part of dnd;

class Dropzone {
  // --------------
  // Options
  // --------------
  /// The [Acceptor] used to determine which [Draggable]s will be accepted by
  /// this [Dropzone].
  Acceptor acceptor;
  
  /// CSS class set to the [Dropzone] element when an accepted [Draggable] is 
  /// dragged over it. See [Dropzone] constructor.
  String overClass;
  
  // -------------------
  // Events
  // -------------------
  StreamController<DropzoneEvent> _onDragEnter;
  StreamController<DropzoneEvent> _onDragOver;
  StreamController<DropzoneEvent> _onDragLeave;
  StreamController<DropzoneEvent> _onDrop;
  
  /**
   * Fired when a [Draggable] enters this [Dropzone].
   */
  Stream<DropzoneEvent> get onDragEnter {
    if (_onDragEnter == null) {
      _onDragEnter = new StreamController<DropzoneEvent>.broadcast(sync: true, 
          onCancel: () => _onDragEnter = null);
    }
    return _onDragEnter.stream;
  }
  
  /**
   * Fired when a [Draggable] is moved over a [Dropzone].
   */
  Stream<DropzoneEvent> get onDragOver {
    if (_onDragOver == null) {
      _onDragOver = new StreamController<DropzoneEvent>.broadcast(sync: true, 
          onCancel: () => _onDragOver = null);
    }
    return _onDragOver.stream;
  }
  
  /**
   * Fired when a [Draggable] leaves this [Dropzone].
   */
  Stream<DropzoneEvent> get onDragLeave {
    if (_onDragLeave == null) {
      _onDragLeave = new StreamController<DropzoneEvent>.broadcast(sync: true, 
          onCancel: () => _onDragLeave = null);
    }
    return _onDragLeave.stream;
  }
  
  /**
   * Fired at the end of the drag operation when the [Draggable] is dropped
   * inside this [Dropzone].
   */
  Stream<DropzoneEvent> get onDrop {
    if (_onDrop == null) {
      _onDrop = new StreamController<DropzoneEvent>.broadcast(sync: true, 
          onCancel: () => _onDrop = null);
    }
    return _onDrop.stream;
  }
  
  // -------------------
  // Private Properties
  // -------------------
  /// The [Element] or [ElementList] on which a drag is detected.
  final _elementOrElementList;
  
  /// Tracks subscriptions.
  List<StreamSubscription> _subs = [];
  
  /// The (accepted) dropzone element the user is currently dragging over.
  Element _currentOverElement;
  
  /// Flag indicating that a child of the [_currentOverElement] is entered.
  /// This means that a dragLeave event for the parent will be fired. So, if 
  /// this flag is true we must ignore the next dragLeave event.
  bool _childOfCurrentOverElementEntered = false;
  
  /**
   * Creates a new [Dropzone] for [elementOrElementList]. The 
   * [elementOrElementList] must be of type [Element] or [ElementList].
   * 
   * ## Options
   * 
   * The [acceptor] is used to determine which [Draggable]s will be accepted by
   * this [Dropzone]. If none is specified, all [Draggable]s will be accepted.
   * 
   * The [overClass] is the css class set to the dragged element 
   * during a drag. If set to null, no such css class is added.
   */
  Dropzone(elementOrElementList,
      { this.acceptor: null,
        this.overClass: 'dnd-over'})
      : this._elementOrElementList = elementOrElementList {
    
    _log.fine('Initializing Dropzone.');

    // Install drag listener on Element or ElementList.
    if (elementOrElementList is ElementList) {
      elementOrElementList.forEach(_installCustomDragListener);
    } else {
      _installCustomDragListener(elementOrElementList);
    }
  }
  
  /**
   * Installs the custom drag listeners (dragEnter, dragOver, dragLeave, and
   * drop) on [element].
   */
  void _installCustomDragListener(Element element) {
    _subs.add(_DragEventDispatcher.enterEvent.forTarget(element)
        .listen(_handleDragEnter));
    _subs.add(_DragEventDispatcher.overEvent.forTarget(element)
        .listen(_handleDragOver));
    _subs.add(_DragEventDispatcher.leaveEvent.forTarget(element)
        .listen(_handleDragLeave));
    _subs.add(_DragEventDispatcher.dropEvent.forTarget(element)
        .listen(_handleDrop));
  }
  
