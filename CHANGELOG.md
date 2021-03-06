# Changelog

## Version 2.0.0 (2021-03-06)

- Migrate to null safety.

## Version 1.4.3 (2019-12-10)

- Remove unnecessary new keyword.

## Version 1.4.2 (2019-02-13)

- Fix #30: Cannot initialize Dropzone with List<HtmlElement>.
- Follow more code style conventions.
- Update dependencies.

## Version 1.4.0 (2018-10-12)

- Add an option `minDragStartDistance` on `Draggable` to define the minimum distance in
  pixels that is needed for a drag to start (#26). Default is `4` pixels. This allows for clicks with tiny movement. The option `clickSuppression` has been marked as DEPRECATED as it had the same goal but a misleading name.

## Version 1.3.0 (2018-08-15)

- Align dart version to support Dart 2 (#25).

## Version 1.2.0 (2018-06-21)

- Support for creating a Draggable with `List<Element>` (in addition to `ElementList` and `Element`).

## Version 1.1.0 (2018-06-21)

- Remove cursor files. Support for `grab`, `-webkit-grab`, `grabbing`, and `-webkit-grabbing` is good enough.

## Version 1.0.0 (2018-06-13)

- Migrate to Dart 2.
- Since Chrome 56 touch event listeners are [treated as passive by default](https://www.chromestatus.com/features/5093566007214080). This disables the possibility to call `preventDefault` on an element which we must do to tell the browser not to scroll while dragging. To fix this in Chrome we set the `touch-action` css property. With this Chrome will not scroll (`none`) or only scroll in one direction (`pan-y` or `pan-x`).

## Version 0.4.0 (2017-06-27)

- Fix strong mode errors (#20).

## Version 0.3.6 (2017-06-06)

- Fix bug: Provide reasonable fallback for event target when mouse position exits viewport (#19).

## Version 0.3.5 (2016-11-22)

- Handle the edge case where destroy is called while dragging an avatar (#17).

## Version 0.3.4 (2016-10-19)

- Fix strong-mode type errors (#15).
- Remove Shadow DOM example and (dev)dependency on Polymer (was causing some confusion).

## Version 0.3.3 (2016-09-22)

- Allow a configurable clickSuppression distance (#13). We found that the click
  suppression was a little too aggressive for users with less mousing accuracy.
  They would attempt to click and trigger a small drag. Which then suppressed the
  click event and prevented the action they intended to complete.

## Version 0.3.2 (2016-07-26)

- Remove null-aware operator since drone.io uses an old version of Dart that doesn't support this yet.

## Version 0.3.1 (2016-07-26)

- Support for programmatic drag abort (see issue #11).

## Version 0.3.0 (2015-04-18)

- BREAKING CHANGE: Refactoring the `AvatarHandler`. Only if you've
  implemented a custom `AvatarHandler` you might need to do some changes:
  - `setPointerEventsNone` and `resetPointerEvents` were removed and don't
    need to be called any more. Pointer event styles are handled automatically.
- Fix `AvatarHandler` margin caching: The `AvatarHandler` only cached the
  margins once for every `Draggable`. This caused problems when margins of
  elements in the same `Draggable` had different margins or the margins were
  changed. Now the margins are reset after every drag.

## Version 0.2.1 (2015-03-09)

- Fix #9: Using transformers in the main `pubspec.yaml` caused problems with
  projects depending on the `dnd` package.

## Version 0.2.0 (2015-03-09)

- Fix #3: Shadow DOM is now supported. A `dnd-retarget` attribute must be added
  to all custom elements where events should be forwarded to the Shadow DOM
  children.
- Fix #7: Add a css class (`dnd-invalid` by default) to dropzones when a
  not-accepted draggable is dragged over.

## Version 0.1.4 (2014-10-20)

- Add a sortable example.
- Change comments according to new Dart Style Guide rule
  (`///` instead of `/** */`).
- Move event dispatching calls from EventManager to Draggable (refactoring).

## Version 0.1.3 (2014-08-09)

- Fix #4: Problem when an ancestor of the dragged element was positioned
  (relative, absolute, fixed).

## Version 0.1.2 (2014-07-22)

- Correcting small bug that occurred when setSelectionRange() was called on
  an element that does not support it.
- Fix Pointer Event bug: Too many event listeners in move, end, cancel.
- Fix for Bug #1 - Not working in Windows 8.1 IE11
- Adding a `cancelled` flag to `DraggableEvent` to indicate if a drag ended
  because of a cancelling operation like `esc` key, etc.

## Version 0.1.1 (2014-07-21)

- Support for IE10 and IE11 touch screens through pointer events.
- Removed `disableTouch` and `disableMouse` options. The goal was to unify
  touch and mouse dragging, so it should not be necessary to disable
  one or the other.

## Version 0.1.0 (2014-07-17)

- First version.
