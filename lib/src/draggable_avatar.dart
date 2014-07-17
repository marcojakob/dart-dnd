part of dnd;

/**
 * The [AvatarHandler] is responsible for creating, position, and removing 
 * a drag avatar. A drag avatar provides visual feedback during the drag 
 * operation.
 */
abstract class AvatarHandler {
  
  AvatarHandler();
  
  /// Returns the [avatar] element.
  Element get avatar;
  
  /// The cached top margin of [avatar].
  num _marginTop;
  
  /// Returns the (cached) top margin of [avatar].
  num get marginTop {
    if (_marginTop == null) {
      _cacheMargins();
    }
    return _marginTop;
  }
  
  /// The cached left margin of [avatar].
  num _marginLeft;
  
  /// Returns the (cached) left margin of [avatar].
  num get marginLeft {
    if (_marginLeft == null) {
      _cacheMargins();
    }
    return _marginLeft;
  }
  
  /**
   * Creates an [AvatarHelper] that uses the draggable element itself as 
   * drag avatar.
   * 
   * See [OriginalAvatarHandler].
   */
  factory AvatarHandler.original() {
    return new OriginalAvatarHandler();
  }
  
  /**
   * Creates an [AvatarHelper] that creates a clone of the draggable element
   * as drag avatar. The avatar is removed at the end of the drag operation.
   * 
   * See [CloneAvatarHandler].
   */
  factory AvatarHandler.clone() {
    return new CloneAvatarHandler();
  }
  
  /**
   * Called when the drag operation starts. 
   * 
   * A drag avatar is created and attached to the DOM.
   * 
   * The provided [draggable] is used to know where in the DOM the drag avatar
   * can be inserted.
   * 
   * The [startPosition] is the position where the drag started, relative to the 
   * whole document (page coordinates).
   */
  void dragStart(Element draggable, Point startPosition);
  
  /**
   * Moves the drag avatar to the new [position]. 
   * 
   * The [startPosition] is the position where the drag started, [position] is the 
   * current position. Both are relative to the whole document (page coordinates).
   */
  void drag(Point startPosition, Point position);
  
  /**
   * Called when the drag operation ends. 
   * 
   * The [startPosition] is the position where the drag started, [position] is the 
   * current position. Both are relative to the whole document (page coordinates).
   */
  void dragEnd(Point startPosition, Point position);
  
  /**
   * Sets the CSS transform translate of [avatar]. Uses requestAnimationFrame
   * to speed up animation.
   */
  void setTranslate(Point position) {
    Function updateFunction = () {
      // Unsing `translate3d` to activate GPU hardware-acceleration (a bit of a hack).
      avatar.style.transform = 'translate3d(${position.x}px, ${position.y}px, 0)';
    };
    
    // Use request animation frame to update the transform translate.
    AnimationHelper.requestUpdate(updateFunction);            
  }
  
  /**
   * Removes the CSS transform of [avatar]. Also stops the requested animation
   * from [setTranslate].
   */
  void removeTranslate() {
    AnimationHelper.stop();
    avatar.style.transform = null;
  }
  
  /**
   * Sets the CSS top/left values of [avatar]. Takes care of any top/left
   * margins the [avatar] might have to correctly position the element.
   */
  void setTopLeft(Point position) {
    avatar.style.top = '${position.y - marginTop}px';
    avatar.style.left = '${position.x - marginLeft}px';
  }
  
  /**
   * Helper method to get the offset of [element] relative to the document.
   */
  Point pageOffset(Element element) {
    Rectangle rect = element.getBoundingClientRect();
    return new Point(
        (rect.left + window.pageXOffset - document.documentElement.client.left).round(), 
        (rect.top + window.pageYOffset - document.documentElement.client.top).round());
  }
  
  /**
   * Sets the pointer-events CSS property of [avatar] to 'none' which enables 
   * mouse and touch events to go trough to the element under the [avatar].
   */
  void setPointerEventsNone() {
    avatar.style.pointerEvents = 'none';
  }
  
