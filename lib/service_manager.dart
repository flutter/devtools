// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import 'eval_on_dart_library.dart';
import 'vm_service_wrapper.dart';

class ServiceConnectionManager {
  ServiceConnectionManager() {
    final IsolateManager isolateManager = new IsolateManager();
    final ServiceExtensionManager serviceExtensionManager =
        new ServiceExtensionManager();
    isolateManager._serviceExtensionManager = serviceExtensionManager;
    serviceExtensionManager._isolateManager = isolateManager;
    _isolateManager = isolateManager;
    _serviceExtensionManager = serviceExtensionManager;
  }
  final StreamController<Null> _stateController =
      new StreamController<Null>.broadcast();
  final StreamController<VmServiceWrapper> _connectionAvailableController =
      new StreamController<VmServiceWrapper>.broadcast();
  final StreamController<Null> _connectionClosedController =
      new StreamController<Null>.broadcast();

  IsolateManager _isolateManager;
  ServiceExtensionManager _serviceExtensionManager;

  IsolateManager get isolateManager => _isolateManager;
  ServiceExtensionManager get serviceExtensionManager =>
      _serviceExtensionManager;

  VmServiceWrapper service;
  VM vm;
  String sdkVersion;

  bool get hasConnection => service != null;

  Stream<Null> get onStateChange => _stateController.stream;

  Stream<VmServiceWrapper> get onConnectionAvailable =>
      _connectionAvailableController.stream;

  Stream<Null> get onConnectionClosed => _connectionClosedController.stream;

  Future<void> vmServiceOpened(
      VmServiceWrapper service, Future<void> onClosed) async {
    try {
      final VM vm = await service.getVM();
      this.vm = vm;
      sdkVersion = vm.version;
      if (sdkVersion.contains(' ')) {
        sdkVersion = sdkVersion.substring(0, sdkVersion.indexOf(' '));
      }

      this.service = service;
      _isolateManager._service = service;
      _serviceExtensionManager._service = service;

      _stateController.add(null);
      _connectionAvailableController.add(service);

      _isolateManager._initIsolates(vm.isolates);
      service.onIsolateEvent.listen(_isolateManager._handleIsolateEvent);
      service.onExtensionEvent
          .listen(_serviceExtensionManager._handleExtensionEvent);

      onClosed.then((_) => vmServiceClosed());

      service.streamListen('Stdout');
      service.streamListen('Stderr');
      service.streamListen('VM');
      service.streamListen('Isolate');
      service.streamListen('Debug');
      service.streamListen('GC');
      service.streamListen('Timeline');
      service.streamListen('Extension');
      service.streamListen('_Graph');
      service.streamListen('_Logging');
    } catch (e) {
      // TODO:
      print(e);
    }
  }

  void vmServiceClosed() {
    service = null;
    vm = null;
    sdkVersion = null;

    _stateController.add(null);
    _connectionClosedController.add(null);
  }
}

class IsolateManager {
  IsolateManager() {
    _flutterIsolateController = new StreamController<IsolateRef>.broadcast();
    _flutterIsolateController.onListen =
        () => _flutterIsolateController.add(_flutterIsolate);
  }

  List<IsolateRef> _isolates = <IsolateRef>[];
  IsolateRef _selectedIsolate;
  IsolateRef _flutterIsolate;
  VmServiceWrapper _service;
  ServiceExtensionManager _serviceExtensionManager;

  StreamController<IsolateRef> _flutterIsolateController;
  final StreamController<IsolateRef> _isolateCreatedController =
      new StreamController<IsolateRef>.broadcast();
  final StreamController<IsolateRef> _isolateExitedController =
      new StreamController<IsolateRef>.broadcast();
  final StreamController<IsolateRef> _selectedIsolateController =
      new StreamController<IsolateRef>.broadcast();

  List<IsolateRef> get isolates => new List<IsolateRef>.unmodifiable(_isolates);

  IsolateRef get selectedIsolate => _selectedIsolate;

  Stream<IsolateRef> get onIsolateCreated => _isolateCreatedController.stream;

  Stream<IsolateRef> get onSelectedIsolateChanged =>
      _selectedIsolateController.stream;

  Stream<IsolateRef> get onIsolateExited => _isolateExitedController.stream;

  void selectIsolate(String isolateRefId) {
    final IsolateRef ref = _isolates.firstWhere(
        (IsolateRef ref) => ref.id == isolateRefId,
        orElse: () => null);
    if (ref != _selectedIsolate) {
      _selectedIsolate = ref;
      _selectedIsolateController.add(_selectedIsolate);
    }
  }

  void _initIsolates(List<IsolateRef> isolates) {
    _isolates = isolates;
    _initFlutterIsolate(isolates);
    _selectedIsolate = _selectBestFirstIsolate(isolates);
    if (_selectedIsolate != null) {
      _isolateCreatedController.add(_selectedIsolate);
      _selectedIsolateController.add(_selectedIsolate);
    }
  }

