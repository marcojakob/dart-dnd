part of dnd.draggable;

/// The currently dragged element. Must be a top-level variable so that all
/// [_DragDetector]s know when a drag operation is already handled.
Element _currentDragElement;

/**
 * The [_DragDetector] detects drag operations for touch and mouse interactions. 
 * Event streams are provided to track touch or mouse dragging:
 * 
 * * [onDragStart]
 * * [onDrag]
 * * [onDragEnd]
 * 
 * A [_DragDetector] can be created for one [Element] or an [ElementList].
 */
class _DragDetector {
  
  // --------------
  // Options
  // --------------
  /// When set to true, only horizontal dragging is tracked. This enables 
  /// vertical touch dragging to be used for scrolling.
  bool horizontalOnly;
  
  /// When set to true, only vertical dragging is tracked. This enables 
  /// horizontal touch dragging to be used for scrolling.
  bool verticalOnly;

  /// Restricts dragging from starting to the [handle]. 
  /// See [_DragDetector].
  String handle;
  
  /// Prevents dragging from starting on specified elements. 
  /// See [_DragDetector].
  String cancel;
  
  /// CSS class set to the dragged element during a drag.
  /// See [_DragDetector].
  String draggingClass;
  
  /// CSS class set to the html body tag during a drag. 
  /// See [_DragDetector].
  String draggingClassBody;
  
  // -------------------
  // Events
  // -------------------
  StreamController<DragEvent> _onDragStart;
  StreamController<DragEvent> _onDrag;
  StreamController<DragEvent> _onDragEnd;
  
  /**
   * Fired when the user starts dragging. 
   * 
   * Note: The [onDragStart] is fired not on touchStart or mouseDown but as 
   * soon as there is a drag movement. When a drag is started an [onDrag] event 
   * will also be fired.
   */
  Stream<DragEvent> get onDragStart {
    if (_onDragStart == null) {
      _onDragStart = new StreamController<DragEvent>.broadcast(sync: true, 
          onCancel: () => _onDragStart = null);
    }
    return _onDragStart.stream;
  }
  
  /**
   * Fired periodically throughout the drag operation. 
   */
  Stream<DragEvent> get onDrag {
    if (_onDrag == null) {
      _onDrag = new StreamController<DragEvent>.broadcast(sync: true, 
          onCancel: () => _onDrag = null);
    }
    return _onDrag.stream;
  }
  
