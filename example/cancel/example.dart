import 'dart:html';
import 'package:dnd/dnd.dart';

/// Example demonstrating how dragging can be prevented on some elements.
main() {
  // Install draggable.
  Draggable(querySelector('.draggable'),
      avatarHandler: AvatarHandler.original(),
      cancel: 'textarea, button, .no-drag');
}