  void _handleIsolateEvent(Event event) {
    if (event.kind == 'IsolateStart') {
      _isolates.add(event.isolate);
      _isolateCreatedController.add(event.isolate);
      if (_selectedIsolate == null) {
        _selectedIsolate = event.isolate;
        _selectedIsolateController.add(event.isolate);
      }
    } else if (event.kind == 'ServiceExtensionAdded') {
      // On hot restart, service extensions are added from here.
      _serviceExtensionManager._maybeAddServiceExtension(event.extensionRPC);

      // Check to see if there is a new flutter isolate.
      if (_flutterIsolate == null) {
        if (_isFlutterExtension(event.extensionRPC)) {
          _setFlutterIsolate(event.isolate);
        }
      }
    } else if (event.kind == 'IsolateExit') {
      _isolates.remove(event.isolate);
      _isolateExitedController.add(event.isolate);
      if (_selectedIsolate == event.isolate) {
        _selectedIsolate = _isolates.isEmpty ? null : _isolates.first;
        _selectedIsolateController.add(_selectedIsolate);
      }
      if (_flutterIsolate == event.isolate) {
        _setFlutterIsolate(null);
        _serviceExtensionManager.resetAvailableExtensions();
      }
    }
  }

  IsolateRef _selectBestFirstIsolate(List<IsolateRef> isolates) {
    final IsolateRef ref = isolates.firstWhere((IsolateRef ref) {
      // 'foo.dart:main()'
      return ref.name.contains(':main(');
    }, orElse: () => null);

    if (ref != null) {
      return ref;
    }

    return isolates.isEmpty ? null : isolates.first;
  }

  bool _isFlutterExtension(String extensionName) {
    return extensionName.startsWith('ext.flutter.');
  }

  void _initFlutterIsolate(List<IsolateRef> isolates) async {
    for (IsolateRef ref in isolates) {
      // Populate flutter isolate info.
      if (_flutterIsolate == null) {
        final Isolate isolate = await _service.getIsolate(ref.id);
        if (isolate.extensionRPCs != null) {
          for (String extensionName in isolate.extensionRPCs) {
            if (_isFlutterExtension(extensionName)) {
              _setFlutterIsolate(ref);
              break;
            }
          }
        }
      }
      // On initial connection to running app, service extensions are added from
      // here.
      _serviceExtensionManager._addRegisteredExtensionRPCs(ref);
    }
  }

  void _setFlutterIsolate(IsolateRef ref) {
    if (_flutterIsolate == ref) {
      // Isolate didn't change. Do nothing.
      return;
    }
    _flutterIsolate = ref;
    _flutterIsolateController.add(ref);
  }

  StreamSubscription<IsolateRef> getCurrentFlutterIsolate(Function onData) {
    return _flutterIsolateController.stream.listen(onData);
  }
}

class ServiceExtensionManager {
  VmServiceWrapper _service;
  IsolateManager _isolateManager;

  bool firstFrameEventReceived = false;

  final Map<String, StreamController<bool>> _serviceExtensionController =
      <String, StreamController<bool>>{};
  final Map<String, StreamController<ServiceExtensionState>>
      _serviceExtensionStateController =
      <String, StreamController<ServiceExtensionState>>{};

  /// All available service extensions.
  final Set<String> _serviceExtensions = Set<String>();

  /// All service extensions that are currently enabled.
  final Map<String, ServiceExtensionState> _enabledServiceExtensions =
      <String, ServiceExtensionState>{};

  /// Temporarily stores service extensions that we need to add. We should not add
  /// extensions until the first frame event has been received [firstFrameEventReceived].
  final Set<String> _pendingServiceExtensions = Set<String>();

  void _handleExtensionEvent(Event event) {
    final String extensionKind = event.extensionKind;
    if (event.kind == 'Extension' &&
        (extensionKind == 'Flutter.FirstFrame' ||
            extensionKind == 'Flutter.Frame')) {
      _onFrameEventReceived();
    }
  }

  void _onFrameEventReceived() {
    if (firstFrameEventReceived) {
      // The first frame event was already received.
      return;
    }
    firstFrameEventReceived = true;

    _pendingServiceExtensions.forEach(_addServiceExtension);
    _pendingServiceExtensions.clear();
  }

  void _addRegisteredExtensionRPCs(IsolateRef isolateRef) async {
    if (_service == null) {
      return;
    }
    final Isolate isolate = await _service.getIsolate(isolateRef.id);
    if (isolate.extensionRPCs != null) {
      isolate.extensionRPCs.forEach(_maybeAddServiceExtension);

      if (!firstFrameEventReceived) {
        final EvalOnDartLibrary flutterLibrary = new EvalOnDartLibrary(
          'package:flutter/src/widgets/binding.dart',
          _service,
        );

        final InstanceRef value = await flutterLibrary
            .eval('WidgetsBinding.instance.debugDidSendFirstFrameEvent');
        final bool didSendFirstFrameEvent =
            value != null && value.valueAsString == 'true';
        if (didSendFirstFrameEvent) {
          _onFrameEventReceived();
        }
      }
    }
  }

