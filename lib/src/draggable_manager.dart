part of dnd;

/// Class responsible for managing browser events.
///
/// This class is an abstraction for the specific managers like
/// [_TouchManager], [_MouseManager], etc.
abstract class _EventManager {

  /// Attribute to mark custom elements where events should be retargeted
  /// to their Shadow DOM children.
  static const String SHADOW_DOM_RETARGET_ATTRIBUTE = 'dnd-retarget';

  /// Tracks subscriptions for start events (mouseDown, touchStart).
  List<StreamSubscription> startSubs = [];

  /// Tracks subscriptions for all other events (mouseMove, touchMove, mouseUp,
  /// touchEnd, and more).
  List<StreamSubscription> dragSubs = [];

  /// A reference back to the [Draggable].
  final Draggable drg;

  _EventManager(this.drg) {
    // Install the start listeners when constructed.
    installStart();
  }

  /// Installs the start listeners (e.g. mouseDown, touchStart, etc.).
  void installStart();

  /// Installs the move listeners (e.g. mouseMove, touchMove, etc.).
  void installMove();

  /// Installs the end listeners (e.g. mouseUp, touchEnd, etc.).
  void installEnd();

  /// Installs the cancel listeners (e.g. touchCancel, pointerCancel, etc.).
  void installCancel();

  /// Installs listener for esc-key and blur (window loses focus). Those
  /// events will cancel the drag operation.
  void installEscAndBlur() {
    // Drag ends when escape key is hit.
    dragSubs.add(window.onKeyDown.listen((keyboardEvent) {
      if (keyboardEvent.keyCode == KeyCode.ESC) {
        handleCancel(keyboardEvent);
      }
    }));

    // Drag ends when focus is lost.
    dragSubs.add(window.onBlur.listen((event) {
      handleCancel(event);
    }));
  }

  /// Handles a start event (touchStart, mouseUp, etc.).
  void handleStart(Event event, Point position) {
    // Initialize the drag info.
    // Note: the drag is not started on touchStart but after a first valid move.
    _currentDrag = new _DragInfo(drg.id, event.currentTarget, position,
        avatarHandler: drg.avatarHandler,
        horizontalOnly: drg.horizontalOnly,
        verticalOnly: drg.verticalOnly);

    // Install listeners to detect a drag move, end, or cancel.
    installMove();
    installEnd();
    installCancel();
    installEscAndBlur();
  }

  /// Handles a move event (touchMove, mouseMove, etc.).
  void handleMove(Event event, Point position, Point clientPosition) {
    // Set the current position.
    _currentDrag.position = position;

    if (!_currentDrag.started
        && _currentDrag.startPosition != _currentDrag.position) {
      // This is the first drag move.

      // Handle dragStart.
      drg._handleDragStart(event);
    }

    // Handle drag (will also be called after drag start).
    if (_currentDrag.started) {
      Element realTarget = _getRealTarget(clientPosition);
      drg._handleDrag(event, realTarget);
    }
  }

  /// Handles all end events (touchEnd, mouseUp, and pointerUp).
  void handleEnd(Event event, EventTarget target, Point position, Point clientPosition) {
    // Set the current position.
    _currentDrag.position = position;

    EventTarget realTarget = _getRealTarget(clientPosition, target: target);
    drg._handleDragEnd(event, realTarget);
  }

  /// Handles all cancel events (touchCancel and pointerCancel).
  void handleCancel(Event event) {
    // Drag end with the cancelled flag.
    drg._handleDragEnd(event, null, cancelled: true);
  }

  /// Resets this [_EventManager] to its initial state. This means that all
  /// listeners are canceled except the listeners set up during [installStart].
  void reset() {
    // Cancel drag subscriptions.
    dragSubs.forEach((sub) => sub.cancel());
    dragSubs.clear();
  }

  /// Cancels all listeners, including the listeners set up during [installStart].
  void destroy() {
    reset();

    // Cancel start subscriptions.
    startSubs.forEach((sub) => sub.cancel());
    startSubs.clear();
  }

  /// Determine the actual target that should receive the event because
  /// mouse or touch event might have occurred on a drag avatar.
  ///
  /// If a [target] is provided it is tested to see if is already the correct
  /// target or if it is the drag avatar and thus must be replaced by the
  /// element underneath.
  EventTarget _getRealTarget(Point clientPosition, {EventTarget target}) {
    // If no target was provided get it.
    if (target == null) {
      target = document.elementFromPoint(clientPosition.x, clientPosition.y);
    }

    // Test if target is the drag avatar.
    if (drg.avatarHandler != null && drg.avatarHandler.avatar != null
        && drg.avatarHandler.avatar.contains(target)) {

      // Target is the drag avatar, get element underneath.
      drg.avatarHandler.avatar.style.visibility = 'hidden';
      target = document.elementFromPoint(clientPosition.x, clientPosition.y);
      drg.avatarHandler.avatar.style.visibility = 'visible';
    }

    target = _recursiveShadowDomTarget(clientPosition, target);

    return target;
  }

