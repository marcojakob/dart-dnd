# Dart Drag and Drop

Drag and Drop for Dart web apps with mouse and touch support.

[![Star this Repo](https://img.shields.io/github/stars/marcojakob/dart-dnd.svg?style=flat-square)](https://github.com/marcojakob/dart-dnd)
[![Pub Package](https://img.shields.io/pub/v/dnd.svg?style=flat-square)](https://pub.dartlang.org/packages/dnd)

[GitHub](https://github.com/marcojakob/dart-dnd) |
[Pub](https://pub.dartlang.org/packages/dnd) |
[Demos and Examples](http://code.makery.ch/library/dart-drag-and-drop/)

![DnD Screenshot](https://raw.githubusercontent.com/marcojakob/dart-dnd/master/doc/dnd-screenshot.png)

## Features

- Use any HTML Element as `Draggable` or `Dropzone`.
- Mouse and Touch dragging.
- Draggable events: `dragStart`, `drag`, and `dragEnd`
- Dropzone events: `dragEnter`, `dragOver`, `dragLeave`, and `drop`
- Drag avatars as visual indication of a drag operation:
  - Original element as drag avatar.
  - Clone as drag avatar.
  - Custom drag avatar.
- Support for Shadow DOM (Web Components, Custom Elements, Polymer, etc.).
- Much more... see examples.

## Usage

Before you read the instructions below, you should take a look at the
[examples](http://code.makery.ch/library/dart-drag-and-drop/).

### Basic Set Up

Create a `Draggable` and give it some HTML elements; this will make them
draggable. You can either pass a single `Element` to the constructor or an
`ElementList` that is returned by `querySelectorAll`.

If you also want to drop somewhere, you'll need a `Dropzone`.

```dart
// Install draggable (no avatar).
Draggable draggable = new Draggable(querySelectorAll('.draggable'));

// Install dropzone.
Dropzone dropzone = new Dropzone(querySelector('.dropzone'));
```

You'll most likely want some **drag avatar** to show the user that a drag is
going on. There are two predefined `AvatarHandler`s that you can use as follows.
But you could also provide your own implementation of `AvatarHandler`.

```dart
// Draggable with clone as avatar.
Draggable draggable = new Draggable(querySelectorAll('.draggable'),
    avatarHandler: new AvatarHandler.clone());


// Draggable with original element as avatar.
Draggable draggable = new Draggable(querySelectorAll('.draggable'),
    avatarHandler: new AvatarHandler.original());
```

### Draggable Options

The following options can be passed as _named parameters_ to the constructor of
`Draggable`:

- `avatarHandler`: Is responsible for creating, position, and removing a drag
  avatar. A drag avatar provides visual feedback during a drag operation. Here
  are possible options (see above for an example):

  - `null` (the default) - will not create a drag avatar
  - `new AvatarHandler.original()` - handler that uses the original
    draggable as avatar. See `OriginalAvatarHandler`.
  - `new AvatarHandler.clone()` - handler that uses a clone of the draggable
    element as avatar. See `CloneAvatarHandler`.
  - A custom `AvatarHandler` - you can provide your own implementation of
    `AvatarHandler`.

- `horizontalOnly`: If set to true, only horizontal dragging is tracked.
  This enables vertical touch dragging to be used for scrolling.

- `verticalOnly`: If set to true, only vertical dragging is tracked.
  This enables horizontal touch dragging to be used for scrolling.

- `handle`: If handle query String is specified, it restricts the dragging from
  starting unless it occurs on the specified element(s). Only elements that
  descend from the draggables elements are permitted.

- `cancel`: If cancel query String is specified, drag starting is prevented on
  specified elements.

- `draggingClass`: Is the css class set to the dragged element
  during a drag. If set to null, no such css class is added.

- `draggingClassBody`: Is the css class set to the html body tag
  during a drag. If set to null, no such css class is added.

- `minDragStartDistance`: Is the minimum distance in pixels that is needed
  for a drag to start. Default is `4`. This allows for clicks with tiny movement.

### Draggable Events

Available event `Stream`s on `Draggable`:

- `onDragStart`: Fired when the user starts dragging.  
  _Note: `onDragStart` is fired not on touchStart or mouseDown but as
  soon as there is a drag movement. When a drag is started an `onDrag` event
  will also be fired._

- `onDrag`: Fired periodically throughout the drag operation.

- `onDragEnd`: Fired when the user ends the dragging.  
  _Note: Is also fired when the user clicks the 'esc'-key or the window loses focus._

### Dropzone Options

The following options can be passed as _named parameters_ to the constructor of
`Dropzone`:

- `acceptor`: Is used to determine which `Draggable`s will be accepted by
  this `Dropzone`. If none is specified, all `Draggable`s will be accepted.

- `overClass`: Is the css class set to the dropzone element when an accepted
  draggable is dragged over it. If set to null, no such css class is added.

- `invalidClass`: Is the css class set to the dropzone element when a not-accepted
  draggable is dragged over it. If set to null, no such css class is added.

### Dropzone Events

Available event `Stream`s on `Dropzone`:

- `onDragEnter`: Fired when a `Draggable` enters this `Dropzone`.

- `onDragOver`: Fired periodically while a `Draggable` is moved over a `Dropzone`.

- `onDragLeave`: Fired when a `Draggable` leaves this `Dropzone`.

- `onDrop`: Fired when a `Draggable` is dropped inside this `Dropzone`.

_Note: `Dropzone` events are only fired when the `Draggable` is accepted by
the `Acceptor`._

### Shadow DOM

Web Components create a nice ecapsulation through Shadow DOM. But this creates
a problem with dropzones inside the Shadow DOM as they never receive events
because all events are captured by the host element. To make this work we need
to retarget events to the Shadow DOM children through recursive
`elementFromPoint()` calls.

For performance reasons it wouldn't make sense to retarget all drag and drop
events. If you wish to retarget events to the Shadow DOM children, you must add
a `dnd-retarget` attribute to the host:

```dart
// Retarget drag and drop events to Shadow DOM children.
<my-element dnd-retarget></my-element>
```

## Attribution

The _Dart Drag and Drop_ library is inspired by

- [jQuery UI Draggable](http://jqueryui.com/draggable/)
- [Draggabilly](http://draggabilly.desandro.com/)

Thank you for your work!

## License

The MIT License (MIT)
