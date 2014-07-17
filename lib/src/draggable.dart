part of dnd;

/// Info about the current drag operation. Must be a top-level variable so that 
/// all [Draggable]s know when a drag operation is already handled.
/// Is also used by the [Dropzone] because we can't pass an [Element] through
/// the [CustomEvent]s.
_DragInfo _currentDrag;

/**
 * The [Draggable] detects drag operations for touch and mouse interactions and
 * optionally creates a drag avatar for visual feedback of the drag. Event 
 * streams are provided to track touch or mouse dragging:
 * 
 * * [onDragStart]
 * * [onDrag]
 * * [onDragEnd]
 * 
 * A [Draggable] can be created for one [Element] or an [ElementList].
 */
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
  AvatarHandler avatarHandler;

  /// When set to true, only horizontal dragging is tracked. This enables 
  /// vertical touch dragging to be used for scrolling.
  bool horizontalOnly;
  
  /// When set to true, only vertical dragging is tracked. This enables 
  /// horizontal touch dragging to be used for scrolling.
  bool verticalOnly;

  /// Restricts dragging from starting to the [handle]. 
  /// See [Draggable] constructor.
  String handle;
  
  /// Prevents dragging from starting on specified elements. 
  /// See [Draggable] constructor.
  String cancel;
  
  /// CSS class set to the dragged element during a drag.
  /// See [Draggable] constructor.
  String draggingClass;
  
  /// CSS class set to the html body tag during a drag. 
  /// See [Draggable] constructor.
  String draggingClassBody;
  
  // -------------------
  // Events
  // -------------------
  StreamController<DraggableEvent> _onDragStart;
  StreamController<DraggableEvent> _onDrag;
  StreamController<DraggableEvent> _onDragEnd;
  
  /**
   * Fired when the user starts dragging. 
   * 
   * Note: The [onDragStart] is fired not on touchStart or mouseDown but as 
   * soon as there is a drag movement. When a drag is started an [onDrag] event 
   * will also be fired.
   */
  Stream<DraggableEvent> get onDragStart {
    if (_onDragStart == null) {
      _onDragStart = new StreamController<DraggableEvent>.broadcast(sync: true, 
          onCancel: () => _onDragStart = null);
    }
    return _onDragStart.stream;
  }
  
  /**
   * Fired periodically throughout the drag operation. 
   */
  Stream<DraggableEvent> get onDrag {
    if (_onDrag == null) {
      _onDrag = new StreamController<DraggableEvent>.broadcast(sync: true, 
          onCancel: () => _onDrag = null);
    }
    return _onDrag.stream;
  }
  
  /**
   * Fired when the user ends the dragging. 
   * Is also fired when the user clicks the 'esc'-key or the window loses focus. 
   */
  Stream<DraggableEvent> get onDragEnd {
    if (_onDragEnd == null) {
      _onDragEnd = new StreamController<DraggableEvent>.broadcast(sync: true, 
          onCancel: () => _onDragEnd = null);
    }
    return _onDragEnd.stream;
  }
  
  // -------------------
  // Private Properties
  // -------------------
  /// The [Element] or [ElementList] on which a drag is detected.
  final _elementOrElementList;
  
  /// Tracks subscriptions for start events (mouseDown, touchStart).
  List<StreamSubscription> _startSubs = [];
  
  /// Tracks subscriptions for all other events (mouseMove, touchMove, mouseUp,
  /// touchEnd, and more).
  List<StreamSubscription> _dragSubs = [];
  
  /**
   * Creates a new [Draggable] for [elementOrElementList]. The 
   * [elementOrElementList] must be of type [Element] or [ElementList].
   * 
   * 
   * ## Options
   * 
   * The [avatarHandler]  is responsible for creating, position, and 
   * removing a drag avatar. A drag avatar provides visual feedback during a
   * drag operation. Here are possible options for the [avatarHandler] :
   * 
   * * null (the default) - will not create a drag avatar
   * * new [AvatarHandler.original] - handler that uses the original 
   *   draggable as avatar. See [OriginalAvatarHandler].
   * * new [AvatarHandler.clone] - handler that uses a clone of the draggable 
   *   element as avatar. See [CloneAvatarHandler].
   * * A custom [AvatarHandler] - you can provide your own implementation of 
   *   [AvatarHandler].
   * 
   * If [horizontalOnly] is set to true, only horizontal dragging is tracked.
   * This enables vertical touch dragging to be used for scrolling.
   * 
   * If [verticalOnly] is set to true, only vertical dragging is tracked.
   * This enables horizontal touch dragging to be used for scrolling.
   * 
   * If [disableTouch] is set to true, touch events will be ignored.
   * 
   * If [disableMouse] is set to true, mouse events will be ignored.
   * 
   * If a [handle] query String is specified, it restricts the dragging from 
   * starting unless it occurs on the specified element(s). Only elements that 
   * descend from [elementOrElementList] are permitted. 
   * 
   * If [cancel] query String is specified, drag starting is prevented on 
   * specified elements.
   * 
   * The [draggingClass] is the css class set to the dragged element 
   * during a drag. If set to null, no such css class is added.
   * 
   * The [draggingClassBody] is the css class set to the html body tag
   * during a drag. If set to null, no such css class is added.
   */
  Draggable(elementOrElementList, 
      { this.avatarHandler: null,
        this.horizontalOnly: false, 
        this.verticalOnly: false, 
        bool disableTouch: false, 
        bool disableMouse: false,
        this.handle: null, 
        this.cancel: 'input, textarea, button, select, option',
        this.draggingClass: 'dnd-dragging',
        this.draggingClassBody: 'dnd-drag-occurring'}) 
        
      : this._elementOrElementList = elementOrElementList {
    
    _log.fine('Initializing Draggable.');
    
    _installDragStartListeners(disableTouch, disableMouse);
  }
  
  /**
   * Installs start listeners for touch and mouse (touchStart, mouseDown).
   */
  void _installDragStartListeners(bool disableTouch, bool disableMouse) {
    // Install listeners for touch. Ignore browsers without touch support.
    bool touchSupport = false;
    
    if (!disableTouch && TouchEvent.supported) {
      _log.fine('Installing drag start listener (touchStart).');
      _startSubs.add(_elementOrElementList.onTouchStart.listen(_handleTouchStart));
    }
    
    // Install drag start listener for mouse.
    if (!disableMouse) {
      _log.fine('Installing drag start listener (mouseDown).');
      _startSubs.add(_elementOrElementList.onMouseDown.listen(_handleMouseDown));
    }
  }
  
  /**
   * Handles the touch start event.
   */
  void _handleTouchStart(TouchEvent startEvent) {
    // Ignore if drag is already beeing handled.
    if (_currentDrag != null) {
      return;
    }
    
    // Ignore multi-touch events.
    if (startEvent.touches.length > 1) {
      return;
    }
    
    // Ensure the drag started on a valid target (with respect to cancel and 
    // handle query Strings).
    if (!_isValidDragStartTarget(startEvent.touches[0].target)) {
      return; 
    }
    
    _log.fine('TouchStart event.');
    
    // Initialize the drag info. 
    // Note: the drag is not started on touchStart but after a first valid move.
    _currentDrag = new _DragInfo(id, startEvent.currentTarget, 
        startEvent.touches[0].page, avatarHandler: avatarHandler,
        horizontalOnly: horizontalOnly, verticalOnly: verticalOnly);

    
    // Install the touchMove listener.
    _dragSubs.add(document.onTouchMove.listen((TouchEvent event) {
      // Set the current position.
      _currentDrag.position = event.changedTouches[0].page;
      
      // Stop and cancel subscriptions on multi-touch.
      if (event.touches.length > 1) {
        _log.fine('Canceling because of multi-touch gesture.');
        _handleDragEnd(event);
        
      } else {
        if (!_currentDrag.started 
            && _currentDrag.startPosition != _currentDrag.position) {
          // This is the first drag move.
          
          // Do the scrolling test.
          if (_currentDrag.isScrolling()) {
            // The user is scrolling --> Stop tracking current drag.
            _log.fine('User is scrolling, cancel drag.');
            _handleDragEnd(event);
            return;
          }
          
          // Handle dragStart.
          _handleDragStart(event);
        }

        // Handle drag (will also be called after drag start).
        if (_currentDrag.started) {
          Element realTarget = _getRealTarget(event.changedTouches[0].client);
          _handleDrag(event, realTarget);
        }
        
        // Prevent touch scrolling.
        event.preventDefault();
      }
    }));
    
    
    // Install the touchEnd listener.
    _dragSubs.add(document.onTouchEnd.listen((TouchEvent event) {
      // Set the current position.
      _currentDrag.position = event.changedTouches[0].page;
      
      // Dispatch a drop event.
      EventTarget realTarget = _getRealTarget(event.changedTouches[0].client);
      _DragEventDispatcher.dispatchDrop(this, realTarget, event.changedTouches[0].page);

      // Drag end.
      _handleDragEnd(event);
    }));
    
    
    // Install the touchCancel listener.
    _dragSubs.add(document.onTouchCancel.listen((TouchEvent event) {
      // Set the current position.
      _currentDrag.position = event.changedTouches[0].page;
      
      // Drag end.
      _handleDragEnd(event);
    }));
    
    // Install esc-key and blur listeners.
    _installEscAndBlurListeners();
  }
  
  /**
   * Handles mouse down event.
   */
  void _handleMouseDown(MouseEvent startEvent) {
    // Ignore if drag is already beeing handled.
    if (_currentDrag != null) {
      return;
    }
    
    // Only handle left clicks, ignore clicks from right or middle buttons.
    if (startEvent.button != 0) {
      return;
    }
    
    // Ensure the drag started on a valid target (with respect to cancel and 
    // handle query Strings).
    if (!_isValidDragStartTarget(startEvent.target)) {
      return; 
    }
    
    _log.fine('MouseDown event.');
    
    // Initialize the drag info. 
    // Note: the drag is not started on mouseDown but after a first valid move.
    _currentDrag = new _DragInfo(id, startEvent.currentTarget, startEvent.page, 
        avatarHandler: avatarHandler,
        horizontalOnly: horizontalOnly, verticalOnly: verticalOnly);
    
    // Install mouseMove listener.
    _dragSubs.add(document.onMouseMove.listen((MouseEvent event) {
      // Set the current position.
      _currentDrag.position = event.page;
      
      if (!_currentDrag.started
          && _currentDrag.startPosition != _currentDrag.position) {
        // This is the first drag move.
        
        // Handle dragStart.
        _handleDragStart(event);
      }
      
      // Handle drag (will also be called after dragStart).
      if (_currentDrag.started) {
        EventTarget realTarget = _getRealTarget(event.client, target: event.target);
        _handleDrag(event, realTarget);
      }
    }));
    
    // Install mouseUp listener.
    _dragSubs.add(document.onMouseUp.listen((MouseEvent event) {
      // Set the current position.
      _currentDrag.position = event.page;
      
      // Dispatch a drop event.
      EventTarget realTarget = _getRealTarget(event.client, target: event.target);
      _DragEventDispatcher.dispatchDrop(this, realTarget, event.page);
      
      _handleDragEnd(event);
    }));
    
    // Install esc-key and blur listeners.
    _installEscAndBlurListeners();
    
    // Prevent default on mouseDown. Reasons:
    // * Disables image dragging handled by the browser.
    // * Disables text selection.
    // 
    // Note: We must NOT prevent default on form elements. Reasons:
    // * SelectElement would not show a dropdown.
    // * InputElement and TextAreaElement would not get focus.
    // * ButtonElement and OptionElement - don't know if this is needed??
    Element target = startEvent.target;
    if (!(target is SelectElement || target is InputElement || 
          target is TextAreaElement || target is ButtonElement || 
          target is OptionElement)) {
      startEvent.preventDefault();
    }
  }
  
  /**
   * Tests if [target] is a valid place to start a drag. If [handle] is
   * provided, drag can only start on the [handle]s. If [cancel] is 
   * provided, drag cannot be started on those elements.
   */
  bool _isValidDragStartTarget(EventTarget target) {
  
    // Test if a drag was started on a cancel element.
    if (cancel != null 
        && target is Element 
        && target.matchesWithAncestors(cancel)) {
      
      _log.fine('Drag started on a cancel element, canceling drag.');
      return false;
    }
  
    // If handle is specified, drag must start on handle or one of its children.
    if (handle != null) {
      if (target is Element) {
        // 1. The target must match the handle query String.
        if (!target.matchesWithAncestors(handle)) {
          _log.fine('Drag not started on valid handle.');
          return false; 
        }
        
        // 2. The target must be a child of the drag element(s).
        if (_elementOrElementList is ElementList) {
          for (Element el in _elementOrElementList) {
            if (el.contains(target)) {
              return true; 
            }
          }
        } else {
          if ((_elementOrElementList as Element).contains(target)) {
            return true; 
          }
        }
      }
      
      // Has a handle specified but we did not find a match.
      _log.fine('Drag not started on valid handle.');
      return false;
    }
    
    return true;
  }
  
  /**
   * Installs listeners for esc-key and blur (window loses focus). Those two
   * events will end the drag operation.
   */
  void _installEscAndBlurListeners() {
    // Drag ends when escape key is hit.
    _dragSubs.add(window.onKeyDown.listen((keyboardEvent) {
      if (keyboardEvent.keyCode == KeyCode.ESC) {
        _log.fine('Esc-key pressed, ending drag.');
        _handleDragEnd(keyboardEvent);
      }
    }));
    
    // Drag ends when focus is lost.
    _dragSubs.add(window.onBlur.listen((event) {
      _log.fine('Window focus lost, ending drag.');
      _handleDragEnd(event);
    }));
  }
  
  /**
   * Handles the drag start start. The [moveEvent] might either be a 
   * [TouchEvent] or a [MouseEvent]. 
   */
  void _handleDragStart(UIEvent moveEvent) {
    _log.fine('DragStart: ${_currentDrag.position}');
          
    // Set the drag started flag.
    _currentDrag.started = true;
    
    // Pass event to AvatarHandler.
    if (avatarHandler != null) {
      avatarHandler.dragStart(_currentDrag.element, _currentDrag.position);
    }
    
    // Fire the drag start event with start position.
    if (_onDragStart != null) {
      // The dragStart has the same for startPosition and current position.
      _onDragStart.add(new DraggableEvent._(moveEvent, _currentDrag));
    }
    
    // Add the css classes during the drag operation.
    if (draggingClass != null) {
      _currentDrag.element.classes.add(draggingClass);
    }
    if (draggingClassBody != null) {
      document.body.classes.add(draggingClassBody);
    }
    
    // Text selections should not be a problem, but it seems better usability 
    // to remove text selection when dragging something.
    _clearTextSelections();
  }
  
  /**
   * Handles the drag. The [moveEvent] might either be a [TouchEvent] or a 
   * [MouseEvent]. 
   * 
   * The [target] is the actual target receiving the event.
   */
  void _handleDrag(UIEvent moveEvent, EventTarget target) {
    _log.finest('Drag: ${_currentDrag.position}');
    
    // Pass event to AvatarHandler.
    if (avatarHandler != null) {
      avatarHandler.drag(_currentDrag.startPosition, _currentDrag.position);
    }
    
    // Dispatch a drag over event.
    _DragEventDispatcher.dispatchEnterOverLeave(this, target, 
        _currentDrag.position);
    
    // Fire the drag event.
    if (_onDrag != null) {
      _onDrag.add(new DraggableEvent._(moveEvent, _currentDrag));
    }
  }
  
  /**
   * Handles the drag end (mouseUp or touchEnd) event. The [event] might either
   * be a [TouchEvent], a [MouseEvent], a [KeyboardEvent], or a [Event] (when 
   * focus is lost). 
   * 
   * The [target] is the actual target receiving the event.
   * 
   * The [position] is the page position of the event. 
   */
  void _handleDragEnd(Event event) {
    // Only handle drag end if the user actually did drag and not just clicked.
    if (_currentDrag.started) {
      
      // Pass event to AvatarHandler.
      if (avatarHandler != null) {
        avatarHandler.dragEnd(_currentDrag.startPosition, _currentDrag.position);
      }
      
      _log.fine('DragEnd: ${_currentDrag.position}');
      
      // Fire dragEnd event.
      if (_onDragEnd != null) {
        _onDragEnd.add(new DraggableEvent._(event, _currentDrag));
      }
      
      // Prevent TouchEvent from emulating a click after touchEnd event.
      event.preventDefault();
      
      if (event is MouseEvent) {
        // Prevent MouseEvent from firing a click after mouseUp event.
        _suppressClickEvent();
      }
      
      // Remove the css classes.
      if (draggingClass != null) {
        _currentDrag.element.classes.remove(draggingClass);
      }
      if (draggingClassBody != null) {
        document.body.classes.remove(draggingClassBody);
      }
    } else {
      _log.fine('No dragging detected.');
    }
    
    // Reset.
    _resetCurrentDrag();
  }
  
  /**
   * Makes sure that a potential click event is ignored. This is necessary for
   * [MouseEvent]s. We have to wait for and cancel a potential click event 
   * happening after the mouseUp event. 
   */
  void _suppressClickEvent() {
    StreamSubscription clickPreventer = _elementOrElementList.onClick.listen((event) {
      _log.fine('Suppressing click event.');
      event.stopPropagation();
      event.preventDefault();
    });
    
    // Wait until the end of event loop to see if a click event is fired.
    // Then cancel the listener.
    new Future(() {
      clickPreventer.cancel();
      clickPreventer = null;
    });
  }
  
  /**
   * Unistalls all listeners. 
   */
  void destroy() {
    _resetCurrentDrag();
    
    // Cancel start subscriptions.
    _startSubs.forEach((sub) => sub.cancel());
    _startSubs.clear();
  }
  
  /**
   * Cancels drag subscriptions and resets to initial state.
   */
  void _resetCurrentDrag() {
    // Cancel drag subscriptions.
    _dragSubs.forEach((sub) => sub.cancel());
    _dragSubs.clear();
    
    // Reset.
    _DragEventDispatcher.reset(this, _currentDrag.position);
    _currentDrag = null;
  }
  
  /**
   * Removes all text selections from the HTML document, including selections
   * in active textarea or active input element.
   */
  void _clearTextSelections() {
    // Remove selection.
    window.getSelection().removeAllRanges();
    
    // Remove selection from textarea or input.
    var activeElement = document.activeElement;
    if (activeElement is TextAreaElement) {
      activeElement.setSelectionRange(0, 0);
    } else if (activeElement is InputElement) {
      activeElement.setSelectionRange(0, 0);
    }
  }
  
  /**
   * Determine the actual target that should receive the event because 
   * mouse or touch event might have occurred on a drag avatar.
   * 
   * If a [target] is provided it is tested to see if is already the correct
   * target or if it is the drag avatar and thus must be replaced by the 
   * element underneath.
   */
  EventTarget _getRealTarget(Point clientPosition, {EventTarget target}) {
    // If no target was provided get it.
    if (target == null) {
      target = document.elementFromPoint(clientPosition.x, clientPosition.y);
    }
    
    // Test if target is the drag avatar.
    if (avatarHandler != null && avatarHandler.avatar != null 
        && avatarHandler.avatar.contains(target)) {
      
      // Target is the drag avatar, get element underneath. 
      avatarHandler.avatar.style.visibility = 'hidden';
      target = document.elementFromPoint(clientPosition.x, clientPosition.y);
      avatarHandler.avatar.style.visibility = 'visible';
    }
    
    return target;
  }
}

