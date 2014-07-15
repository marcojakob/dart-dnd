library dnd_example;

import 'dart:html';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:dnd/dnd.dart';

final _log = new Logger('dnd_example');

Element dragAlert;

main() {
  initLogging();
  
  dragAlert = querySelector('.alert span');
  
  // Set up a Draggable on the image element.
  Draggable dragDetectorImage = new Draggable(querySelector('.dragme-image'), 
      avatarHandler: new AvatarHandler.clone());
  dragDetectorImage.onDrag.listen(showDragAlert);
  dragDetectorImage.onDragEnd.listen(showDragEndAlert);
  
  // Set up a Draggable with handles.
  Draggable dragDetectorHandle = new Draggable(
      querySelectorAll('.dragme-handle > li'), 
      handle: '.handle',
      avatarHandler: new AvatarHandler.clone());
  dragDetectorHandle.onDrag.listen(showDragAlert);
  dragDetectorHandle.onDragEnd.listen(showDragEndAlert);
  
  // Set up a Draggable with cancel.
  Draggable dragDetectorCancel = new Draggable(
      querySelectorAll('.dragme-cancel'), 
      cancel: 'textarea, button, .nodrag',
      avatarHandler: new AvatarHandler.clone());
  dragDetectorCancel.onDrag.listen(showDragAlert);
  dragDetectorCancel.onDragEnd.listen(showDragEndAlert);
}

showDragAlert(DraggableEvent event) {
  Point dist = event.position - event.startPosition;
  dragAlert.text =  'You are dragging: element=${event.dragElement}, distance=(${dist.x},${dist.y})';
}

showDragEndAlert(DraggableEvent event) {
  dragAlert.text =  'You stopped dragging. Why would you do that? :-)';
}

initLogging() {
  DateFormat dateFormat = new DateFormat('yyyy.mm.dd HH:mm:ss.SSS');
  
  // Print output to console.
  Logger.root.onRecord.listen((LogRecord r) {
    print('${dateFormat.format(r.time)}\t${r.loggerName}\t[${r.level.name}]:\t${r.message}');
  });
  
  // Root logger level.
  Logger.root.level = Level.FINEST;
}