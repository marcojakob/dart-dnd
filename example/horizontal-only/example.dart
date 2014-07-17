import 'dart:html';
import 'package:dnd/dnd.dart';

/**
 * An example of a how to restrict dragging to the horizontal axis. 
 * A nice side effect: When a touch drag is started in the vertical direction 
 * it is ignored and thus can be used for scrolling on touch devices.
 */
main() {
  // Install draggable.
  Draggable draggable = new Draggable(querySelector('.draggable'), 
      avatarHandler: new AvatarHandler.original(),
      horizontalOnly: true);
}