  /// Recursively searches for the real target inside the Shadow DOM for all
  /// Shadow hosts with the attribute [SHADOW_DOM_RETARGET_ATTRIBUTE].
  EventTarget _recursiveShadowDomTarget(Point clientPosition, EventTarget target) {

    // Retarget if target is a shadow host and has the specific attribute.
    if (target is Element && target.shadowRoot != null &&
        target.attributes.containsKey(SHADOW_DOM_RETARGET_ATTRIBUTE)) {

      Element newTarget = (target as Element).shadowRoot
          .elementFromPoint(clientPosition.x, clientPosition.y);

      // Recursive call for nested shadow DOM trees.
      target = _recursiveShadowDomTarget(clientPosition, newTarget);
    }

    return target;
  }

  /// Tests if [target] is a valid place to start a drag. If [handle] is
  /// provided, drag can only start on the [handle]s. If [cancel] is
  /// provided, drag cannot be started on those elements.
  bool _isValidDragStartTarget(EventTarget target) {
    // Test if a drag was started on a cancel element.
    if (drg.cancel != null
        && target is Element
        && target.matchesWithAncestors(drg.cancel)) {

      return false;
    }

    // If handle is specified, drag must start on handle or one of its children.
    if (drg.handle != null) {
      if (target is Element) {
        // 1. The target must match the handle query String.
        if (!target.matchesWithAncestors(drg.handle)) {
          return false;
        }

        // 2. The target must be a child of the drag element(s).
        if (drg._elementOrElementList is ElementList) {
          for (Element el in drg._elementOrElementList) {
            if (el.contains(target)) {
              return true;
            }
          }
        } else {
          if ((drg._elementOrElementList as Element).contains(target)) {
            return true;
          }
        }
      }

      // Has a handle specified but we did not find a match.
      return false;
    }

    return true;
  }
}

/// Manages the browser's touch events.
class _TouchManager extends _EventManager {

  _TouchManager(Draggable draggable)
      : super(draggable);

  @override
  void installStart() {
    startSubs.add(drg._elementOrElementList.onTouchStart.listen((TouchEvent event) {
      // Ignore if drag is already beeing handled.
      if (_currentDrag != null) {
        return;
      }

      // Ignore multi-touch events.
      if (event.touches.length > 1) {
        return;
      }

      // Ensure the drag started on a valid target.
      if (!_isValidDragStartTarget(event.touches[0].target)) {
        return;
      }

      handleStart(event, event.touches[0].page);
    }));
  }

  @override
  void installMove() {
    dragSubs.add(document.onTouchMove.listen((TouchEvent event) {
      // Stop and cancel subscriptions on multi-touch.
      if (event.touches.length > 1) {
        handleCancel(event);
        return;
      }

      // Do a scrolling test if this is the first drag.
      if (!_currentDrag.started && isScrolling(event.changedTouches[0].page)) {
        // The user is scrolling --> Stop tracking current drag.
        handleCancel(event);
        return;
      }

      handleMove(event, event.changedTouches[0].page,
          event.changedTouches[0].client);

      // Prevent touch scrolling.
      event.preventDefault();
    }));
  }

  @override
  void installEnd() {
    dragSubs.add(document.onTouchEnd.listen((TouchEvent event) {
      handleEnd(event, null, event.changedTouches[0].page, event.changedTouches[0].client);
    }));
  }

  @override
  void installCancel() {
    dragSubs.add(document.onTouchCancel.listen((TouchEvent event) {
      handleCancel(event);
    }));
  }

  /// Returns true if there was scrolling activity instead of dragging.
  bool isScrolling(Point currentPosition) {
    Point delta = currentPosition - _currentDrag.startPosition;

    // If horizontalOnly test for vertical movement.
    if (drg.horizontalOnly && delta.y.abs() > delta.x.abs()) {
      // Vertical scrolling.
      return true;
    }

    // If verticalOnly test for horizontal movement.
    if (drg.verticalOnly && delta.x.abs() > delta.y.abs()) {
      // Horizontal scrolling.
      return true;
    }

    // No scrolling.
    return false;
  }
}

/// Manages the browser's mouse events.
class _MouseManager extends _EventManager {

  _MouseManager(Draggable draggable)
      : super(draggable);


