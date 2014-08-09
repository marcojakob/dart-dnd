import 'dart:html';
import 'package:dnd/dnd.dart';

/**
 * A basic example of how to use [Draggable]s and [Dropzone]s together.
 */
main() {
  // Install draggable.
  Draggable draggable = new Draggable(querySelector('.draggable'), 
      avatarHandler: new AvatarHandler.clone());
}