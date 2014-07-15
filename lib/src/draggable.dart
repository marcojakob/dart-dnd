part of dnd;

/// The currently dragged element. Must be a top-level variable so that all
/// [Draggable]s know when a drag operation is already handled.
/// Is also used by the [Dropzone] because we can't pass an [Element] through
/// the [CustomEvent]s.
Element _currentDragElement;

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
  
  /// Position where the drag started.
  Point _startPosition;
  
  /// Current position of the drag. Used for events that do not have 
  /// coordinates like keyboard events and blur events.
  Point _currentPosition;
  
  /// Flag indicating if a drag movement is going on.
  bool _dragMoved = false;
  
  /**
   * Creates a new [Draggable] for [elementOrElementList]. The 
   * [elementOrElementList] must be of type [Element] or [ElementList].
   * 
   * 
   * ## Options
   * 
   * The [avatarHandler]  is responsible for creating, position, and 
   * removing a drag avatar. A drag avatar provides visual feedback during a
   * drag operation. Here are possible options for the [dragAvatarHandler]:
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
    try {
      touchSupport = TouchEvent.supported;
    } catch (_) {}
    
    if (!disableTouch && touchSupport) {
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
    // Ignore multi-touch events.
    if (startEvent.touches.length > 1) {
      return;
    }
    
    // Prepare the drag and test if the drag is valid.
    bool dragPrepareOk = _prepareDrag(startEvent.currentTarget, 
        startEvent.touches[0].target, startEvent.touches[0].page);
    if (!dragPrepareOk) {
      return;
    }
    
    _log.fine('TouchStart event: $_startPosition');

    // Install the touchMove listener.
    _dragSubs.add(document.onTouchMove.listen((TouchEvent event) {
      // Stop and cancel subscriptions on multi-touch.
      if (event.touches.length > 1) {
        _log.fine('Canceling because of multi-touch gesture.');
        _handleDragEnd(event, event.touches[0].page);
        
      } else {
        Point position = event.changedTouches[0].page;
        
        // If this is the first touchMove event, do scrolling test.
        if (!_dragMoved && _isScrolling(position)) {
          // The user is scrolling --> Stop tracking current drag.
          _log.fine('User is scrolling, canceling drag.');
          _cancelDragSubsAndReset();
          return;
        }
        
        // Prevent touch scrolling.
        event.preventDefault();
        
        // Handle the drag.
        Element realTarget = _getRealTouchTarget(event.changedTouches[0].client);
        _handleMove(event, realTarget, position);
      }
    }));
    
    // Install the touchEnd listener.
    _dragSubs.add(document.onTouchEnd.listen((TouchEvent event) {
      // Dispatch a drop event.
      EventTarget realTarget = _getRealTouchTarget(event.changedTouches[0].client);
      _DragEventDispatcher.dispatchDrop(this, realTarget, event.changedTouches[0].page);

      // Drag end.
      _handleDragEnd(event, event.changedTouches[0].page);
    }));
    
    // Install the touchCancel listener.
    _dragSubs.add(document.onTouchCancel.listen((TouchEvent event) {
      _handleDragEnd(event, event.changedTouches[0].page);
    }));
    
    // Install esc-key and blur listeners.
    _installEscAndBlurListeners();
  }
  
  /**
   * Returns true if there was scrolling activity instead of dragging.
   */
  bool _isScrolling(Point position) {
    Point delta = position - _startPosition;
    
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
   * Handles mouse down event.
   */
  void _handleMouseDown(MouseEvent startEvent) {
    // Ignore clicks from right or middle buttons.
    if (startEvent.button != 0) {
      return;
    }
    
    // Prepare the drag and test if the drag is valid.
    bool dragPrepareOk = _prepareDrag(startEvent.currentTarget, 
        startEvent.target, startEvent.page);
    if (!dragPrepareOk) {
      return;
    }
    
    _log.fine('MouseDown event: $_startPosition');
    
    // Install mouseMove listener.
    _dragSubs.add(document.onMouseMove.listen((MouseEvent event) {
      // Determine the actual target that should receive the event because 
      // mouse event might have occurred on a drag avatar.
      EventTarget realTarget = _getRealMouseTarget(event.target, event.client);
      _handleMove(event, realTarget, event.page);
    }));
    
    // Install mouseUp listener.
    _dragSubs.add(document.onMouseUp.listen((MouseEvent event) {
      // Dispatch a drop event.
      EventTarget realTarget = _getRealMouseTarget(event.target, event.client);
      _DragEventDispatcher.dispatchDrop(this, realTarget, event.page);
      
      _handleDragEnd(event, event.page);
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
   * Initializes the necessary variables to prepare for the drag. It is not 
   * certain at this point if there will actually be a valid drag operation.
   * Only after the user actually moved the mouse and the [_handleMove] method 
   * is called, a drag occured.
   * 
   * The [dragElement] is the element the event handler has been attached to
   * which is one of [_elementOrElementList].
   * 
   * The [eventTarget] is the element the mouseDown or touchStart event was 
   * dispatched on. This method tests if the drag starts on a valid 
   * [eventTarget]. If not, false is returned. 
   */
  bool _prepareDrag(Element dragElement, Element eventTarget, Point startPosition) {
    // Ignore if drag is already beeing handled.
    if (_currentDragElement != null) {
      return false;
    }
    
    // Ensure the drag started on a valid target (with respect to cancel and 
    // handle query Strings).
    if (!_isValidDragStartTarget(eventTarget)) {
      return false; 
    }
    
    // Set the drag target to prevent other widgets from inheriting the event.
    _currentDragElement = dragElement;
    
    // Set the start position.
    this._startPosition = startPosition;
    this._currentPosition = startPosition;
    
    return true;
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
        _handleDragEnd(keyboardEvent, _currentPosition);
      }
    }));
    
    // Drag ends when focus is lost.
    _dragSubs.add(window.onBlur.listen((event) {
      _log.fine('Window focus lost, ending drag.');
      _handleDragEnd(event, _currentPosition);
    }));
  }
  
  /**
   * Handles the drag movement (mouseMove or touchMove). The [moveEvent] might
   * either be a [TouchEvent] or a [MouseEvent]. 
   * 
   * The [target] is the actual target receiving the event.
   * 
   * The [position] is the page position of the event. The [clientPosition] is 
   * the position relative to the client area.
   * 
   * Fires an [onDrag] event. If this is the first move, an [onDragStart]
   * event is fired first, followed by the [onDrag] event.
   */
  void _handleMove(UIEvent moveEvent, EventTarget target, Point position) {
    // If no previous move has been detected, this is the start of the drag.
    if (!_dragMoved) {
      // The drag must be at least 1px in any direction. It's strange, but 
      // Chrome will sometimes fire a mouseMove event when the user clicked, 
      // even when there was no movement. This test prevents such an event from 
      // beeing handled as a drag.
      if (_startPosition.distanceTo(position) < 1) {
        return;
      }
      
      _handleDragStart(moveEvent, _startPosition);
    }
    
    _handleDrag(moveEvent, target, position);
  }
  
  /**
   * Handles the drag start start. The [moveEvent] might either be a 
   * [TouchEvent] or a [MouseEvent]. The [position] is the page position of 
   * the start event.
   */
  void _handleDragStart(UIEvent moveEvent, Point position) {
    _log.fine('DragStart: $position');
          
    // Set the drag moved flag.
    _dragMoved = true;
    
    // Pass event to AvatarHandler.
    if (avatarHandler != null) {
      avatarHandler.dragStart(_currentDragElement, position);
    }
    
    // Fire the drag start event with start position.
    if (_onDragStart != null) {
      // The dragStart has the same for startPosition and current position.
      _onDragStart.add(new DraggableEvent._(_currentDragElement, moveEvent, 
          position, position));
    }
    
    // Add the css classes during the drag operation.
    if (draggingClass != null) {
      _currentDragElement.classes.add(draggingClass);
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
   * 
   * The [position] is the page position of the event. 
   */
  void _handleDrag(UIEvent moveEvent, EventTarget target, Point position) {
    _log.finest('Drag: $position');
    
    // Save the current position.
    _currentPosition = position;
    
    // Pass event to AvatarHandler.
    if (avatarHandler != null) {
      avatarHandler.drag(_startPosition, _currentPosition);
    }
    
    // Dispatch a drag over event.
    _DragEventDispatcher.dispatchEnterOverLeave(this, target, position);
    
    // Fire the drag event.
    if (_onDrag != null) {
      _onDrag.add(new DraggableEvent._(_currentDragElement, moveEvent, _startPosition,
          _currentPosition)); 
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
  void _handleDragEnd(Event event, Point position) {
    // Only handle drag end if the user actually did drag and not just clicked.
    if (_dragMoved) {
      
      // Pass event to AvatarHandler.
      if (avatarHandler != null) {
        avatarHandler.dragEnd(_startPosition, _currentPosition);
      }
      
      _log.fine('DragEnd: $position');
      
      // Fire dragEnd event.
      if (_onDragEnd != null) {
        _onDragEnd.add(new DraggableEvent._(_currentDragElement, event, 
            _startPosition, position));
      }
      
      // Prevent TouchEvent from emulating a click after touchEnd event.
      event.preventDefault();
      
      if (event is MouseEvent) {
        // Prevent MouseEvent from firing a click after mouseUp event.
        _suppressClickEvent();
      }
      
      // Remove the css classes.
      if (draggingClass != null) {
        _currentDragElement.classes.remove(draggingClass);
      }
      if (draggingClassBody != null) {
        document.body.classes.remove(draggingClassBody);
      }
    } else {
      _log.fine('No dragging detected.');
    }
    
    // Cancel the all subscriptions that were set up during start.
    _cancelDragSubsAndReset();
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
    _cancelStartSubs();
    _cancelDragSubsAndReset();
  }
  
  /**
   * Cancels start subscriptions.
   */
  void _cancelStartSubs() {
    _startSubs.forEach((sub) => sub.cancel());
    _startSubs.clear();
  }
  
  /**
   * Cancels drag subscriptions and resets to initial state.
   */
  void _cancelDragSubsAndReset() {
    _dragSubs.forEach((sub) => sub.cancel());
    _dragSubs.clear();
    
    // Reset.
    _DragEventDispatcher.reset(this, _currentPosition);
    _startPosition = null;
    _currentPosition = null;
    _currentDragElement = null;
    _dragMoved = false;
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
   * mouse event might have occurred on a drag avatar.
   * If the mouse is over the drag avatar, the element below is returned, 
   * otherwise, the [target] itself is returend.
   */
  EventTarget _getRealMouseTarget(EventTarget target, Point clientPosition) {
    EventTarget realTarget = target;
    
    if (avatarHandler != null && avatarHandler.avatar != null 
        && avatarHandler.avatar.contains(target)) {
      // Mouse or touch is over drag avatar. Get element underneath.
      avatarHandler.avatar.style.visibility = 'hidden';
      realTarget = document.elementFromPoint(clientPosition.x, 
          clientPosition.y);
      avatarHandler.avatar.style.visibility = 'visible';
    }
    
    return realTarget;
  }
  
  /**
   * Determine the actual target that should receive the event because the 
   * touch might have occurred on a drag avatar.
   * Hides the avatar (if there is one) and returns the [Element] from point 
   * [clientPosition].
   */
  Element _getRealTouchTarget(Point clientPosition) {
    Element result;
    
    if (avatarHandler != null && avatarHandler.avatar != null) {
      // Mouse or touch is over drag avatar. Get element underneath.
      avatarHandler.avatar.style.visibility = 'hidden';
      result = document.elementFromPoint(clientPosition.x, clientPosition.y);
      avatarHandler.avatar.style.visibility = 'visible';
    } else {
      result = document.elementFromPoint(clientPosition.x, clientPosition.y);
    }
    
    return result;
  }
}

/**
 * Event used when a drag is detected.
 */
class DraggableEvent {
  /// The [Element] that is beeing dragged. 
  final Element draggableElement;
  
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
  DraggableEvent._(this.draggableElement, this.originalEvent, this.startPosition, 
      this.position);
}