  @override
  void installStart() {
    startSubs.add(drg._elementOrElementList.onMouseDown.listen((MouseEvent event) {
      // Ignore if drag is already beeing handled.
      if (_currentDrag != null) {
        return;
      }

      // Only handle left clicks, ignore clicks from right or middle buttons.
      if (event.button != 0) {
        return;
      }

      // Ensure the drag started on a valid target.
      if (!_isValidDragStartTarget(event.target)) {
        return;
      }

      // Prevent default on mouseDown. Reasons:
      // * Disables image dragging handled by the browser.
      // * Disables text selection.
      //
      // Note: We must NOT prevent default on form elements. Reasons:
      // * SelectElement would not show a dropdown.
      // * InputElement and TextAreaElement would not get focus.
      // * ButtonElement and OptionElement - don't know if this is needed??
      Element target = event.target;
      if (!(target is SelectElement || target is InputElement ||
            target is TextAreaElement || target is ButtonElement ||
            target is OptionElement)) {
        event.preventDefault();
      }

      handleStart(event, event.page);
    }));
  }

  @override
  void installMove() {
    dragSubs.add(document.onMouseMove.listen((MouseEvent event) {
      handleMove(event, event.page, event.client);
    }));
  }

  @override
  void installEnd() {
    dragSubs.add(document.onMouseUp.listen((MouseEvent event) {
      handleEnd(event, event.target, event.page, event.client);
    }));
  }

  @override
  void installCancel() {
    // No mouse cancel event.
  }
}

/// Manages the browser's pointer events (used for Internet Explorer).
class _PointerManager extends _EventManager {

  bool msPrefix;

  _PointerManager(Draggable draggable, {this.msPrefix: false})
      : super(draggable);

  @override
  void installStart() {
    String downEventName = msPrefix ? 'MSPointerDown' : 'pointerdown';

    // Function to be called on all elements of [_elementOrElementList].
    var installFunc = (Element element) {
      startSubs.add(element.on[downEventName].listen((event) {
        // Ignore if drag is already beeing handled.
        if (_currentDrag != null) {
          return;
        }

        // Only handle left clicks, ignore clicks from right or middle buttons.
        if (event.button != 0) {
          return;
        }

        // Ensure the drag started on a valid target.
        if (!_isValidDragStartTarget(event.target)) {
          return;
        }

        // Prevent default on mouseDown. Reasons:
        // * Disables image dragging handled by the browser.
        // * Disables text selection.
        //
        // Note: We must NOT prevent default on form elements. Reasons:
        // * SelectElement would not show a dropdown.
        // * InputElement and TextAreaElement would not get focus.
        // * ButtonElement and OptionElement - don't know if this is needed??
        Element target = event.target;
        if (!(target is SelectElement || target is InputElement ||
              target is TextAreaElement || target is ButtonElement ||
              target is OptionElement)) {
          event.preventDefault();
        }

        handleStart(event, event.page);
      }));
    };

    // The [ElementList] does not have the `on` method for custom events. So,
    // we need to manually go trough all [Element]s and call the [installFunc].
    if (drg._elementOrElementList is ElementList) {
      drg._elementOrElementList.forEach(installFunc);
    } else {
      installFunc(drg._elementOrElementList);
    }

    // Disable default touch actions on all elements (scrolling, panning, zooming).
    if (msPrefix) {
      drg._elementOrElementList.style.setProperty('-ms-touch-action',
          _getTouchActionValue());
    } else {
      drg._elementOrElementList.style.setProperty('touch-action',
          _getTouchActionValue());
    }
  }

  @override
  void installMove() {
    String moveEventName = msPrefix ? 'MSPointerMove' : 'pointermove';

    dragSubs.add(document.on[moveEventName].listen((event) {
      handleMove(event, event.page, event.client);
    }));
  }

  @override
  void installEnd() {
    String endEventName = msPrefix ? 'MSPointerUp' : 'pointerup';

    dragSubs.add(document.on[endEventName].listen((event) {
      handleEnd(event, event.target, event.page, event.client);
    }));
  }

  @override
  void installCancel() {
    String cancelEventName = msPrefix ? 'MSPointerCancel' : 'mspointercancel';

    dragSubs.add(document.on[cancelEventName].listen((event) {
      handleCancel(event);
    }));
  }

  /// Returns the touch-action values `none`, `pan-x`, or `pan-y` depending on
  /// horizontalOnly / verticalOnly options.
  String _getTouchActionValue() {
    if (drg.horizontalOnly) {
      return 'pan-y';
    }
    if (drg.verticalOnly) {
      return 'pan-x';
    }
    return 'none';
  }
}