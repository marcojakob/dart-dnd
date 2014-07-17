import 'dart:html';
import 'package:dnd/dnd.dart';

/**
 * An example that only uses drag detection. This already helps quite a lot
 * as it unifies touch and mouse dragging and provides convenient event streams.
 * 
 * Use this if you want to implement your own custom dragging behavior.
 */
main() {
  // Install draggable.
  Draggable draggable = new Draggable(querySelector('.draggable'));
  
  // Paragraph.
  Element p = querySelector('.draggable p');
  
  // Listen to drag start.
  draggable.onDragStart.listen((DraggableEvent event) {
    p.innerHtml = 'DragStart: <br>${event.position}';
  });
  
  // Listen do drag.
  draggable.onDrag.listen((DraggableEvent event) {
    p.innerHtml = 'Drag: <br>${event.position}';
  });
  
  // Listen to dragEnd.
  draggable.onDragEnd.listen((DraggableEvent event) {
    p.innerHtml = 'DragEnd: ${event.position}';
  });
    
  
}