/**
 * Event used when a drag is detected.
 */
class DraggableEvent {
  /// The [Element] that is beeing dragged. 
  final Element draggableElement;
  
  /// The [AvatarHandler] or null if there is none.
  final AvatarHandler avatarHandler;
  
  /// The original event which is either ...
  /// * a [MouseEvent], 
  /// * a [TouchEvent], 
  /// * a [KeyboardEvent] when the user clicks the esc-key, or
  /// * a normal [Event] when the window loses focus (blur event).
  final Event originalEvent;
  
  /// Position where the drag started, relative to the whole document (page 
  /// position).
  final Point startPosition;
  
  /// The current mouse/touch position, relative to the whole document (page 
  /// position).
  final Point position;
  
  /**
   * Private constructor for [DraggableEvent].
   */
  DraggableEvent._(this.originalEvent, _DragInfo dragInfo)
      : draggableElement = dragInfo.element,
        startPosition = dragInfo.startPosition,
        position = dragInfo.position,
        avatarHandler = dragInfo.avatarHandler;
}

/**
 * Information about the current drag operation.
 */
class _DragInfo {
  /// The id of the currently dragged [Draggable].
  final int draggableId;
  
  /// The dragged element.
  final Element element;
  
  /// Position where the drag started.
  final Point startPosition;
  