  /**
   * Handles dragEnter events.
   */
  void _handleDragEnter(CustomEvent event) {
    _DragEventInfo info = new _DragEventInfo.fromJson(event.detail);
    
    // Test if the current draggable is accepted by this dropzone. If there is
    // no accepter all are accepted.
    if (acceptor == null || 
        acceptor.accepts(_currentDragElement, info.draggableId, event.currentTarget)) {
      
      _log.fine('DragEnter');

      if (_currentOverElement == event.currentTarget) {
        // The same element receives a dragEnter event AGAIN. This means that 
        // a child element is entered. After this dragEnter event there will
        // be a dragLeave event for the parent element which we must ignore.
        _childOfCurrentOverElementEntered = true;
      }
      _currentOverElement = event.currentTarget;
      
      // Fire dragEnter event.
      if (_onDragEnter != null) {
        _onDragEnter.add(new DropzoneEvent._(_currentDragElement, 
            event.currentTarget, info.position));
      }
      
      // Add the css class to indicate drag over.
      if (overClass != null) {
        (event.currentTarget as Element).classes.add(overClass);
      }
    }
  }
  
  /**
   * Handles dragOver events.
   */
  void _handleDragOver(CustomEvent event) {
    _DragEventInfo info = new _DragEventInfo.fromJson(event.detail);
    
    // Test if the current draggable is accepted by this dropzone. If there is
    // no accepter all are accepted.
    if (acceptor == null || 
        acceptor.accepts(_currentDragElement, info.draggableId, event.currentTarget)) {
      
      _log.finest('DragOver');
      
      // Fire dragOver event.
      if (_onDragOver != null) {
        _onDragOver.add(new DropzoneEvent._(_currentDragElement, 
            event.currentTarget, info.position));
      }
    }
  }
  
  /**
   * Handles dragLeave events.
   */
  void _handleDragLeave(CustomEvent event) {
    if (_childOfCurrentOverElementEntered) {
      // Must ignore because user didn't really leave but only entered a child.
      _childOfCurrentOverElementEntered = false;
      return;
    }
    
    _currentOverElement = null;
    
    _DragEventInfo info = new _DragEventInfo.fromJson(event.detail);
    
    // Test if the current draggable is accepted by this dropzone. If there is
    // no accepter all are accepted.
    if (acceptor == null || 
        acceptor.accepts(_currentDragElement, info.draggableId, event.currentTarget)) {
      
      _log.fine('DragLeave');
      
      // Fire dragLeave event.
      if (_onDragLeave != null) {
        _onDragLeave.add(new DropzoneEvent._(_currentDragElement, 
            event.currentTarget, info.position));
      }
      
      // Remove the css class.
      if (overClass != null) {
        (event.currentTarget as Element).classes.remove(overClass);
      }
    }
  }
  
  
  /**
   * Handles drop events.
   */
  void _handleDrop(CustomEvent event) {
    _DragEventInfo info = new _DragEventInfo.fromJson(event.detail);
    
    // Test if the current draggable is accepted by this dropzone. If there is
    // no accepter all are accepted.
    if (acceptor == null || 
        acceptor.accepts(_currentDragElement, info.draggableId, event.currentTarget)) {
      
      _log.fine('Drop');
      
      // Fire drop event.
      if (_onDrop != null) {
        _onDrop.add(new DropzoneEvent._(_currentDragElement, 
            event.currentTarget, info.position));
      }
    }
  }
  
  /**
   * Unistalls all listeners.
   */
  void destroy() {
    _subs.forEach((sub) => sub.cancel());
    _subs.clear();
  }
}


/**
 * Event for dropzone elements.
 */
class DropzoneEvent {
  /// The [Element] that is beeing dragged. 
  Element draggableElement;
  
  /// The [Element] of the [Dropzone].
  Element dropzoneElement;
  
  /// The current mouse/touch position, relative to the whole document (page 
  /// position).
  Point position;
  
  DropzoneEvent._(this.draggableElement, this.dropzoneElement, this.position);
}