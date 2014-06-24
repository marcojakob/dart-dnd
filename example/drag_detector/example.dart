library dnd_example;

import 'dart:html';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:dnd/drag_detector.dart';

final _log = new Logger('dnd_example');

Element dragAlert;

main() {
  initLogging();
  
  dragAlert = querySelector('.alert span');
  
  // Set up a DragDetector on the image element.
  DragDetector dragDetectorImage = new DragDetector(querySelector('.dragme-image'));
  dragDetectorImage.onDrag.listen(showDragAlert);
  dragDetectorImage.onDragEnd.listen(showDragEndAlert);
  
  // Set up a DragDetector with handles.
  DragDetector dragDetectorHandle = new DragDetector(
      querySelectorAll('.dragme-handle > li'), handle: '.handle');
  dragDetectorHandle.onDrag.listen(showDragAlert);
  dragDetectorHandle.onDragEnd.listen(showDragEndAlert);
  
  // Set up a DragDetector with cancel.
  DragDetector dragDetectorCancel = new DragDetector(
      querySelectorAll('.dragme-cancel'), cancel: 'textarea, button, .nodrag');
  dragDetectorCancel.onDrag.listen(showDragAlert);
  dragDetectorCancel.onDragEnd.listen(showDragEndAlert);
}

showDragAlert(DragEvent event) {
  Point dist = event.startCoords - event.coords;
  dragAlert.text =  'You are dragging: element=${event.dragElement}, distance=(${dist.x},${dist.y})';
}

showDragEndAlert(DragEvent event) {
  dragAlert.text =  'You stopped dragging. Why would you do that? :-(';
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