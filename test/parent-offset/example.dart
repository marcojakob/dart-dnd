import 'dart:html';
import 'package:dnd/dnd.dart';

/// A test with a draggable that has a parent with offset > 0.
main() {
  // Install draggable.
  Draggable draggable = new Draggable(querySelector('.draggable'), 
      avatarHandler: new AvatarHandler.clone());
}