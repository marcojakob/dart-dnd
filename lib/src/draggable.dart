part of dnd;

/// Info about the current drag operation. Must be a top-level variable so that
/// all [Draggable]s know when a drag operation is already handled.
/// Is also used by the [Dropzone] because we can't pass an [Element] through
/// the [CustomEvent]s.
_DragInfo? _currentDrag;

/// The [Draggable] detects drag operations for touch and mouse interactions and
/// optionally creates a drag avatar for visual feedback of the drag. Event
/// streams are provided to track touch or mouse dragging:
///
/// * [onDragStart]
/// * [onDrag]
/// * [onDragEnd]
///
/// A [Draggable] can be created for one [Element] or an [ElementList].
class Draggable {
  /// Counter to generate a unique id for each instance.
  static int idCounter = 0;

  /// An auto-generated [id] used to identify this [Draggable].
  final int id = idCounter++;

  // --------------
  // Options
  // --------------
  /// [avatarHandler] is a function to create a [DragAvatar] for this [Draggable].
  /// See [Draggable] constructor.
  AvatarHandler? avatarHandler;

  /// When set to true, only horizontal dragging is tracked. This enables
  /// vertical touch dragging to be used for scrolling.
  bool horizontalOnly;

  /// When set to true, only vertical dragging is tracked. This enables
  /// horizontal touch dragging to be used for scrolling.
  bool verticalOnly;

  /// Restricts dragging from starting to the [handle].
  /// See [Draggable] constructor.
  String? handle;

  /// Prevents dragging from starting on specified elements.
  /// See [Draggable] constructor.
  String cancel;

  /// CSS class set to the dragged element during a drag.
  /// See [Draggable] constructor.
  String draggingClass;

  /// CSS class set to the html body tag during a drag.
  /// See [Draggable] constructor.
  String draggingClassBody;

  /// The minimum distance in pixels that is needed for a drag to start.
  /// See [Draggable] constructor.
  int minDragStartDistance;

  /// The minimum distance for a drag to prevent click events.
  /// DEPRECATED: Please use [minDragStartDistance] instead.
  @deprecated
  int get clickSuppression => minDragStartDistance;

  /// DEPRECATED: Please use [minDragStartDistance] instead.
  @deprecated
  set clickSuppression(int distance) => minDragStartDistance = distance;

  // -------------------
  // Events
  // -------------------
  StreamController<DraggableEvent>? _onDragStart;
  StreamController<DraggableEvent>? _onDrag;
  StreamController<DraggableEvent>? _onDragEnd;

  /// Fired when the user starts dragging.
  ///
  /// Note: The [onDragStart] is fired not on touchStart or mouseDown but as
  /// soon as there is a drag movement. When a drag is started an [onDrag] event
  /// will also be fired.
  Stream<DraggableEvent> get onDragStart {
    if (_onDragStart == null) {
      _onDragStart = StreamController<DraggableEvent>.broadcast(
          sync: true, onCancel: () => _onDragStart = null);
    }
    return _onDragStart!.stream;
  }

  /// Fired periodically throughout the drag operation.
  Stream<DraggableEvent> get onDrag {
    if (_onDrag == null) {
      _onDrag = StreamController<DraggableEvent>.broadcast(
          sync: true, onCancel: () => _onDrag = null);
    }
    return _onDrag!.stream;
  }

  /// Fired when the user ends the dragging.
  /// Is also fired when the user clicks the 'esc'-key or the window loses focus.
  Stream<DraggableEvent> get onDragEnd {
    if (_onDragEnd == null) {
      _onDragEnd = StreamController<DraggableEvent>.broadcast(
          sync: true, onCancel: () => _onDragEnd = null);
    }
    return _onDragEnd!.stream;
  }

  /// Abort the current drag
  void abort() {
    if (_currentDrag != null && _currentDrag!.draggableId == this.id) {
      _handleDragEnd(null, null, cancelled: true);
    }
  }

  // -------------------
  // Private Properties
  // -------------------
  /// The list of [Element]s on which a drag is detected.
  late List<Element> _elements;

  /// Managers for browser events.
  final List<_EventManager> _eventManagers = [];

