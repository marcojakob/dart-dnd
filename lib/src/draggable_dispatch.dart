part of dnd;

/**
 * Dispatches [CustomEvent]s for dragEnter, dragOver, and dragLeave.
 * 
 * Those events are only meant for communication between [Draggable]s and 
 * [Dropzone]s and not to be consumed by users of the library.
 */
class _DragEventDispatcher {

  /// Custom drag enter event that is fired on the element that is entered.
  static const String CUSTOM_DRAG_ENTER = '_customDragEnter';
  
  /// Custom drag over event that is fired on the element that is dragged over.
  static const String CUSTOM_DRAG_OVER = '_customDragOver';
  
  /// Custom drag leave event that is fired on the element that is left.
  static const String CUSTOM_DRAG_LEAVE = '_customDragLeave';
  
  /// Custom drag leave event that is fired on the element that is left.
  static const String CUSTOM_DROP = '_customDrop';
  
  /// Keeps track of the previous target to be able to fire dragLeave events on it.
  static EventTarget previousTarget;
  
  /// Stream provider for [CUSTOM_DRAG_ENTER] events.
  static EventStreamProvider<CustomEvent> enterEvent =
       new EventStreamProvider(CUSTOM_DRAG_ENTER);
  
  /// Stream provider for [CUSTOM_DRAG_OVER] events.
  static EventStreamProvider<CustomEvent> overEvent =
       new EventStreamProvider(CUSTOM_DRAG_OVER);
  
  /// Stream provider for [CUSTOM_DRAG_LEAVE] events.
  static EventStreamProvider<CustomEvent> leaveEvent =
       new EventStreamProvider(CUSTOM_DRAG_LEAVE);
  
  /// Stream provider for [CUSTOM_DROP] events.
  static EventStreamProvider<CustomEvent> dropEvent =
       new EventStreamProvider(CUSTOM_DROP);
  
  /**
   * Dispatches dragEnter, dragOver, and dragLeave events.
   * 
   * The [draggable] is the [Draggable] that is dispatching the event.
   * The [target] is the element that the event will be dispatched on.
   */
  static void dispatchEnterOverLeave(Draggable draggable, EventTarget target, 
                                     Point pagePosition) {
    
    // Sometimes the target is null (e.g. when user drags over buttons on 
    // android). Ignore it.
    if (target == null) {
      return;
    }
    
    _DragEventInfo dragInfo = new _DragEventInfo(draggable.id, pagePosition);
    String dragInfoJson = dragInfo.toJson();
    
    if (previousTarget == target) {
      // Moved on the same element --> dispatch dragOver.
      CustomEvent dragOverEvent = new CustomEvent(CUSTOM_DRAG_OVER, 
          detail: dragInfoJson);
      target.dispatchEvent(dragOverEvent);
      
    } else {
      // Entered a new element --> fire dragEnter of new element.
      CustomEvent dragEnterEvent = new CustomEvent(CUSTOM_DRAG_ENTER, 
          detail: dragInfoJson);
      target.dispatchEvent(dragEnterEvent);
      
      // Fire dragLeave of old element (if there is one).
      if (previousTarget != null) {
        CustomEvent dragLeaveEvent = new CustomEvent(CUSTOM_DRAG_LEAVE, 
            detail: dragInfoJson);
        previousTarget.dispatchEvent(dragLeaveEvent);
      }
      
      // Also fire the first dragOver event for the new element.
      CustomEvent dragOverEvent = new CustomEvent(CUSTOM_DRAG_OVER, 
          detail: dragInfoJson);
      target.dispatchEvent(dragOverEvent);
      
      previousTarget = target;
    }
  }
  
  
  /**
   * Dispatches drop event.
   * 
   * The [draggable] is the [Draggable] that is dispatching the event.
   * The [target] is the element that the event will be dispatched on.
   */
  static void dispatchDrop(Draggable draggable, EventTarget target, 
                           Point pagePosition) {
    
    // Sometimes the target is null (e.g. when user drags over buttons on 
    // android). Ignore it.
    if (target == null) {
      return;
    }
    
    _DragEventInfo dragInfo = new _DragEventInfo(draggable.id, pagePosition);
    String dragInfoJson = dragInfo.toJson();

    CustomEvent dropEvent = new CustomEvent(CUSTOM_DROP, 
        detail: dragInfoJson);
    target.dispatchEvent(dropEvent);
    
    reset(draggable, pagePosition);
  }
  
  /**
   * Must be called when drag ended to fire a last dragLeave event.
   */
  static void reset(Draggable draggable, Point pagePosition) {
    // Fire a last dragLeave.
    if (previousTarget != null) {
      _DragEventInfo dragInfo = new _DragEventInfo(draggable.id, pagePosition);
      CustomEvent dragLeaveEvent = new CustomEvent(CUSTOM_DRAG_LEAVE, 
          detail: dragInfo.toJson());
      previousTarget.dispatchEvent(dragLeaveEvent);
      previousTarget = null;
    }
  }
}

/**
 * Used as detail for the [CustomEvent]s.
 */
class _DragEventInfo {
  /// The id of the currently dragged draggable.
  int draggableId;
  
  /// The current mouse/touch position, relative to the whole document (page 
  /// position).
  Point position;
  
  _DragEventInfo(this.draggableId, this.position);
  
  _DragEventInfo.fromJson(String jsonString) {
    Map jsonMap = JSON.decode(jsonString);
    draggableId = jsonMap['draggableId'];
    position = new Point(jsonMap['position']['x'], jsonMap['position']['y']);    
  }
  
  String toJson() {
    return JSON.encode({
      'draggableId': draggableId,
      'position': {
        'x': position.x,
        'y': position.y
      },
    });
  }
}