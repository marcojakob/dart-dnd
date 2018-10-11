import 'dart:html';
import 'package:dnd/dnd.dart';

/// Uses Acceptors to determine which Draggables are accepted by which Dropzones.
main() {
  // Install draggables.
  new Draggable(querySelector('#draggable-a'),
      avatarHandler: new AvatarHandler.clone());
  var draggableB = new Draggable(querySelector('#draggable-b'),
      avatarHandler: new AvatarHandler.clone());
  new Draggable(querySelector('#draggable-c'),
      avatarHandler: new AvatarHandler.clone());

  // No acceptor means everything is accepted.
  new Dropzone(querySelector('#dropzone-1'));

  // Use provided DraggablesAcceptor to accept Draggable B only.
  new Dropzone(querySelector('#dropzone-2'),
      acceptor: new Acceptor.draggables([draggableB]));

  // Use a custom Acceptor that accepts Draggables with a input containing
  // the text 'acceptme'.
  new Dropzone(querySelector('#dropzone-3'), acceptor: new MyAcceptor());
}

/**
 * Custom acceptor that accepts [Draggable]s with an input containing
 * the text 'acceptme'.
 */
class MyAcceptor extends Acceptor {
  @override
  bool accepts(
      Element draggableElement, int draggableId, Element dropzoneElement) {
    InputElement input = draggableElement.querySelector('input');
    return input != null && input.value == 'acceptme';
  }
}
