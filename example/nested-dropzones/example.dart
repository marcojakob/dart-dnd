import 'dart:html';
import 'package:dnd/dnd.dart';

/**
 * Example how to drag over nested [Dropzone]s.
 * 
 * Note: If dropped on an inner [Dropzone] the outer [Dropzone] will also 
 * receive the drop event.
 */
main() {
  // Install draggable.
  Draggable draggable = new Draggable(querySelector('.draggable'), 
      avatarHandler: new AvatarHandler.original());
  
  // Install dropzones.
  Dropzone outerDropzone = new Dropzone(querySelector('.dropzone-outer'));
  Dropzone innerDropzone = new Dropzone(querySelector('.dropzone-inner'));  
  
  // The text elements.
  Element draggableText = querySelector('.draggable > p');
  Element outerText = querySelector('.dropzone-outer > span');
  Element innerText = querySelector('.dropzone-inner > span');

  // Dropped flags to help for displaying the correct text in dragLeave
  // (dragLeave is fired after a drop).
  bool outerDropped = false;
  bool innerDropped = false;
  
  // Listen to dragEnter.
  outerDropzone.onDragEnter.listen((DropzoneEvent event) {
    outerText.text = 'Outer Dropzone: Enter';
  });
  innerDropzone.onDragEnter.listen((DropzoneEvent event) {
    innerText.text = 'Inner Dropzone: Enter';
  });
  
  // Listen to dragLeave.
  outerDropzone.onDragLeave.listen((DropzoneEvent event) {
    if (outerDropped) {
      outerText.text = 'Outer Dropzone: Drop, Leave';
    } else {
      outerText.text = 'Outer Dropzone: Leave';
    }
  });
  innerDropzone.onDragLeave.listen((DropzoneEvent event) {
    if (innerDropped) {
      innerText.text = 'Inner Dropzone: Drop, Leave';
    } else {
      innerText.text = 'Inner Dropzone: Leave';
    }
  });
  
  
  // Listen to drop.
  outerDropzone.onDrop.listen((DropzoneEvent event) {
    outerDropped = true;
  });
  innerDropzone.onDrop.listen((DropzoneEvent event) {
    innerDropped = true;
  });
  
  // Listen to dragStart to reset.
  draggable.onDragStart.listen((DraggableEvent event) {
    outerDropped = false;
    innerDropped = false;
    draggableText.text = 'Drag me!';
    outerText.text = 'Outer Dropzone';
    innerText.text = 'Inner Dropzone';
  });
}