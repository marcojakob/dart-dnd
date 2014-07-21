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
        this.handle: null, 
        this.cancel: 'input, textarea, button, select, option',
        this.draggingClass: 'dnd-dragging',
        this.draggingClassBody: 'dnd-drag-occurring'}) 
        
      : this._elementOrElementList = elementOrElementList {
    
    // Detect IE Pointer Event Support.
    JsObject jsWindow = new JsObject.fromBrowserObject(window);
    JsObject jsNavigator = jsWindow['navigator'];
    
    if (jsNavigator.hasProperty('pointerEnabled')) {
      // We're on IE11 or higher supporting pointerEvents.
      _installStartPointer();
      
    } else if (jsNavigator.hasProperty('msPointerEnabled')){
      // We're on IE10 supporting msPointerEvents.
      _installStartPointer(msPrefix: true);
      
    } else {
      // We're on other browsers. Install touch and mouse listeners.
      if (TouchEvent.supported) {
        _installStartTouch();
      }
      _installStartMouse();
    }
  }
  
  /**
   * Installs listener for the touchStart event.
   */
  void _installStartTouch() {
    _startSubs.add(_elementOrElementList.onTouchStart.listen((TouchEvent event) {
      // Ignore multi-touch events.
      if (event.touches.length > 1) {
        return;
      }
      
      bool validStart = _handleStart(event, event.touches[0].target, event.touches[0].page);

      if (validStart) {
        // Install listeners to detect a drag move or a drag end.
        _installMoveTouch();
        _installEndTouch();
        _installCancelTouch();
        _installCancelEscAndBlur();
      }
    }));
  }
  
  /**
   * Installs listener for the mouseDown event.
   */
  void _installStartMouse() {
    _startSubs.add(_elementOrElementList.onMouseDown.listen((MouseEvent event) {
      // Only handle left clicks, ignore clicks from right or middle buttons.
      if (event.button != 0) {
        return;
      }
      
      bool validStart = _handleStart(event, event.target, event.page);
      
      if (validStart) {
        // Install listeners to detect a drag move or a drag end.
        _installMoveMouse();
        _installEndMouse();
        _installCancelEscAndBlur();
        
        // Prevent default on mouseDown. Reasons:
        // * Disables image dragging handled by the browser.
        // * Disables text selection.
        // 
        // Note: We must NOT prevent default on form elements. Reasons:
        // * SelectElement would not show a dropdown.
        // * InputElement and TextAreaElement would not get focus.
        // * ButtonElement and OptionElement - don't know if this is needed??
        Element target = event.target;
        if (!(target is SelectElement || target is InputElement || 
              target is TextAreaElement || target is ButtonElement || 
              target is OptionElement)) {
          event.preventDefault();
        }
      }
    }));
  }
  
  /**
   * Installs pointerDown listeners (for IE).
   */
  void _installStartPointer({bool msPrefix: false}) {
    String downEventName = msPrefix ? 'MSPointerDown' : 'pointerdown';
    
    // Function to be called on all elements of [_elementOrElementList].
    var installFunc = (Element element) {
      _startSubs.add(element.on[downEventName].listen((UIEvent event) {
        bool validStart = _handleStart(event, event.target, event.page);
        
        if (validStart) {
          // Install listeners to detect a drag move or a drag end.
          _installMovePointer(msPrefix: msPrefix);
          _installEndPointer(msPrefix: msPrefix);
          _installCancelPointer(msPrefix: msPrefix);
          _installCancelEscAndBlur();
          
          event.preventDefault();
        }
      }));
    };
    
    if (_elementOrElementList is ElementList) {
      // Must call the `element.on[...]` on every single element of ElementList
      // because the method does not exist on the collection.
      _elementOrElementList.forEach(installFunc);
    } else { 
      // Install on the single [Element].
      installFunc(_elementOrElementList);
    }
    
    // Disable default touch actions on all elements (scrolling, panning, zooming).
    if (msPrefix) {
      _elementOrElementList.style.setProperty('-ms-touch-action', 'none');
    } else {
      _elementOrElementList.style.setProperty('-touch-action', 'none');
    }
  }
  
  /**
   * Handles all start events (touchStart, mouseDown, and pointerDown).
   * 
   * Returns true if it was a valid move.
   */
  bool _handleStart(Event event, EventTarget target, Point position) {
    // Ignore if drag is already beeing handled.
    if (_currentDrag != null) {
      return false;
    }
    
    // Ensure the drag started on a valid target (with respect to cancel and 
    // handle query Strings).
    if (!_isValidDragStartTarget(target)) {
      return false; 
    }
    
    // Initialize the drag info. 
    // Note: the drag is not started on touchStart but after a first valid move.
    _currentDrag = new _DragInfo(id, event.currentTarget, 
        position, avatarHandler: avatarHandler,
        horizontalOnly: horizontalOnly, verticalOnly: verticalOnly);
    
    return true;
  }
  
  /**
   * Installs the touchMove listener.
   */
  void _installMoveTouch() {
    _dragSubs.add(document.onTouchMove.listen((TouchEvent event) {
      // Stop and cancel subscriptions on multi-touch.
      if (event.touches.length > 1) {
        _handleDragEnd(event);
        return;
      }
        
      bool validMove = _handleMove(event, event.changedTouches[0].page, 
          event.changedTouches[0].client, scrollingTest: true);
      
      if (validMove) {
        // Prevent touch scrolling.
        event.preventDefault();
      }
    }));
  }
  
  /**
   * Installs the mouseMove listener.
   */
  void _installMoveMouse() {
    _dragSubs.add(document.onMouseMove.listen((MouseEvent event) {
      _handleMove(event, event.page, event.client);
    }));
  }
  
  /**
   * Installs pointerMove listeners (for IE).
   */
  void _installMovePointer({bool msPrefix: false}) {
    String moveEventName = msPrefix ? 'MSPointerMove' : 'pointermove';
    
    // Function to be called on all elements of [_elementOrElementList].
    var installFunc = (Element element) {
      _dragSubs.add(document.on[moveEventName].listen((event) {
        _handleMove(event, event.page, event.client);
      }));
    };
    
    if (_elementOrElementList is ElementList) {
      // Must call the `element.on[...]` on every single element of ElementList
      // because the method does not exist on the collection.
      _elementOrElementList.forEach(installFunc);
    } else { 
      // Install on the single [Element].
      installFunc(_elementOrElementList);
    }
  }
  
  /**
   * Handles all move events (touchMove, mouseMove, and pointerMove).
   * 
   * Returns true if it was a valid move.
   */
  bool _handleMove(Event event, Point position, Point clientPosition, 
                   {bool scrollingTest: false}) {
    // Set the current position.
    _currentDrag.position = position;
    
    if (!_currentDrag.started 
        && _currentDrag.startPosition != _currentDrag.position) {
      // This is the first drag move.
      
      // Do the scrolling test.
      if (scrollingTest && _currentDrag.isScrolling()) {
        // The user is scrolling --> Stop tracking current drag.
        _handleDragEnd(event);
        return false;
      }
      
      // Handle dragStart.
      _handleDragStart(event);
    }

    // Handle drag (will also be called after drag start).
    if (_currentDrag.started) {
      Element realTarget = _getRealTarget(clientPosition);
      _handleDrag(event, realTarget);
    }
    
    return true;
  }
  
  /**
   * Installs the touchEnd listener.
   */
  void _installEndTouch() {
    _dragSubs.add(document.onTouchEnd.listen((TouchEvent event) {
      _handleEnd(event, null, event.changedTouches[0].page, event.changedTouches[0].client);
    }));
  }
  
  /**
   * Installs the mouseUp listener.
   */
  void _installEndMouse() {
    _dragSubs.add(document.onMouseUp.listen((MouseEvent event) {
      _handleEnd(event, event.target, event.page, event.client);
    }));
  }
  
  /**
   * Installs pointerUp listener (for IE).
   */
  void _installEndPointer({bool msPrefix: false}) {
    String endEventName = msPrefix ? 'MSPointerUp' : 'pointerup';
    
    // Function to be called on all elements of [_elementOrElementList].
    var installFunc = (Element element) {
      _dragSubs.add(document.on[endEventName].listen((event) {
        _handleEnd(event, event.target, event.page, event.client);
      }));
    };
    
    if (_elementOrElementList is ElementList) {
      // Must call the `element.on[...]` on every single element of ElementList
      // because the method does not exist on the collection.
      _elementOrElementList.forEach(installFunc);
    } else { 
      // Install on the single [Element].
      installFunc(_elementOrElementList);
    }
  }
  
  /**
   * Handles all end events (touchEnd, mouseUp, and pointerUp).
   */
  void _handleEnd(Event event, EventTarget target, Point position, Point clientPosition) {
    // Set the current position.
    _currentDrag.position = position;
    
    // Dispatch a drop event.
    EventTarget realTarget = _getRealTarget(clientPosition, target: target);
    _DragEventDispatcher.dispatchDrop(this, realTarget, position);
    
    _handleDragEnd(event);
  }
  
  /**
   * Installs the touchCancel listener.
   */
  void _installCancelTouch() {
    _dragSubs.add(document.onTouchCancel.listen((TouchEvent event) {
      _handleCancel(event, event.changedTouches[0].page);
    }));
  }
  
  /**
   * Installs pointerCancel listener (for IE).
   */
  void _installCancelPointer({bool msPrefix: false}) {
    String cancelEventName = msPrefix ? 'MSPointerCancel' : 'mspointercancel';
    
    // Function to be called on all elements of [_elementOrElementList].
    var installFunc = (Element element) {
      _dragSubs.add(document.on[cancelEventName].listen((event) {
        _handleCancel(event, event.page);
      }));
    };
    
    if (_elementOrElementList is ElementList) {
      // Must call the `element.on[...]` on every single element of ElementList
      // because the method does not exist on the collection.
      _elementOrElementList.forEach(installFunc);
    } else { 
      // Install on the single [Element].
      installFunc(_elementOrElementList);
    }
  }
  
  /**
   * Installs listener for esc-key and blur (window loses focus). Those 
   * events will cancel the drag operation.
   */
  void _installCancelEscAndBlur() {
    // Drag ends when escape key is hit.
    _dragSubs.add(window.onKeyDown.listen((keyboardEvent) {
      if (keyboardEvent.keyCode == KeyCode.ESC) {
        _handleCancel(keyboardEvent, _currentDrag.position);
      }
    }));
    
    // Drag ends when focus is lost.
    _dragSubs.add(window.onBlur.listen((event) {
      _handleCancel(event, _currentDrag.position);
    }));
  }
  
  /**
   * Handles all cancel events (touchCancel and pointerCancel).
   */
  void _handleCancel(Event event, Point position) {
    // Set the current position.
    _currentDrag.position = position;
    
    // Drag end.
    _handleDragEnd(event);
  }
  
  
  /**
   * Handles the drag start start. The [moveEvent] might either be a 
   * [TouchEvent] or a [MouseEvent]. 
   */
  void _handleDragStart(UIEvent moveEvent) {
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
     
      return false;
    }
  
    // If handle is specified, drag must start on handle or one of its children.
    if (handle != null) {
      if (target is Element) {
        // 1. The target must match the handle query String.
        if (!target.matchesWithAncestors(handle)) {
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
      return false;
    }
    
    return true;
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
  
  /// The current position, constrained by the horizontal/vertical axis 
  /// depending on [horizontalOnly] and [verticalOnly].
  Point get position => _constrainAxis(_realPosition);
  
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
   */
  Point _constrainAxis(Point pos) {
    // Set y-value to startPosition if horizontalOnly.
    if (horizontalOnly) {
      return new Point(pos.x, startPosition.y);
    }
    
    // Set x-value to startPosition if verticalOnly.
    if (verticalOnly) {
      return new Point(startPosition.x, pos.y);
    }
    
    // Axis is not constrained.
    return pos;
  }
}
