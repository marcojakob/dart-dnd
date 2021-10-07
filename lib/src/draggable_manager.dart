part of dnd;

/// Class responsible for managing browser events.
///
/// This class is an abstraction for the specific managers
/// [_TouchManager], [_MouseManager], and [_PointerManager].
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

    // Disable touch actions (scrolling, panning, zooming) depending on
    // horizontalOnly / verticalOnly options.
    if (drg.horizontalOnly) {
      // Only allow vertical scrolling, panning.
      drg._elements.forEach((el) => el.style.touchAction = 'pan-y');
    } else if (drg.verticalOnly) {
      // Only allow horizontal scrolling, panning.
      drg._elements.forEach((el) => el.style.touchAction = 'pan-x');
    } else {
      // No scrolling, panning.
      drg._elements.forEach((el) => el.style.touchAction = 'none');
    }
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
    _currentDrag = _DragInfo(drg.id, event.currentTarget as Element, position,
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
    _currentDrag!.position = position;

    if (!_currentDrag!.started) {
      // Test if drag has moved far enough to start drag.
      if (_currentDrag!.startPosition.distanceTo(_currentDrag!.position) >=
          drg.minDragStartDistance) {
        // Drag starts now.
        drg._handleDragStart(event);
      }
    } else {
      // Drag already started.
      Element realTarget = _getRealTarget(clientPosition);
      drg._handleDrag(event, realTarget);
    }
  }

  /// Handles all end events (touchEnd, mouseUp, and pointerUp).
  void handleEnd(Event event, EventTarget? target, Point? position,
      Point? clientPosition) {
    // Set the current position.
    if (position != null && _currentDrag != null) {
      _currentDrag!.position = position;
    }

    if (clientPosition != null) {
      EventTarget realTarget = _getRealTarget(clientPosition, target: target);
      drg._handleDragEnd(event, realTarget);
    }
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

    // Reset the touch action property.
    drg._elements.forEach((el) => el.style.touchAction = '');
  }

  /// Determine a target using `document.elementFromPoint` via the provided [clientPosition].
  ///
  /// Falls back to `document.body` if no element is found at the provided [clientPosition].
  Element _getRealTargetFromPoint(Point clientPosition) {
    return document.elementFromPoint(
            clientPosition.x.round(), clientPosition.y.round()) ??
        document.body!;
  }

  /// Determine the actual target that should receive the event because
  /// mouse or touch event might have occurred on a drag avatar.
  ///
  /// If a [target] is provided it is tested to see if is already the correct
  /// target or if it is the drag avatar and thus must be replaced by the
  /// element underneath.
  Element _getRealTarget(Point clientPosition, {EventTarget? target}) {
    // If no target was provided get it.
    if (target == null || target is! Element) {
      target = _getRealTargetFromPoint(clientPosition);
    }

    // Test if target is the drag avatar.
    if (drg.avatarHandler != null &&
        drg.avatarHandler!.avatar != null &&
        drg.avatarHandler!.avatar!.contains(target)) {
      // Target is the drag avatar, get element underneath.
      drg.avatarHandler!.avatar!.style.visibility = 'hidden';
      target = _getRealTargetFromPoint(clientPosition);
      drg.avatarHandler!.avatar!.style.visibility = 'visible';
    }

    target = _recursiveShadowDomTarget(clientPosition, target);

    return target;
  }

  /// Recursively searches for the real target inside the Shadow DOM for all
  /// Shadow hosts with the attribute [SHADOW_DOM_RETARGET_ATTRIBUTE].
  Element _recursiveShadowDomTarget(Point clientPosition, Element target) {
    // Retarget if target is a shadow host and has the specific attribute.
    if (target is Element &&
        target.shadowRoot != null &&
        target.attributes.containsKey(SHADOW_DOM_RETARGET_ATTRIBUTE)) {
      Element? newTarget = target.shadowRoot!
          .elementFromPoint(clientPosition.x.round(), clientPosition.y.round());

      // Recursive call for nested shadow DOM trees.
      if (newTarget != null) {
        target = _recursiveShadowDomTarget(clientPosition, newTarget);
      }
    }

    return target;
  }

  /// Tests if [target] is a valid place to start a drag. If [handle] is
  /// provided, drag can only start on the [handle]s. If [cancel] is
  /// provided, drag cannot be started on those elements.
  bool _isValidDragStartTarget(EventTarget target) {
    // Test if a drag was started on a cancel element.
    if (target is Element && target.matchesWithAncestors(drg.cancel)) {
      return false;
    }

    // If handle is specified, drag must start on handle or one of its children.
    if (drg.handle != null) {
      if (target is Element) {
        // 1. The target must match the handle query String.
        if (!target.matchesWithAncestors(drg.handle!)) {
          return false;
        }

        // 2. The target must be a child of the drag element(s).
        if (drg._elements.any((el) => el.contains(target))) {
          return true;
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
  _TouchManager(Draggable draggable) : super(draggable);

  @override
  void installStart() {
    drg._elements.forEach((el) {
      startSubs.add(el.onTouchStart.listen((TouchEvent event) {
        // Ignore if drag is already beeing handled.
        if (_currentDrag != null) {
          return;
        }

        // Ignore multi-touch events.
        if (event.touches != null && event.touches!.length > 1) {
          return;
        }

        // Ensure the drag started on a valid target.
        if (event.touches != null &&
            !_isValidDragStartTarget(event.touches![0].target!)) {
          return;
        }

        if (event.touches != null) {
          handleStart(event, event.touches![0].page);
        }
      }));
    });
  }

  @override
  void installMove() {
    dragSubs.add(document.onTouchMove.listen((TouchEvent event) {
      // Stop and cancel subscriptions on multi-touch.
      if (event.touches != null && event.touches!.length > 1) {
        handleCancel(event);
        return;
      }

      // Do a scrolling test if this is the first drag.
      if (event.changedTouches != null) {
        if (!_currentDrag!.started &&
            isScrolling(event.changedTouches![0].page)) {
          // The user is scrolling --> Stop tracking current drag.
          handleCancel(event);
          return;
        }

        handleMove(event, event.changedTouches![0].page,
            event.changedTouches![0].client);
      }

      // Prevent touch scrolling.
      event.preventDefault();
    }));
  }

  @override
  void installEnd() {
    dragSubs.add(document.onTouchEnd.listen((TouchEvent event) {
      handleEnd(event, null, event.changedTouches?[0].page,
          event.changedTouches?[0].client);
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
    Point delta = currentPosition - _currentDrag!.startPosition;

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
  _MouseManager(Draggable draggable) : super(draggable);

  @override
  void installStart() {
    drg._elements.forEach((el) {
      startSubs.add(el.onMouseDown.listen((MouseEvent event) {
        // Ignore if drag is already beeing handled.
        if (_currentDrag != null) {
          return;
        }

        // Only handle left clicks, ignore clicks from right or middle buttons.
        if (event.button != 0) {
          return;
        }

        // Ensure the drag started on a valid target.
        if (event.target != null && !_isValidDragStartTarget(event.target!)) {
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
        EventTarget? target = event.target;
        if (!(target is SelectElement ||
            target is InputElement ||
            target is TextAreaElement ||
            target is ButtonElement ||
            target is OptionElement)) {
          event.preventDefault();
        }

        handleStart(event, event.page);
      }));
    });
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
  _PointerManager(Draggable draggable) : super(draggable);

  @override
  void installStart() {
    drg._elements.forEach((el) {
      startSubs.add(el.on['pointerdown'].listen((e) {
        var event = e as PointerEvent;

        // Ignore if drag is already beeing handled.
        if (_currentDrag != null) {
          return;
        }

        // Only handle left clicks, ignore clicks from right or middle buttons.
        if (event.button != 0) {
          return;
        }

        // Ensure the drag started on a valid target.
        if (event.target != null && !_isValidDragStartTarget(event.target!)) {
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
        EventTarget? target = event.target;
        if (!(target is SelectElement ||
            target is InputElement ||
            target is TextAreaElement ||
            target is ButtonElement ||
            target is OptionElement)) {
          event.preventDefault();
        }

        handleStart(event, event.page);
      }));
    });
  }

  @override
  void installMove() {
    dragSubs.add(document.on['pointermove'].listen((e) {
      var event = e as PointerEvent;
      handleMove(event, event.page, event.client);
    }));
  }

  @override
  void installEnd() {
    dragSubs.add(document.on['pointerup'].listen((e) {
      var event = e as PointerEvent;
      // handleEnd(event, event.target, event.page, event.client);
      handleEnd(event, null, event.page, event.client);
    }));
  }

  @override
  void installCancel() {
    dragSubs.add(document.on['pointercancel'].listen((event) {
      handleCancel(event);
    }));
  }
}
