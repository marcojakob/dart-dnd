library dnd.drag_detector;

import 'dart:html';
import 'dart:async';
import 'package:logging/logging.dart';

final _log = new Logger('dnd.drag_detector');

/**
 * The [DragDetector] detects drag operations for touch and mouse interactions. 
 * Event streams are provided to track touch or mouse dragging:
 * 
 * * [onDragStart]
 * * [onDrag]
 * * [onDragEnd]
 * 
 * A [DragDetector] can be created for one [Element] or an [ElementList].
 */
class DragDetector {
  
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
  /// See [DragDetector.forElement].
  String handle;
  
  /// Prevents dragging from starting on specified elements. 
  /// See [DragDetector.forElement].
  String cancel;
  
  /// CSS class set to the dragged element during a drag.
  /// See [DragDetector.forElement].
  String draggingClassElement;
  
  /// CSS class set to the html body tag during a drag. 
  /// See [DragDetector.forElement].
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
   * For those two cases, the mouse positions of [DragEvent] will be null.
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
  /// touchEnd).
  List<StreamSubscription> _dragSubs = [];
  
  /// Coordinates where the drag started.
  Point _startCoords;
  
  /// Current coordinates of the drag. Used for events that do not have 
  /// coordinates like keyboard events and blur events.
  Point _currentCoords;
  
  /// The element of the current drag operation (one of 
  /// [_elementOrElementList]). If [_currentDragElement] is NOT null, it 
  /// inicates that a drag is currently beeing handled. 
  Element _currentDragElement;
  
  /// Flag indicating if a drag movement is going on.
  bool _dragging = false;
  
