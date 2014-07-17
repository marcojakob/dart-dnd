import 'dart:html';
import 'package:dnd/dnd.dart';

/**
 * Uses Acceptors to determine which Draggables are accepted by which Dropzones.
 */
main() {
  // Install draggables.
  Draggable draggableA = new Draggable(querySelector('#draggable-a'), 
      avatarHandler: new AvatarHandler.clone());
  Draggable draggableB = new Draggable(querySelector('#draggable-b'), 
      avatarHandler: new AvatarHandler.clone());
  Draggable draggableC = new Draggable(querySelector('#draggable-c'), 
      avatarHandler: new AvatarHandler.clone());
  
  
  // No acceptor means everything is accepted.
  Dropzone dropzone1 = new Dropzone(querySelector('#dropzone-1'));
  
  // Use provided DraggablesAcceptor to accept Draggables A and C.
  Dropzone dropzone2 = new Dropzone(querySelector('#dropzone-2'), 
      acceptor: new Acceptor.draggables([draggableA, draggableC]));
  
  // Use a custom Acceptor that accepts Draggables with a input containing 
  // the text 'acceptme'.
  Dropzone dropzone3 = new Dropzone(querySelector('#dropzone-3'), 
      acceptor: new MyAcceptor());
}

/**
 * Custom acceptor that accepts [Draggable]s with an input containing
 * the text 'acceptme'.
 */
class MyAcceptor extends Acceptor {
  
  @override
  bool accepts(Element draggableElement, int draggableId, Element dropzoneElement) {
    InputElement input = draggableElement.querySelector('input');
    return input != null && input.value == 'acceptme';
  }
}