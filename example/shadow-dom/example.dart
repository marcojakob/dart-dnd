import 'dart:html';
import 'package:polymer/polymer.dart';

import 'package:dnd/dnd.dart';

/// Example how to use drag and drop in Shadow DOM with Polymer.
///
/// Important: You must add the "dnd-retarget" attribute on all custom elements
/// where you want events to be forwarded to it's Shadow DOM children.
main() {
  // Initialize polymer.
  initPolymer().run(() {

    // Install draggable.
    Draggable draggable = new Draggable(
        querySelectorAll('body /deep/ .draggable'),
        avatarHandler: new AvatarHandler.clone());

    // Install dropzone.
    Dropzone dropzone = new Dropzone(
        querySelectorAll('body /deep/ .dropzone'));
  });
}