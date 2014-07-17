import 'dart:html';
import 'package:dnd/dnd.dart';

/**
 * Example demonstrating how dragging can be prevented on some elements.
 */
main() {
  // Install draggable.
  Draggable draggable = new Draggable(querySelector('.draggable'), 
      avatarHandler: new AvatarHandler.original(),
      cancel: 'textarea, button, .no-drag');
}