import 'dart:html';
import 'package:dnd/dnd.dart';

/// Example that uses a sub-element as drag handle.
main() {
  // Install draggable.
  Draggable(querySelector('.draggable'),
      avatarHandler: AvatarHandler.original(), handle: '.handle');
}
