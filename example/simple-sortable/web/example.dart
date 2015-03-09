import 'dart:html';
import 'package:dnd/dnd.dart';

/// Just a test if we can set up [Draggable] and [Dropzone] on the same elements
/// and implement some basic sortable/rearranging behavior.
main() {
  // Install same elements as draggable and dropzone.
  Draggable draggable = new Draggable(querySelectorAll('.sortable'),
      avatarHandler: new AvatarHandler.clone());

  Dropzone dropzone = new Dropzone(querySelectorAll('.sortable'));

  // Swap elements when dropped.
  dropzone.onDrop.listen((DropzoneEvent event) {
    swapElements(event.draggableElement, event.dropzoneElement);
  });
}

/// Simple function to swap two elements.
void swapElements(Element elm1, Element elm2) {
  var parent1 = elm1.parent;
  var next1   = elm1.nextElementSibling;
  var parent2 = elm2.parent;
  var next2   = elm2.nextElementSibling;

  parent1.insertBefore(elm2, next1);
  parent2.insertBefore(elm1, next2);
}