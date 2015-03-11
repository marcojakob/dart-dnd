import 'dart:html';
import 'package:dnd/dnd.dart';

/// A test with a draggable that has a scrollable parent.
main() {
  // Install draggable.
  Draggable draggable = new Draggable(querySelector('.draggable'),
      avatarHandler: new AvatarHandler.clone());

  // Install dropzone.
  Dropzone dropzone = new Dropzone(querySelector('.dropzone'));
}