  /**
   * Fired when the user ends the dragging. 
   * Is also fired when the user clicks the 'esc'-key or the window loses focus. 
   */
  Stream<DragEvent> get onDragEnd {
    if (_onDragEnd == null) {
      _onDragEnd = new StreamController<DragEvent>.broadcast(sync: true, 
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
   * Creates a new [_DragDetector] for [elementOrElementList]. The 
   * [elementOrElementList] must be of type [Element] or [ElementList].
   * 
   * 
   * ## Options
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
  _DragDetector(elementOrElementList, 
      { this.horizontalOnly: false, 
        this.verticalOnly: false, 
        bool disableTouch: false, 
        bool disableMouse: false,
        this.handle: null, 
        this.cancel: 'input, textarea, button, select, option',
        this.draggingClass: 'dnd-dragging',
        this.draggingClassBody: 'dnd-drag-occurring'}) 
        
      : this._elementOrElementList = elementOrElementList {
    
    _log.fine('Initializing DragDetector.');
    
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
  void _handleTouchStart(TouchEvent touchEvent) {
    // Ignore multi-touch events.
    if (touchEvent.touches.length > 1) {
      return;
    }
    
    // Prepare the drag and test if the drag is valid.
    bool dragPrepareOk = _prepareDrag(touchEvent.currentTarget, 
        touchEvent.touches[0].target, touchEvent.touches[0].page);
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
        _handleMove(event, position);
      }
    }));
    
    // Install the touchEnd listener.
    _dragSubs.add(document.onTouchEnd.listen((TouchEvent event) {
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
  void _handleMouseDown(MouseEvent mouseEvent) {
    // Ignore clicks from right or middle buttons.
    if (mouseEvent.button != 0) {
      return;
    }
    
    // Prepare the drag and test if the drag is valid.
    bool dragPrepareOk = _prepareDrag(mouseEvent.currentTarget, 
        mouseEvent.target, mouseEvent.page);
    if (!dragPrepareOk) {
      return;
    }
    
    _log.fine('MouseDown event: $_startPosition');
    
    // Install mouseMove listener.
    _dragSubs.add(document.onMouseMove.listen((MouseEvent event) {
      _handleMove(event, event.page);
    }));
    
    // Install mouseUp listener.
    _dragSubs.add(document.onMouseUp.listen((MouseEvent event) {
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
    Element target = mouseEvent.target;
    if (!(target is SelectElement || target is InputElement || 
          target is TextAreaElement || target is ButtonElement || 
          target is OptionElement)) {
      mouseEvent.preventDefault();
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
        _handleDragEnd(keyboardEvent, _currentPosition, cancelled: true);
      }
    }));
    
    // Drag ends when focus is lost.
    _dragSubs.add(window.onBlur.listen((event) {
      _log.fine('Window focus lost, ending drag.');
      _handleDragEnd(event, _currentPosition, cancelled: true);
    }));
  }
  
  /**
   * Handles the drag movement (mouseMove or touchMove). The [moveEvent] might
   * either be a [TouchEvent] or a [MouseEvent]. The [position] is the page
   * position of the event.
   * 
   * Fires an [onDrag] event. If this is the first move, an [onDragStart]
   * event is fired first, followed by the [onDrag] event.
   */
  void _handleMove(UIEvent moveEvent, Point position) {
    // If no previous move has been detected, this is the start of the drag.
    if (!_dragMoved) {
      // The drag must be at least 1px in any direction. It's strange, but 
      // Chrome will sometimes fire a mouseMove event when the user clicked, 
      // even when there was no movement. This test prevents such an event from 
      // beeing handled as a drag.
      if (_startPosition.distanceTo(position) < 1) {
        return;
      }
      
      _handleDragStart(moveEvent, position);
    }
    
    _handleDrag(moveEvent, position);
  }
  
  /**
   * Handles the drag start start. The [moveEvent] might either be a 
   * [TouchEvent] or a [MouseEvent]. The [position] are the page position of 
   * the event.
   */
  void _handleDragStart(UIEvent moveEvent, Point position) {
    _log.fine('DragStart: $_startPosition');
          
    // Set the drag moved flag.
    _dragMoved = true;
    
    // Fire the drag start event with start position.
    if (_onDragStart != null) {
      // The dragStart has the same for startPosition and current position.
      _onDragStart.add(new DragEvent._(_currentDragElement, moveEvent, 
          _startPosition, _startPosition));
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
   * [MouseEvent]. The [position] is the page position of the event.
   */
  void _handleDrag(UIEvent moveEvent, Point position) {
    // Save the current position.
    _currentPosition = position;
    
    // Fire the drag event.
    _log.finest('Drag: $_currentPosition');
    if (_onDrag != null) {
      _onDrag.add(new DragEvent._(_currentDragElement, moveEvent, _startPosition,
          _currentPosition)); 
    }
  }
  
  /**
   * Handles the drag end (mouseUp or touchEnd) event. The [event] might either
   * be a [TouchEvent], a [MouseEvent], a [KeyboardEvent], or a [Event] (when 
   * focus is lost). The [position] is the page position of the event.
   * 
   * Set [cancelled] to true if the user cancelled the event (e.g. with 
   * esc-key).
   */
  void _handleDragEnd(Event event, Point position, {bool cancelled: false}) {
    // Only handle drag end if the user actually did drag and not just clicked.
    if (_dragMoved) {
      _log.fine('DragEnd: $position');
      
      if (_onDragEnd != null) {
        _onDragEnd.add(new DragEvent._(_currentDragElement, event, _startPosition, 
            position, cancelled: cancelled));
      }
      
      // Prevent TouchEvent from emulating a click after touchEnd event.
      event.preventDefault();
      
      if (event is MouseEvent) {
        // Prevent MouseEvent from firing a click after mouseUp event.
        _suppressClickEvent();
      }
    } else {
      _log.fine('No dragging detected.');
    }
    
    // Remove the css classes.
    if (draggingClass != null) {
      _currentDragElement.classes.remove(draggingClass);
    }
    if (draggingClassBody != null) {
      document.body.classes.remove(draggingClassBody);
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
   * Unistalls all listeners. This will return the [Element] or [ElementList]
   * back to its pre-init state.
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
}