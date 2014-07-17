library dnd_example;

import 'dart:html';
import 'dart:math' as math;
import 'package:dnd/dnd.dart';

/**
 * An example of how to use a custom [AvatarHandler]. 
 * 
 * See [MyAvatarHandler].
 */
main() {
  // Install draggables.
  Draggable draggable = new Draggable(querySelectorAll('.document'), 
      avatarHandler: new MyAvatarHandler());

  // Install dropzone (trash).
  Element trash = querySelector('.trash');
  Dropzone dropzone = new Dropzone(trash);

  // Keep track if we're over the trash.
  bool overTrash = false;
  dropzone.onDragEnter.listen((DropzoneEvent event) {
    overTrash = true;
  });
  dropzone.onDragLeave.listen((DropzoneEvent event) {
    overTrash = false;
  });
  
  // Change the drag avatar during the drag.
  draggable.onDrag.listen((DraggableEvent event) {
    MyAvatarHandler handler = event.avatarHandler;
    
    if (overTrash) {
      // Set to last image if over trash.
      handler.updateImage(4);
    } else {
      // Set image depending on distance to trash.
      int imageNumber = calcImageNumber(trash, event.startPosition, event.position);
      handler.updateImage(imageNumber);
    }
  });
  
  // Remove the documents when dropped.
  dropzone.onDrop.listen((DropzoneEvent event) {
    event.draggableElement.remove();
    event.dropzoneElement.classes.add('full');
  });
}

/**
 * An example of a custom [AvatarHandler].
 * 
 * The [MyAvatarHandler] creates changing smiley images as drag avatar.
 */
class MyAvatarHandler extends AvatarHandler {

  /// List of smiley src urls.
  static final List<String> SMILEYS = [
    'images/smiley02.png',
    'images/smiley03.png',
    'images/smiley04.png',
    'images/smiley05.png',
    'images/smiley06.png'];
  
  /// Define an offset for the avatar relative to the mouse cursor.
  static const Point OFFSET = const Point(-64, -130);
  
  /// The avatar element which is created in [dragStart].
  ImageElement avatar;
  
  MyAvatarHandler() {
    // Preload avatar images.
    SMILEYS.forEach((s) {
      new ImageElement(src: s);
    });
  }
  
  @override
  void dragStart(Element draggable, Point startPosition) {
    // Use first image as avatar.
    avatar = new ImageElement(src: SMILEYS[0]);
    
    // Set the initial position of avatar.
    setLeftTop(startPosition + OFFSET);
    
    // Ensure avatar has an absolute position.
    avatar.style.position = 'absolute';
    
    // Set pointer-events to none.
    setPointerEventsNone();
    
    // Add the drag avatar to the body element.
    document.body.append(avatar);
  }
  
  @override
  void drag(Point startPosition, Point position) {
    setTranslate(position - startPosition);
  }
  
  /**
   * Called when the drag operation ends. 
   */
  @override
  void dragEnd(Point startPosition, Point position) {
    avatar.remove();
  }
  
  /**
   * Updates the image to [imageNumber].
   */
  void updateImage(int imageNumber) {
    avatar.src = SMILEYS[imageNumber]; 
  }
}

/**
 * Calculates the image number depending on the distance to [trash].
 */
int calcImageNumber(Element trash, Point startPosition, Point position) {
  var trashDim = trash.borderEdge;
  Point trashCenter = new Point(trashDim.left + trashDim.width / 2, 
      trashDim.top + trashDim.height / 2);
  
  // Set image depending on distance to trash.
  double remainingDistance = position.distanceTo(trashCenter) - 64;
  double totalDistance = startPosition.distanceTo(trashCenter) - 64;
  
  num distancePercent = remainingDistance / totalDistance;
  distancePercent = math.min(1, distancePercent);
  
  return 3 - (3 * distancePercent).round();
}