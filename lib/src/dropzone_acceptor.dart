part of dnd;

/**
 * An acceptor defines which draggable elements are accepted by a [Dropzone].
 */
abstract class Acceptor {
  
  Acceptor();
  
  /**
   * Creates an [Acceptor] that accepts all drag elements that are part of the 
   * specified [draggables].
   * 
   * See [DraggableAcceptor].
   */
  factory Acceptor.draggable(List<Draggable> draggables) {
    return new DraggableAcceptor(draggables);
  }
  
  /**
   * Returns true if the [draggableElement] with [draggableId] should be 
   * accepted by the [dropzoneElement].
   */
  bool accepts(Element draggableElement, int draggableId, Element dropzoneElement);
}

/**
 * The [DraggableAcceptor] accepts all drag elements that are part of the 
 * specified list of [Draggable]s. 
 */
class DraggableAcceptor extends Acceptor {
  
  final Set<int> draggableIds = new Set();
  
  DraggableAcceptor(List<Draggable> draggables) {
    draggables.forEach((d) => draggableIds.add(d.id));
  }
  
  @override
  bool accepts(Element draggableElement, int draggableId, Element dropzoneElement) {
    return draggableIds.contains(draggableId);
  }
}