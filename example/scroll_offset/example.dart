import 'dart:html';
import 'package:dnd/dnd.dart';

/// A test with a draggable that has a scrollable parent.
main() {
  // Install draggable.
  Draggable(querySelector('.draggable'), avatarHandler: AvatarHandler.clone());

  // Install dropzone.
  Dropzone(querySelector('.dropzone'));
}
