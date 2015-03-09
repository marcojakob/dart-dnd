# Changelog

## Version 0.2.1 (2014-03-09)

* Fix #9: Using transformers in the main `pubspec.yaml` caused problems with 
  projects depending on the `dnd` package.


## Version 0.2.0 (2014-03-09)

* Fix #3: Shadow DOM is now supported. A `dnd-retarget` attribute must be added
  to all custom elements where events should be forwarded to the Shadow DOM
  children.
* Fix #7: Add a css class (`dnd-invalid` by default) to dropzones when a 
  not-accepted draggable is dragged over.


## Version 0.1.4 (2014-10-20)

* Add a sortable example.
* Change comments according to new Dart Style Guide rule 
  (`///` instead of `/** */`).
* Move event dispatching calls from EventManager to Draggable (refactoring). 


## Version 0.1.3 (2014-08-09)

* Fix #4: Problem when an ancestor of the dragged element was positioned
  (relative, absolute, fixed). 


## Version 0.1.2 (2014-07-22)

* Correcting small bug that occurred when setSelectionRange() was called on 
  an element that does not support it.
* Fix Pointer Event bug: Too many event listeners in move, end, cancel.
* Fix for Bug #1 - Not working in Windows 8.1 IE11
* Adding a `cancelled` flag to `DraggableEvent` to indicate if a drag ended 
  because of a cancelling operation like `esc` key, etc.


## Version 0.1.1 (2014-07-21)

* Support for IE10 and IE11 touch screens through pointer events.
* Removed `disableTouch` and `disableMouse` options. The goal was to unify
  touch and mouse dragging, so it should not be necessary to disable 
  one or the other.
  
  
## Version 0.1.0 (2014-07-17)

* First version.
