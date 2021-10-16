import 'dart:async';

typedef ResourceFactory<RESOURCE> = Future<RESOURCE> Function();

class ResourcePool<RESOURCE> {
  final int capacity;
  final ResourceFactory<RESOURCE> resourceFactory;
  final int? maxQueueSize;

  final Set<RESOURCE> _availableResources = {};
  final Set<RESOURCE> _busyResources = {};
  final Set<Completer<RESOURCE>> _queue = {};

  int _waitingForCreation = 0;

  ResourcePool(this.capacity, this.resourceFactory, {this.maxQueueSize});

  Future<RESOURCE> get() async {
    if (_availableResources.isEmpty) {
      if (_busyResources.length + _waitingForCreation < capacity) {
        final newResource = await _createResource();
        _busyResources.add(newResource);
        return newResource;
      } else {
        if (maxQueueSize != null && _queue.length >= maxQueueSize!) {
          throw "Max queue size reached: ${_queue.length}";
        }

        Completer<RESOURCE> completer = Completer();
        _queue.add(completer);
        return completer.future;
      }
    } else {
      final firstAvailableResource = _availableResources.first;
      _availableResources.remove(firstAvailableResource);
      _busyResources.add(firstAvailableResource);
      return firstAvailableResource;
    }
  }

  void release(RESOURCE resource) {
    if (!_busyResources.contains(resource)) {
      throw "Pool does not own released resource";
    }

    if (_queue.isNotEmpty) {
      _completeWaiter(resource);
    } else {
      _busyResources.remove(resource);
      _availableResources.add(resource);
    }
  }

  Future<void> remove(RESOURCE resource) async {
    _busyResources.remove(resource);
    _availableResources.remove(resource);

    if (_queue.isNotEmpty) {
      final newResource = await _createResource();
      _completeWaiter(newResource);
      _busyResources.add(newResource);
    }
  }

  int get availableResourceCount => _availableResources.length;

  int get busyResourceCount => _busyResources.length;

  int get queueSize => _queue.length;

  void _completeWaiter(RESOURCE resource) {
    final firstInQueue = _queue.first;
    _queue.remove(firstInQueue);
    firstInQueue.complete(resource);
  }

  Future<RESOURCE> _createResource() async {
    try {
      _waitingForCreation++;
      return await resourceFactory();
    } finally {
      _waitingForCreation--;
    }
  }
}
