library dnd_example;

import 'dart:html';
import 'package:dnd/dnd.dart';

main() {
  // Install draggables (documents).
  Draggable draggable = new Draggable(querySelectorAll('.document'), 
      avatarHandler: new AvatarHandler.clone());
  
  Dropzone dropzone = new Dropzone(querySelector('.trash'), 
      acceptor: new Acceptor.draggable([draggable]));
  
  draggable.onDragStart.listen((_) => print('onDragStart ${new DateTime.now()}'));
//  draggable.onDrag.listen((_) => print('onDrag ${new DateTime.now()}'));
  draggable.onDragEnd.listen((_) => print('onDragEnd ${new DateTime.now()}'));
  
  dropzone.onDragEnter.listen((_) => print('onDragEnter ${new DateTime.now()}'));
//  dropzone.onDragOver.listen((_) => print('onDragOver ${new DateTime.now()}'));
  dropzone.onDragLeave.listen((_) => print('onDragLeave ${new DateTime.now()}'));
  dropzone.onDrop.listen((_) => print('onDrop ${new DateTime.now()}'));
}