import 'dart:html';
import 'package:dnd/dnd.dart';

/// Uses Acceptors to determine which Draggables are accepted by which Dropzones.
main() {
  // Install draggables.
  Draggable(querySelector('#draggable-a'),
      avatarHandler: AvatarHandler.clone());
  var draggableB = Draggable(querySelector('#draggable-b'),
      avatarHandler: AvatarHandler.clone());
  Draggable(querySelector('#draggable-c'),
      avatarHandler: AvatarHandler.clone());

  // No acceptor means everything is accepted.
  Dropzone(querySelector('#dropzone-1'));

  // Use provided DraggablesAcceptor to accept Draggable B only.
  Dropzone(querySelector('#dropzone-2'),
      acceptor: Acceptor.draggables([draggableB]));

  // Use a custom Acceptor that accepts Draggables with a input containing
  // the text 'acceptme'.
  Dropzone(querySelector('#dropzone-3'), acceptor: MyAcceptor());
}

/**
 * Custom acceptor that accepts [Draggable]s with an input containing
 * the text 'acceptme'.
 */
class MyAcceptor extends Acceptor {
  @override
  bool accepts(
      Element draggableElement, int draggableId, Element dropzoneElement) {
    InputElement? input =
        draggableElement.querySelector('input') as InputElement?;
    return input != null && input.value == 'acceptme';
  }
}
