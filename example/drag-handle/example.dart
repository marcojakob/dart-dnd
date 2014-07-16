library dnd_example;

import 'dart:html';
import 'package:dnd/dnd.dart';

/**
 * Example that uses a sub-element as drag handle.
 */
main() {
  // Install draggable (document).
  Draggable draggable = new Draggable(querySelector('.draggable'), 
      avatarHandler: new AvatarHandler.original(),
      handle: '.handle');
}