part of dnd;

/// The [AvatarHandler] is responsible for creating, position, and removing
/// a drag avatar. A drag avatar provides visual feedback during the drag
/// operation.
abstract class AvatarHandler {

  /// Returns the [avatar] element during a drag operation.
  ///
  /// If there is no drag operation going on, [avatar] will be null.
  Element avatar;

  /// The cached top margin of [avatar].
  num _marginTop;

  /// Returns the (cached) top margin of [avatar].
  num get marginTop {
    if (_marginTop == null) {
      cacheMargins();
    }
    return _marginTop;
  }

  /// The cached left margin of [avatar].
  num _marginLeft;

  /// Returns the (cached) left margin of [avatar].
  num get marginLeft {
    if (_marginLeft == null) {
      cacheMargins();
    }
    return _marginLeft;
  }

  /// Saved pointer events style before the drag operation.
  String _pointerEventsBeforeDrag;

  /// Default constructor.
  AvatarHandler();

  /// Creates an [AvatarHelper] that uses the draggable element itself as
  /// drag avatar.
  ///
  /// See [OriginalAvatarHandler].
  factory AvatarHandler.original() {
    return new OriginalAvatarHandler();
  }

  /// Creates an [AvatarHelper] that creates a clone of the draggable element
  /// as drag avatar. The avatar is removed at the end of the drag operation.
  ///
  /// See [CloneAvatarHandler].
  factory AvatarHandler.clone() {
    return new CloneAvatarHandler();
  }

  /// Handles the drag start.
  void _handleDragStart(Element draggable, Point startPosition) {
    dragStart(draggable, startPosition);

    // Sets the pointer-events CSS property of avatar to 'none' which enables
    // mouse and touch events to go trough to the element under the avatar.
    _pointerEventsBeforeDrag = avatar.style.pointerEvents;
    avatar.style.pointerEvents = 'none';
  }

  /// Handles the drag.
  void _handleDrag(Point startPosition, Point position) {
    drag(startPosition, position);
  }

  /// Handles the drag end.
  void _handleDragEnd(Point startPosition, Point position) {
    dragEnd(startPosition, position);

    // Reset the pointer-events CSS property to its original value.
    avatar.style.pointerEvents = _pointerEventsBeforeDrag;
    _pointerEventsBeforeDrag = null;

    // Reset avatar.
    avatar = null;

    // Reset margins (causes them to be recalculated in next drag operation).
    _marginTop = null;
    _marginLeft = null;
  }

  /// Called when the drag operation starts.
  ///
  /// This method must set the [avatar] variable and must attache it to the DOM.
  ///
  /// The provided [draggable] is used to know where in the DOM the drag avatar
  /// can be inserted.
  ///
  /// The [startPosition] is the position where the drag started, relative to the
  /// whole document (page coordinates).
  void dragStart(Element draggable, Point startPosition);

  /// Moves the drag avatar to the new [position].
  ///
  /// The [startPosition] is the position where the drag started, [position] is the
  /// current position. Both are relative to the whole document (page coordinates).
  void drag(Point startPosition, Point position);

  /// Called when the drag operation ends.
  ///
  /// The [avatar] must be removed from the DOM in this method if it is not
  /// needed any more.
  ///
  /// The [startPosition] is the position where the drag started, [position] is the
  /// current position. Both are relative to the whole document (page coordinates).
  void dragEnd(Point startPosition, Point position);

  /// Sets the CSS transform translate of [avatar]. Uses requestAnimationFrame
  /// to speed up animation.
  void setTranslate(Point position) {
    Function updateFunction = () {
      // Unsing `translate3d` to activate GPU hardware-acceleration (a bit of a hack).
      if (avatar != null) {
        avatar.style.transform = 'translate3d(${position.x}px, ${position.y}px, 0)';
      }
    };

    // Use request animation frame to update the transform translate.
    AnimationHelper.requestUpdate(updateFunction);
  }

  /// Removes the CSS transform of [avatar]. Also stops the requested animation
  /// from [setTranslate].
  void removeTranslate() {
    AnimationHelper.stop();
    avatar.style.transform = null;
  }

  /// Sets the CSS left/top values of [avatar]. Takes care of any left/top
  /// margins the [avatar] might have to correctly position the element.
  ///
  /// Note: The [avatar] must already be in the DOM for the margins to be
  /// calculated correctly.
  void setLeftTop(Point position) {
    avatar.style.left = '${position.x - marginLeft}px';
    avatar.style.top = '${position.y - marginTop}px';
  }

  /// Caches the [marginLeft] and [marginTop] of [avatar].
  ///
  /// Call this method again if those margins somehow changed during a drag
  /// operation.
  void cacheMargins() {
    // Calculate margins.
    var computedStyles = avatar.getComputedStyle();
    _marginLeft = num.parse(computedStyles.marginLeft.replaceFirst('px', ''),
        (s) => 0);
    _marginTop = num.parse(computedStyles.marginTop.replaceFirst('px', ''),
        (s) => 0);
  }
}


/// The [OriginalAvatarHandler] uses the draggable element itself as drag
/// avatar. It uses absolute positioning of the avatar.
class OriginalAvatarHandler extends AvatarHandler {

  Point _draggableStartOffset;

  @override
  void dragStart(Element draggable, Point startPosition) {
    // Use the draggable itself as avatar.
    avatar = draggable;

    // Get the start offset of the draggable (relative to the closest positioned
    // ancestor).
    _draggableStartOffset = draggable.offset.topLeft;

    // Ensure avatar has an absolute position.
    avatar.style.position = 'absolute';

    // Set the initial position of the original.
    setLeftTop(_draggableStartOffset);
  }

  @override
  void drag(Point startPosition, Point position) {
    setTranslate(position - startPosition);
  }

  @override
  void dragEnd(Point startPosition, Point position) {
    // Remove the translate and set the new position as left/top.
    removeTranslate();

    // Set the new position as left/top. Prevent from moving past the top and
    // left borders as the user might not be able to grab the element any more.
    Point constrainedPosition = new Point(math.max(1, position.x),
        math.max(1, position.y));

    setLeftTop(constrainedPosition - startPosition + _draggableStartOffset);
  }
}


/// [CloneAvatarHandler] creates a clone of the draggable element as drag avatar.
/// The avatar is removed at the end of the drag operation.
class CloneAvatarHandler extends AvatarHandler {

  @override
  void dragStart(Element draggable, Point startPosition) {
    // Clone the draggable to create the avatar.
    avatar = (draggable.clone(true) as Element)
        ..attributes.remove('id')
        ..style.cursor = 'inherit';

    // Ensure avatar has an absolute position.
    avatar.style.position = 'absolute';
    avatar.style.zIndex = '100';

    // Add the drag avatar to the parent element.
    draggable.parentNode.append(avatar);

    // Set the initial position of avatar (relative to the closest positioned
    // ancestor).
    setLeftTop(draggable.offset.topLeft);
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


/// Simple helper class to speed up animation with requestAnimationFrame.
class AnimationHelper {

  static Function _lastUpdateFunction;
  static bool _updating = false;

  /// Requests that the [updateFunction] be called. When the animation frame is
  /// ready, the [updateFunction] is executed. Note that any subsequent calls
  /// in the same frame will overwrite the [updateFunction].
  static void requestUpdate(void updateFunction()) {
    _lastUpdateFunction = updateFunction;

    if (!_updating) {
      window.animationFrame.then((_) => _update());
      _updating = true;
    }
  }

  /// Stops the updating.
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