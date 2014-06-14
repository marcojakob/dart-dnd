library dnd.drag_detector;

import 'dart:html';
import 'dart:async';
import 'package:logging/logging.dart';

final _log = new Logger('dnd.drag_detector');

/**
 * The [DragDetector] detects drag operations for touch and mouse interactions. 
 * Event streams are provided to track touch or mouse dragging:
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
  /// When set to true detecting touch events by [DragDetector] will be 
  /// disabled.
  bool disableTouch = false;

  /// When set to true, detecting mouse events by [DragDetector] will be 
  /// disabled.
  bool disableMouse = false;
  
  /// When set to true, only horizontal dragging is tracked. This enables 
  /// vertical touch dragging to be used for scrolling.
  bool horizontalOnly = false;
  
  /// When set to true, only vertical dragging is tracked. This enables 
  /// horizontal touch dragging to be used for scrolling.
  bool verticalOnly = false;
  
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
  
  /// Flag indicating if the drag is already beeing handled.
  bool _dragHandled = false;
  
  /// Flag indicating if a drag movement is going on.
  bool _dragging = false;
  
  /**
   * Creates a new [DragDetector]. The [element] is where a drag can be 
   * started.
   */
  DragDetector.forElement(Element element) 
      : this._elementOrElementList = element {
    
    _log.fine('Initializing DragDetector for an Element.');
    
    _installDragStartListeners();
  }
  
  /**
   * Creates a new [DragDetector]. The [elementList] is where a drag can be 
   * started.
   */
  DragDetector.forElements(ElementList elementList) 
      : this._elementOrElementList = elementList {
    
    _log.fine('Initializing DragDetector for an ElementList.');
    
    _installDragStartListeners();
  }
  
  /**
   * Installs start listeners for touch and mouse (touchStart, mouseDown).
   * The [elementOrElementList] is either one [Element] or an [ElementList] 
   * on which a drag can be started.
   */
  void _installDragStartListeners() {
    _log.finest('Installing drag start listeners (touchStart and mouseDown).');
    
    // Install listeners for touch. Ignore browsers without touch support.
    if (!disableTouch && TouchEvent.supported) {
      _startSubs.add(_elementOrElementList.onTouchStart.listen(_handleTouchStart));
    }
    
    // Install drag start listener for mouse.
    if (!disableMouse) {
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
    
    // Ignore if drag is already beeing handled.
    if (_dragHandled) {
      return;
    }
    // Set the flag to prevent other widgets from inheriting the event.
    _dragHandled = true;
    
    // Set the start coords.
    _startCoords = touchEvent.touches[0].page;
    
    _log.fine('TouchStart event: $_startCoords');

    // Install the touchMove listener.
    _dragSubs.add(document.onTouchMove.listen((TouchEvent event) {
      // Stop and cancel subscriptions on multi-touch.
      if (event.touches.length > 1) {
        _log.fine('Canceling drag because of multi-touch gesture.');
        _cancelDragSubsAndReset();
        
      } else {
        Point coords = event.changedTouches[0].page;
        
        // If this is the first touchMove event, do scrolling test.
        if (!_dragging && _isScrolling(coords)) {
          // The user is scrolling --> Stop tracking current drag.
          _cancelDragSubsAndReset();
          return;
        }
        
        // Prevent touch scrolling.
        event.preventDefault();
        
        // Handle the drag.
        _handleDrag(event, coords);
      }
    }));
    
    // Install the touchEnd listener.
    _dragSubs.add(document.onTouchEnd.listen((TouchEvent event) {
      _handleDragEnd(event, event.changedTouches[0].page);
    }));
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
    
    // Ignore if drag is already beeing handled.
    if (_dragHandled) {
      return;
    }
    // Set the flag to prevent other widgets from inheriting the event.
    _dragHandled = true;
    
    // Set the start coords.
    _startCoords = mouseEvent.page;
    
    _log.fine('MouseDown event: $_startCoords');
    
    // Install mouseMove listener.
    _dragSubs.add(document.onMouseMove.listen((MouseEvent event) {
      _handleDrag(event, event.page);
    }));
    
    // Install mouseUp listener.
    _dragSubs.add(document.onMouseUp.listen((MouseEvent event) {
      _handleDragEnd(event, event.page);
    }));
    
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
   * Handles the drag movement (mouseMove or touchMove). The [moveEvent] might
   * either be a [TouchEvent] or a [MouseEvent]. The [coords] are the page
   * coordinates of the event.
   * 
   * Fires a [onDrag] event. If this is the first drag event, an [onDragStart]
   * event is fired first, followed by the [onDrag] event.
   */
  void _handleDrag(UIEvent moveEvent, Point coords) {
    // If no previous move has been detected, this is the start of the drag.
    if (!_dragging) {
      _log.fine('DragStart: $_startCoords');
      
      // Fire the drag start event with start coordinates.
      if (_onDragStart != null) {
        _onDragStart.add(new DragEvent._internal(moveEvent, _startCoords));
      }
      _dragging = true;
    }
    
    // Fire the drag event.
    _log.finest('Drag: $coords');
    if (_onDrag != null) {
      _onDrag.add(new DragEvent._internal(moveEvent, coords)); 
    }
  }
  
  /**
   * Handles the drag end (mouseUp or touchEnd) event. The [event] might either
   * be a [TouchEvent] or a [MouseEvent]. The [coords] are the page
   * coordinates of the event.
   */
  void _handleDragEnd(UIEvent event, Point coords) {
    // Only handle drag end if the user actually did drag and not just clicked.
    if (_dragging) {
      _log.fine('DragEnd: $coords');
      
      if (_onDragEnd != null) {
        _onDragEnd.add(new DragEvent._internal(event, coords));
      }
      
      // Prevent TouchEvent from emulating a click after touchEnd event.
      event.preventDefault();
      
      if (event is MouseEvent) {
        // Prevent MouseEvent from firing a click after mouseUp event.
        _suppressClickEvent();
      }
    } else {
      _log.fine('DragEnd: There was no dragging.');
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
    _dragHandled = false;
    _dragging = false;
  }
}

/**
 * Events used when a drag is detected.
 */
class DragEvent {
  /// The original event which is either a [MouseEvent] or [TouchEvent].
  UIEvent originalEvent;
  
  /// The coordinates of the event, relative to the top left content area of
  /// the browser (page coordinates).
  Point coords;
  
  DragEvent._internal(this.originalEvent, this.coords);
}