  /// Creates a new [Draggable] for [elementOrElementList]. The
  /// [elementOrElementList] must be of type [Element], [ElementList], or
  /// [List<Element>].
  ///
  ///
  /// ## Options
  ///
  /// The [avatarHandler]  is responsible for creating, position, and
  /// removing a drag avatar. A drag avatar provides visual feedback during a
  /// drag operation. Here are possible options for the [avatarHandler] :
  ///
  /// * null (the default) - will not create a drag avatar
  /// * [AvatarHandler.original] - handler that uses the original
  ///   draggable as avatar. See [OriginalAvatarHandler].
  /// * [AvatarHandler.clone] - handler that uses a clone of the draggable
  ///   element as avatar. See [CloneAvatarHandler].
  /// * A custom [AvatarHandler] - you can provide your own implementation of
  ///   [AvatarHandler].
  ///
  /// If [horizontalOnly] is set to true, only horizontal dragging is tracked.
  /// This enables vertical touch dragging to be used for scrolling.
  ///
  /// If [verticalOnly] is set to true, only vertical dragging is tracked.
  /// This enables horizontal touch dragging to be used for scrolling.
  ///
  /// If a [handle] query String is specified, it restricts the dragging from
  /// starting unless it occurs on the specified element(s). Only elements that
  /// descend from [elementOrElementList] are permitted.
  ///
  /// If [cancel] query String is specified, drag starting is prevented on
  /// specified elements.
  ///
  /// The [draggingClass] is the css class set to the dragged element
  /// during a drag. If set to null, no such css class is added.
  ///
  /// The [draggingClassBody] is the css class set to the html body tag
  /// during a drag. If set to null, no such css class is added.
  ///
  /// The [minDragStartDistance] is the minimum distance in pixels that is needed
  /// for a drag to start. Default is `4`. This allows for clicks with tiny movement.
  ///
  Draggable(elementOrElementList,
      {this.avatarHandler,
      this.horizontalOnly = false,
      this.verticalOnly = false,
      this.handle,
      this.cancel = 'input, textarea, button, select, option',
      this.draggingClass = 'dnd-dragging',
      this.draggingClassBody = 'dnd-drag-occurring',
      this.minDragStartDistance = 4}) {
    // Wrap in a List if it is not a list but a single Element.
    _elements = elementOrElementList is List<Element>
        ? elementOrElementList
        : [elementOrElementList];

    // Detect Pointer Event Support.
    JsObject jsWindow = JsObject.fromBrowserObject(window);

    if (jsWindow.hasProperty('PointerEvent')) {
      // Browser with support for Pointer Events.
      _eventManagers.add(_PointerManager(this));
    } else {
      // We're on a browser with no support for Pointer Events.
      // Install touch and mouse listeners.
      if (TouchEvent.supported) {
        _eventManagers.add(_TouchManager(this));
      }
      _eventManagers.add(_MouseManager(this));
    }
  }

  /// Handles the drag start. The [moveEvent] might either be a
  /// [TouchEvent] or a [MouseEvent].
  void _handleDragStart(Event moveEvent) {
    // Set the drag started flag.
    _currentDrag!.started = true;

    // Pass event to AvatarHandler.
    if (avatarHandler != null) {
      avatarHandler!
          ._handleDragStart(_currentDrag!.element, _currentDrag!.position);
    }

    // Fire the drag start event with start position.
    if (_onDragStart != null) {
      // The dragStart has the same for startPosition and current position.
      _onDragStart!.add(DraggableEvent._(moveEvent, _currentDrag!));
    }

    // Add the css classes during the drag operation.
    _currentDrag!.element.classes.add(draggingClass);
    document.body!.classes.add(draggingClassBody);

    // Text selections should not be a problem, but it seems better usability
    // to remove text selection when dragging something.
    _clearTextSelections();
  }

  /// Handles the drag. The [moveEvent] might either be a [TouchEvent] or a
  /// [MouseEvent].
  ///
  /// The [target] is the actual target receiving the event.
  void _handleDrag(Event moveEvent, EventTarget? target) {
    // Pass event to AvatarHandler.
    if (avatarHandler != null) {
      avatarHandler!
          ._handleDrag(_currentDrag!.startPosition, _currentDrag!.position);
    }

    // Dispatch internal drag enter, over, or leave event.
    _DragEventDispatcher.dispatchEnterOverLeave(this, target);

    // Fire the drag event.
    if (_onDrag != null) {
      _onDrag!.add(DraggableEvent._(moveEvent, _currentDrag!));
    }
  }

  /// Handles the drag end (mouseUp or touchEnd) event. The [event] might either
  /// be a [TouchEvent], a [MouseEvent], a [KeyboardEvent], or a [Event] (when
  /// focus is lost).
  ///
  /// The [target] is the actual target receiving the event. The [target] may
  /// be null when the event was [cancelled] (e.g. user clicked esc-key).
  ///
  /// Set [cancelled] to true to indicate that this drag ended through a
  /// cancel oparation like hitting the `esc` key.
  void _handleDragEnd(Event? event, EventTarget? target, {cancelled = false}) {
    // Only handle drag end if the user actually did drag and not just clicked.
    if (_currentDrag != null && _currentDrag!.started) {
      // Pass event to AvatarHandler.
      if (avatarHandler != null) {
        avatarHandler!._handleDragEnd(
            _currentDrag!.startPosition, _currentDrag!.position);
      }

      // Dispatch internal drop event if drag was not cancelled.
      if (!cancelled && target != null) {
        _DragEventDispatcher.dispatchDrop(this, target);
      }

      // Fire dragEnd event.
      if (_onDragEnd != null) {
        _onDragEnd!
            .add(DraggableEvent._(event, _currentDrag!, cancelled: cancelled));
      }

      // Prevent TouchEvent from emulating a click after touchEnd event.
      if (event != null) {
        event.preventDefault();
      }

      // Prevent MouseEvent from firing a click after mouseUp event.
      if (event is MouseEvent) {
        _suppressClickEvent(_currentDrag!.element);
      }

      // Remove the css classes.
      _currentDrag!.element.classes.remove(draggingClass);
      document.body!.classes.remove(draggingClassBody);
    }

    // Reset.
    _resetCurrentDrag();
  }