  /// The [AvatarHandler] or null if there is none.
  final AvatarHandler avatarHandler;

  /// The current position of the mouse or touch. This position is the real
  /// position that is not constrained by the horizontal/vertical axis.
  Point _realPosition;
  
  /// Flag indicating if the drag started.
  bool started = false;
  
  final bool horizontalOnly;
  final bool verticalOnly;
  
  _DragInfo(this.draggableId, this.element, this.startPosition, 
      { this.avatarHandler: null, 
        this.horizontalOnly: false, 
        this.verticalOnly: false}) {
    // Initially set current position to startPosition.
    _realPosition = startPosition;
  }
  
  /// The current position. Is constrained by the horizontal/vertical axis 
  /// (depending on [horizontalOnly] and [verticalOnly]) and the left and 
  /// top borders of the window.
  Point get position => _constrain(_realPosition);
  
  /// Sets the current position.
  set position(Point pos) => _realPosition = pos;
  
  /**
   * Returns true if there was scrolling activity instead of dragging.
   */
  bool isScrolling() {
    Point delta = _realPosition - startPosition;
    
    // If horizontalOnly test for vertical movement.
    if (horizontalOnly && delta.y.abs() > delta.x.abs()) {
      // Vertical scrolling.
      return true;
    }
    
    // If verticalOnly test for horizontal movement.
    if (verticalOnly && delta.x.abs() > delta.y.abs()) {
      // Horizontal scrolling.
      return true;
    }
    
    // No scrolling.
    return false;
  }
  
  /**
   * Constrains the axis if [horizontalOnly] or [verticalOnly] is true.
   * Further it keeps x and y >= 0 to not allow dragging out of the window.
   */
  Point _constrain(Point pos) {
    int x = pos.x;
    int y = pos.y;
    
    // Set y-value to startPosition if horizontalOnly.
    if (horizontalOnly) {
      y = startPosition.y;
    }
    // Set x-value to startPosition if verticalOnly.
    if (verticalOnly) {
      x = startPosition.x;
    }
    
    // Constrain by top and left border of window.
    return new Point(math.max(0, x), math.max(0, y));
  }
}