  /**
   * Creates a new [DragDetector]. The [elementOrElementList] is where a drag 
   * can be started. The [elementOrElementList] must be of type [Element] or
   * [ElementList].
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
   * The [draggingClassElement] is the css class set to the dragged element 
   * during a drag.
   * 
   * The [draggingClassBody] is the css class set to the html body tag
   * during a drag.
   */
  DragDetector(elementOrElementList, 
      { this.horizontalOnly: false, 
        this.verticalOnly: false, 
        bool disableTouch: false, 
        bool disableMouse: false,
        this.handle: null, 
        this.cancel: 'input, textarea, button, select, option',
        this.draggingClassElement: 'dnd-dragging',
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
    
    _log.fine('TouchStart event: $_startCoords');

    // Install the touchMove listener.
    _dragSubs.add(document.onTouchMove.listen((TouchEvent event) {
      // Stop and cancel subscriptions on multi-touch.
      if (event.touches.length > 1) {
        _log.fine('Canceling because of multi-touch gesture.');
        _handleDragEnd(event, event.touches[0].page);
        
      } else {
        Point coords = event.changedTouches[0].page;
        
        // If this is the first touchMove event, do scrolling test.
        if (!_dragging && _isScrolling(coords)) {
          // The user is scrolling --> Stop tracking current drag.
          _log.fine('User is scrolling, canceling drag.');
          _cancelDragSubsAndReset();
          return;
        }
        
        // Prevent touch scrolling.
        event.preventDefault();
        
        // Handle the drag.
        _handleDragStartAndDrag(event, coords);
      }
    }));
    
    // Install the touchEnd listener.
    _dragSubs.add(document.onTouchEnd.listen((TouchEvent event) {
      _handleDragEnd(event, event.changedTouches[0].page);
    }));
    
    // Install esc-key and blur listeners.
    _installEscAndBlurListeners();
  }
  
  /**
   * Returns true if there was scrolling activity instead of dragging.
   */
  bool _isScrolling(Point coords) {
    Point delta = coords - _startCoords;
    
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
    
    _log.fine('MouseDown event: $_startCoords');
    
    // Install mouseMove listener.
    _dragSubs.add(document.onMouseMove.listen((MouseEvent event) {
      _handleDragStartAndDrag(event, event.page);
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
   * Only after the user actually moved the mouse and the 
   * [_handleDragStartAndDrag] method is called, a drag occured.
   * 
   * The [dragElement] is the element the event handler has been attached to
   * which is one of [_elementOrElementList].
   * 
   * The [eventTarget] is the element the mouseDown or touchStart event was 
   * dispatched on. This method tests if the drag starts on a valid 
   * [eventTarget]. If not, false is returned. 
   */
  bool _prepareDrag(Element dragElement, Element eventTarget, Point startCoords) {
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
    
    // Set the start coords.
    _startCoords = startCoords;
    _currentCoords = startCoords;
    
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
        _handleDragEnd(keyboardEvent, _currentCoords, cancelled: true);
      }
    }));
    
    // Drag ends when focus is lost.
    _dragSubs.add(window.onBlur.listen((event) {
      _log.fine('Window focus lost, ending drag.');
      _handleDragEnd(event, _currentCoords, cancelled: true);
    }));
  }
  
  /**
   * Handles the drag movement (mouseMove or touchMove). The [moveEvent] might
   * either be a [TouchEvent] or a [MouseEvent]. The [coords] are the page
   * coordinates of the event.
   * 
   * Fires an [onDrag] event. If this is the first drag event, an [onDragStart]
   * event is fired first, followed by the [onDrag] event.
   */
  void _handleDragStartAndDrag(UIEvent moveEvent, Point coords) {
    // If no previous move has been detected, this is the start of the drag.
    if (!_dragging) {
      
      // The drag must be at least 1px in any direction. It's strange, but 
      // Chrome will sometimes fire a mouseMove event when the user clicked, 
      // even when there was no movement. This test prevents such an event from 
      // beeing handled as a drag.
      if (_startCoords.distanceTo(coords) < 1) {
        return;
      }
      
      // Drag started.
      _log.fine('DragStart: $_startCoords');
      
      // Add the css classes during the drag operation.
      if (draggingClassElement != null) {
        _currentDragElement.classes.add(draggingClassElement);
      }
      if (draggingClassBody != null) {
        document.body.classes.add(draggingClassBody);
      }
      
      // Fire the drag start event with start coordinates.
      if (_onDragStart != null) {
        _onDragStart.add(new DragEvent._internal(_currentDragElement, moveEvent, 
            _startCoords, _startCoords));
      }
      _dragging = true;
    }
    
    // Save the current coordinates.
    _currentCoords = coords;
    
    // Fire the drag event.
    _log.finest('Drag: $_currentCoords');
    if (_onDrag != null) {
      _onDrag.add(new DragEvent._internal(_currentDragElement, moveEvent, _startCoords,
          _currentCoords)); 
    }
  }
  
  /**
   * Handles the drag end (mouseUp or touchEnd) event. The [event] might either
   * be a [TouchEvent], a [MouseEvent], a [KeyboardEvent], or a [Event] (when 
   * focus is lost). The [coords] are the page coordinates of the event.
   * 
   * Set [cancelled] to true if the user cancelled the event (e.g. with 
   * esc-key).
   */
  void _handleDragEnd(Event event, Point coords, {bool cancelled: false}) {
    // Only handle drag end if the user actually did drag and not just clicked.
    if (_dragging) {
      _log.fine('DragEnd: $coords');
      
      if (_onDragEnd != null) {
        _onDragEnd.add(new DragEvent._internal(_currentDragElement, event, _startCoords, 
            coords, cancelled: cancelled));
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
    if (draggingClassElement != null) {
      _currentDragElement.classes.remove(draggingClassElement);
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
    _startCoords = null;
    _currentCoords = null;
    _currentDragElement = null;
    _dragging = false;
  }
}

/**
 * Events used when a drag is detected.
 */
class DragEvent {
  /// The [Element] that is beeing dragged. 
  final Element dragElement;
  
  /// The original event which is either a [MouseEvent] or a [TouchEvent]. When
  /// the drag is cancelled (user clicks esc-key or window loses focus) the 
  /// event can be a [KeyboardEvent] or a normal [Event] (blur event).
  final Event originalEvent;
  
  /// Coordinates where the drag started, relative to the top left content
  /// area of the browser (page coordinates).
  final Point startCoords;
  
  /// The coordinates of the event, relative to the top left content area of
  /// the browser (page coordinates).
  final Point coords;
  
  /// True if the user cancelled the drag operation.
  final bool cancelled;
  
  DragEvent._internal(this.dragElement, this.originalEvent, this.startCoords, 
      this.coords, {this.cancelled: false});
}