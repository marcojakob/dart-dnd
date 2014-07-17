import 'dart:html';
import 'package:dnd/dnd.dart';

/**
 * An example of a how to freely drag a [Draggable]. Instead of using a clone
 * for the drag avatar, the original element itself is dragged.
 */
main() {
  // Install draggable.
  Draggable draggable = new Draggable(querySelector('.draggable'), 
      avatarHandler: new AvatarHandler.original());
}