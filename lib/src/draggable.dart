library dnd.draggable;

import 'dart:html';
import 'dart:async';
import 'package:logging/logging.dart';

part 'drag_detector.dart';
part 'drag_avatar.dart';

final _log = new Logger('dnd.draggable');

/**
 * The [Draggable] detects drag operations for touch and mouse interactions and
 * optionally creates a drag avatar for visual feedback of the drag. 
 * 
 * Event streams are inherited from [_DragDetector] : 
 * 
 * * [onDragStart]
 * * [onDrag]
 * * [onDragEnd]
 * 
 * A [_DragDetector] can be created for one [Element] or an [ElementList].
 */
class Draggable extends _DragDetector {
  
  // -------------------
  // Options
  // -------------------
  /**
   * [avatarHandler] is a function to create a [DragAvatar] for this 
   * [Draggable]. If it is null (the default), the drag image is created from 
   * the [Draggable]'s HTML element. 
   */
  final AvatarHandler avatarHandler;
  
  // -------------------
  // Private Properties
  // -------------------
  /// Tracks subscriptions.
  List<StreamSubscription> _subs = [];
  
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
        bool horizontalOnly: false, 
        bool verticalOnly: false, 
        bool disableTouch: false, 
        bool disableMouse: false,
        String handle: null, 
        String cancel: 'input, textarea, button, select, option',
        String draggingClass: 'dnd-dragging',
        String draggingClassBody: 'dnd-drag-occurring'}) 
        
      : super(elementOrElementList, 
              horizontalOnly: horizontalOnly,
              verticalOnly: verticalOnly,
              disableTouch: disableTouch, 
              disableMouse: disableMouse, 
              handle: handle,
              cancel: cancel,
              draggingClass: draggingClass, 
              draggingClassBody: draggingClassBody) {
    
    _log.fine('Initializing Draggable.');

    // Pass events forward to dragAvatarHandler (if it exists).
    if (avatarHandler != null) {
      _subs.add(onDragStart.listen((dragEvent) {
        avatarHandler.dragStart(dragEvent.dragElement, dragEvent.position);
      }));
      
      _subs.add(onDrag.listen((dragEvent) {
        avatarHandler.drag(dragEvent.startPosition, dragEvent.position);
      }));
      
      _subs.add(onDragEnd.listen((dragEvent) {
        avatarHandler.dragEnd(dragEvent.startPosition, dragEvent.position);  
      }));
    }
  }
  
  /**
   * Unistalls all listeners. This will return the [Element] or [ElementList]
   * back to its pre-init state.
   */
  void destroy() {
    // Cancel subscriptions.
    _subs.forEach((sub) => sub.cancel());
    _subs.clear();
    
    super.destroy();
  }
}

/**
 * Events used when a drag is detected.
 */
class DragEvent {
  /// The [Element] that is beeing dragged. 
  final Element dragElement;
  
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
  
  /// True if the user cancelled the drag operation.
  final bool cancelled;
  
  /**
   * Private constructor for [DragEvent].
   */
  DragEvent._(this.dragElement, this.originalEvent, this.startPosition, 
      this.position, {this.cancelled: false});
}