  /// Makes sure that a potential click event is ignored. This is necessary for
  /// [MouseEvent]s. We have to wait for and cancel a potential click event
  /// happening after the mouseUp event.
  void _suppressClickEvent(Element element) {
    StreamSubscription clickPreventer = element.onClick.listen((event) {
      event.stopPropagation();
      event.preventDefault();
    });

    // Wait until the end of event loop to see if a click event is fired.
    // Then cancel the listener.
    Future(() {
      clickPreventer.cancel();
    });
  }

  /// Resets the draggable elements to their initial state.
  ///
  /// All listeners are uninstalled.
  void destroy() {
    _resetCurrentDrag();

    // Destroy all managers with their listeners.
    _eventManagers.forEach((m) => m.destroy());
    _eventManagers.clear();
    if (avatarHandler != null && avatarHandler!.avatar != null) {
      avatarHandler!.avatar!.remove();
    }
  }

  /// Cancels drag subscriptions and resets to initial state.
  void _resetCurrentDrag() {
    // Reset all managers.
    _eventManagers.forEach((m) => m.reset());

    // Reset dispatcher to fire a last internal dragLeave event.
    _DragEventDispatcher.reset();

    // Reset the current drag.
    _currentDrag = null;
  }

  /// Removes all text selections from the HTML document, including selections
  /// in active textarea or active input element.
  void _clearTextSelections() {
    // Remove selection.
    window.getSelection()?.removeAllRanges();

    // Try to remove selection from textarea or input.
    try {
      var activeElement = document.activeElement;
      if (activeElement is TextAreaElement) {
        activeElement.setSelectionRange(0, 0);
      } else if (activeElement is InputElement) {
        activeElement.setSelectionRange(0, 0);
      }
    } catch (_) {
      // Might throw an error if the element does not support setSelectionRange.
      // This is the case for InputElement with type 'file'.
    }
  }
}

/// Event used when a drag is detected.
class DraggableEvent {
  /// The [Element] that is beeing dragged.
  final Element draggableElement;

  /// The [AvatarHandler] or null if there is none.
  final AvatarHandler? avatarHandler;

  /// The original event which is either ...
  /// * a [MouseEvent],
  /// * a [TouchEvent],
  /// * a [KeyboardEvent] when the user clicks the esc-key,
  /// * a normal [Event] when the window loses focus (blur event), or
  /// * null if the drag was programmatically aborted.
  final Event? originalEvent;

  /// Position where the drag started, relative to the whole document (page
  /// position).
  final Point startPosition;

  /// The current mouse/touch position, relative to the whole document (page
  /// position).
  final Point position;

  /// Indicates if this [DraggableEvent] was [cancelled]. This is currently
  /// only used for [onDragEnd] events to indicate a drag end through a
  /// cancelling oparation like `esc` key or windows loosing focus.
  final bool cancelled;

  /// Private constructor for [DraggableEvent].
  DraggableEvent._(this.originalEvent, _DragInfo dragInfo,
      {this.cancelled = false})
      : draggableElement = dragInfo.element,
        avatarHandler = dragInfo.avatarHandler,
        startPosition = dragInfo.startPosition,
        position = dragInfo.position;
}

/// Information about the current drag operation.
class _DragInfo {
  /// The id of the currently dragged [Draggable].
  final int draggableId;

  /// The dragged element.
  final Element element;

  /// Position where the drag started.
  final Point startPosition;

  /// The [AvatarHandler] or null if there is none.
  final AvatarHandler? avatarHandler;

  /// The current position of the mouse or touch. This position is constrained
  /// by the horizontal/vertical axis.
  late Point _position;

  /// Flag indicating if the drag started.
  bool started = false;

  final bool horizontalOnly;
  final bool verticalOnly;

  _DragInfo(this.draggableId, this.element, this.startPosition,
      {this.avatarHandler,
      this.horizontalOnly = false,
      this.verticalOnly = false}) {
    // Initially set current position to startPosition.
    _position = startPosition;
  }

  /// The current position, constrained by the horizontal/vertical axis
  /// depending on [horizontalOnly] and [verticalOnly].
  Point get position => _position;

  /// Sets the current position.
  set position(Point pos) => _position = _constrainAxis(pos);

  /// Constrains the axis if [horizontalOnly] or [verticalOnly] is true.
  Point _constrainAxis(Point pos) {
    // Set y-value to startPosition if horizontalOnly.
    if (horizontalOnly) {
      return Point(pos.x, startPosition.y);
    }

    // Set x-value to startPosition if verticalOnly.
    if (verticalOnly) {
      return Point(startPosition.x, pos.y);
    }

    // Axis is not constrained.
    return pos;
  }
}
