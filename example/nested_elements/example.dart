import 'dart:html';
import 'package:dnd/dnd.dart';

/// Example demonstrating how to drag over nested elements and get correct
/// dragEnter and dragLeave events.
main() {
  // Install draggable.
  Draggable(querySelector('.draggable'),
      avatarHandler: AvatarHandler.original());

  // Install dropzone.
  Dropzone dropzone = Dropzone(querySelector('.dropzone'));

  // Text element
  Element text = querySelector('.dropzone > span') as Element;

  // Listen to dragEnter.
  dropzone.onDragEnter.listen((DropzoneEvent event) {
    text.text = 'Outer div: enter';
  });

  // Listen to dragLeave.
  dropzone.onDragLeave.listen((DropzoneEvent event) {
    text.text = 'Outer div: leave';
  });
}
