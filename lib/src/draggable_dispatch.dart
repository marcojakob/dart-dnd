part of dnd;

/// Dispatches [MouseEvent]s for dragEnter, dragOver, and dragLeave.
///
/// Those events are only meant for communication between [Draggable]s and
/// [Dropzone]s and not to be consumed by users of the library.
class _DragEventDispatcher {

  /// Custom drag enter event that is fired on the element that is entered.
  static const String CUSTOM_DRAG_ENTER = '_customDragEnter';

  /// Custom drag over event that is fired on the element that is dragged over.
  static const String CUSTOM_DRAG_OVER = '_customDragOver';

  /// Custom drag leave event that is fired on the element that is left.
  static const String CUSTOM_DRAG_LEAVE = '_customDragLeave';

  /// Custom drag leave event that is fired on the element that is left.
  static const String CUSTOM_DROP = '_customDrop';

  /// Stream provider for [CUSTOM_DRAG_ENTER] events. The relatedTarget contains
  /// the [Element] the user entered from (may be null).
  static EventStreamProvider<MouseEvent> enterEvent =
       new EventStreamProvider(CUSTOM_DRAG_ENTER);

  /// Stream provider for [CUSTOM_DRAG_OVER] events. The relatedTarget is empty.
  static EventStreamProvider<MouseEvent> overEvent =
       new EventStreamProvider(CUSTOM_DRAG_OVER);

  /// Stream provider for [CUSTOM_DRAG_LEAVE] events. The relatedTarget contains
  /// the [Element] the user is leaving to (may be null).
  static EventStreamProvider<MouseEvent> leaveEvent =
       new EventStreamProvider(CUSTOM_DRAG_LEAVE);

  /// Stream provider for [CUSTOM_DROP] events. The relatedTarget is empty.
  static EventStreamProvider<MouseEvent> dropEvent =
       new EventStreamProvider(CUSTOM_DROP);


  /// Keeps track of the previous target to be able to fire dragLeave events on it.
  static EventTarget previousTarget;

  /// Dispatches dragEnter, dragOver, and dragLeave events.
  ///
  /// The [draggable] is the [Draggable] that is dispatching the event.
  /// The [target] is the element that the event will be dispatched on.
  static void dispatchEnterOverLeave(Draggable draggable, EventTarget target) {

    // Sometimes the target is null (e.g. when user drags over buttons on
    // android). Ignore it.
    if (target == null) {
      return;
    }

    if (previousTarget == target) {
      // Moved on the same element --> dispatch dragOver.
      MouseEvent dragOverEvent = new MouseEvent(CUSTOM_DRAG_OVER);
      target.dispatchEvent(dragOverEvent);

    } else {
      // Entered a new element --> fire dragEnter of new element.
      MouseEvent dragEnterEvent = new MouseEvent(CUSTOM_DRAG_ENTER,
          relatedTarget: previousTarget);
      target.dispatchEvent(dragEnterEvent);

      // Fire dragLeave of old element (if there is one).
      if (previousTarget != null) {
        MouseEvent dragLeaveEvent = new MouseEvent(CUSTOM_DRAG_LEAVE,
            relatedTarget: target);
        previousTarget.dispatchEvent(dragLeaveEvent);
      }

      // Also fire the first dragOver event for the new element.
      MouseEvent dragOverEvent = new MouseEvent(CUSTOM_DRAG_OVER);
      target.dispatchEvent(dragOverEvent);

      previousTarget = target;
    }
  }


  /// Dispatches drop event.
  ///
  /// The [draggable] is the [Draggable] that is dispatching the event.
  /// The [target] is the element that the event will be dispatched on.
  static void dispatchDrop(Draggable draggable, EventTarget target) {

    // Sometimes the target is null (e.g. when user drags over buttons on
    // android). Ignore it.
    if (target == null) {
      return;
    }

    MouseEvent dropEvent = new MouseEvent(CUSTOM_DROP);
    target.dispatchEvent(dropEvent);

    reset();
  }

  /// Must be called when drag ended to fire a last dragLeave event.
  static void reset() {
    // Fire a last dragLeave.
    if (previousTarget != null) {
      MouseEvent dragLeaveEvent = new MouseEvent(CUSTOM_DRAG_LEAVE);
      previousTarget.dispatchEvent(dragLeaveEvent);
      previousTarget = null;
    }
  }
}