  void _maybeAddServiceExtension(String name) {
    if (firstFrameEventReceived) {
      assert(_pendingServiceExtensions.isEmpty);
      _addServiceExtension(name);
    } else {
      _pendingServiceExtensions.add(name);
    }
  }

  void _addServiceExtension(String name) {
    final StreamController<bool> streamController =
        _getServiceExtensionController(name);

    _serviceExtensions.add(name);
    streamController.add(true);

    // Restore any previously enabled states by calling their service extensions.
    if (_enabledServiceExtensions.containsKey(name)) {
      _callServiceExtension(name, _enabledServiceExtensions[name].value);
    }
  }

  void _callServiceExtension(String name, dynamic value) {
    if (_service == null) {
      return;
    }

    assert(value != null);
    if (value is bool) {
      _service.callServiceExtension(
        name,
        isolateId: _isolateManager.selectedIsolate.id,
        args: {'enabled': value},
      );
    } else if (value is String) {
      _service.callServiceExtension(
        name,
        isolateId: _isolateManager.selectedIsolate.id,
        args: {'value': value},
      );
    } else if (value is double) {
      _service.callServiceExtension(
        name,
        isolateId: _isolateManager.selectedIsolate.id,
        // The param name for a numeric service extension will be the last part
        // of the extension name (ext.flutter.extensionName => extensionName).
        args: {name.substring(name.lastIndexOf('.') + 1): value},
      );
    }
  }

  void resetAvailableExtensions() {
    firstFrameEventReceived = false;
    _serviceExtensions.clear();
    _serviceExtensionController
        .forEach((String name, StreamController<bool> stream) {
      stream.add(false);
    });
  }

  /// Sets the state for a service extension and makes the call to the VMService.
  void setServiceExtensionState(String name, bool enabled, dynamic value) {
    _callServiceExtension(name, value);

    final StreamController<ServiceExtensionState> streamController =
        _getServiceExtensionStateController(name);
    streamController.add(new ServiceExtensionState(enabled, value));

    // Add or remove service extension from [enabledServiceExtensions].
    if (enabled) {
      _enabledServiceExtensions[name] =
          new ServiceExtensionState(enabled, value);
    } else {
      _enabledServiceExtensions.remove(name);
    }
  }

  StreamSubscription<bool> hasServiceExtension(String name, Function onData) {
    final StreamController<bool> streamController =
        _getServiceExtensionController(name);
    return streamController.stream.listen(onData);
  }

  StreamSubscription<ServiceExtensionState> getServiceExtensionState(
      String name, Function onData) {
    final StreamController<ServiceExtensionState> streamController =
        _getServiceExtensionStateController(name);
    return streamController.stream.listen(onData);
  }

  StreamController<bool> _getServiceExtensionController(String name) {
    return _getStream(name, _serviceExtensionController,
        onFirstListenerSubscribed: () {
      // If the service extension is in [_serviceExtensions], then we have been
      // waiting for a listener to add the initial true event. Otherwise, the
      // service extension is not available, so we should add a false event.
      _serviceExtensionController[name].add(_serviceExtensions.contains(name));
    });
  }

  StreamController<ServiceExtensionState> _getServiceExtensionStateController(
      String name) {
    return _getStream(name, _serviceExtensionStateController,
        onFirstListenerSubscribed: () {
      // If the service extension is enabled, add the current state as the first
      // event. Otherwise, add a disabled state as the first event.
      if (_enabledServiceExtensions.containsKey(name)) {
        assert(_enabledServiceExtensions[name].enabled);
        _serviceExtensionStateController[name]
            .add(_enabledServiceExtensions[name]);
      } else {
        _serviceExtensionStateController[name]
            .add(new ServiceExtensionState(false, null));
      }
    });
  }

  /// Initializes a generic stream if it does not already exist for the given
  /// extension name.
  StreamController<T> _getStream<T>(
      String name, Map<String, StreamController<T>> streams,
      {@required Function onFirstListenerSubscribed}) {
    streams.putIfAbsent(
        name,
        () =>
            StreamController<T>.broadcast(onListen: onFirstListenerSubscribed));
    return streams[name];
  }
}

class ServiceExtensionState {
  ServiceExtensionState(this.enabled, this.value) {
    if (value is bool) {
      assert(enabled == value);
    }
  }

  // For boolean service extensions, [enabled] should equal [value].
  final bool enabled;
  final dynamic value;
}