  /**
   * Removes the pointer-events CSS property from [avatar].
   */
  void resetPointerEvents() {
    avatar.style.pointerEvents = null;
  }
  
  /**
   * Caches the margins of [avatar].
   */
  void _cacheMargins() {
    // Calculate margins.
    var marginEdge = avatar.marginEdge;
    var borderEdge = avatar.borderEdge;
    
    _marginTop = borderEdge.top - marginEdge.top;
    _marginLeft = borderEdge.left - marginEdge.left;
  }
}


/**
 * The [OriginalAvatarHandler] uses the draggable element itself as drag 
 * avatar. It uses absolute positioning of the avatar.
 */
class OriginalAvatarHandler extends AvatarHandler {
  
  /// The avatar element which is created in [dragStart].
  Element avatar;
  
  Point _dragStartOffset;
  
  @override
  void dragStart(Element draggable, Point startPosition) {
    // Use the draggable itself as avatar.
    avatar = draggable;
    
    // Calc the start offset of the mouse relative to the draggable.
    _dragStartOffset = pageOffset(draggable);
    Point mouseOffset = startPosition - _dragStartOffset;
    
    // Set pointer-events to none.
    setPointerEventsNone();
    
    // Ensure avatar has an absolute position.
    avatar.style.position = 'absolute';
    
    // Set the initial position of the original.
    setTopLeft(startPosition - mouseOffset);
  }
  
  @override
  void drag(Point startPosition, Point position) {
    setTranslate(position - startPosition);
  }
  
  @override
  void dragEnd(Point startPosition, Point position) {
    // Remove the translate and set the new position as left/top.
    removeTranslate();
    setTopLeft(position - startPosition + _dragStartOffset);
    
    resetPointerEvents();
  }
}


/**
 * [CloneAvatarHandler] creates a clone of the draggable element as drag avatar.
 * The avatar is removed at the end of the drag operation.
 */
class CloneAvatarHandler extends AvatarHandler {
  
  /// The avatar element which is created in [dragStart].
  Element avatar;
  
  @override
  void dragStart(Element draggable, Point startPosition) {
    // Clone the draggable to create the avatar.
    avatar = (draggable.clone(true) as Element)
        ..attributes.remove('id')
        ..style.cursor = 'inherit';
    
    // Calc the position of the draggable.
    Point draggablePosition = pageOffset(draggable);
    
    // Set the initial position of avatar.
    setTopLeft(draggablePosition);
    
    // Ensure avatar has an absolute position.
    avatar.style.position = 'absolute';
    avatar.style.zIndex = '100';
    
    // Set pointer-events to none.
    setPointerEventsNone();
    
    // Add the drag avatar to the parent element.
    draggable.parentNode.append(avatar);
  }
  
  @override
  void drag(Point startPosition, Point position) {
    setTranslate(position - startPosition);
  }
  
  @override
  void dragEnd(Point startPosition, Point position) {
    avatar.remove();
  }
}


/**
 * Simple helper class to speed up animation with requestAnimationFrame.
 */
class AnimationHelper {
  
  static Function _lastUpdateFunction;
  static bool _updating = false;
  
  /**
   * Requests that the [updateFunction] be called. When the animation frame is
   * ready, the [updateFunction] is executed. Note that any subsequent calls 
   * in the same frame will overwrite the [updateFunction]. 
   */
  static void requestUpdate(void updateFunction()) {
    _lastUpdateFunction = updateFunction;
    
    if (!_updating) {
      window.animationFrame.then((_) => _update());
      _updating = true;
    }
  }
  
  /**
   * Stops the updating.
   */
  static void stop() {
    _updating = false;
  }
  
  static void _update() {
    // Test if it wasn't stopped.
    if (_updating) {
      _lastUpdateFunction();
      _updating = false;
    }
  }
}