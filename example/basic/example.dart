import 'dart:html';
import 'package:dnd/dnd.dart';

/// A basic example of how to use [Draggable]s and [Dropzone]s together.
main() {
  // Install draggables (documents).
  Draggable draggable = new Draggable(querySelectorAll('.document'),
      avatarHandler: new AvatarHandler.clone());

  // Install dropzone (trash).
  Dropzone dropzone = new Dropzone(querySelector('.trash'));

  // Remove the documents when dropped.
  dropzone.onDrop.listen((DropzoneEvent event) {
    event.draggableElement.remove();
    event.dropzoneElement.classes.add('full');
  });
}