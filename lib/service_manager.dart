// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import 'eval_on_dart_library.dart';
import 'service_extensions.dart' as extensions;
import 'vm_service_wrapper.dart';

class ServiceConnectionManager {
  ServiceConnectionManager() {
    final IsolateManager isolateManager = IsolateManager();
    final ServiceExtensionManager serviceExtensionManager =
        ServiceExtensionManager();
    isolateManager._serviceExtensionManager = serviceExtensionManager;
    serviceExtensionManager._isolateManager = isolateManager;
    _isolateManager = isolateManager;
    _serviceExtensionManager = serviceExtensionManager;
  }

  final StreamController<Null> _stateController =
      StreamController<Null>.broadcast();
  final StreamController<VmServiceWrapper> _connectionAvailableController =
      StreamController<VmServiceWrapper>.broadcast();
  final StreamController<Null> _connectionClosedController =
      StreamController<Null>.broadcast();
  final Completer<Null> serviceAvailable = Completer();
  final Map<String, List<String>> methodsForService = {};

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

  /// Call a service that is registered by exactly one client.
  Future<Response> callService(String name,
      {String isolateId, Map args}) async {
    final registered = methodsForService[name] ?? const [];
    if (registered.length != 1) {
      throw Exception('Expected one registered service for "$name" but found '
          '${registered.length}');
    }
    return service.callMethod(registered.first,
        isolateId: isolateId, args: args);
  }

  /// Call a service that may have been registered by multiple clients.
  ///
  /// For example, a service to navigate a code editor to a specific line and
  /// column might be registered by multiple code editors.
  Future<List<Response>> callMulticastService(String name,
      {String isolateId, Map args}) async {
    final registered = methodsForService[name] ?? const [];
    if (registered.isNotEmpty) {
      return Future.wait(registered.map((String method) {
        return service.callMethod(method, isolateId: isolateId, args: args);
      }));
    } else {
      throw Exception('There are no registered methods for service "$name"');
    }
  }

  Future<void> vmServiceOpened(
      VmServiceWrapper service, Future<void> onClosed) async {
    try {
      final vm = await service.getVM();
      this.vm = vm;
      sdkVersion = vm.version;
      if (sdkVersion.contains(' ')) {
        sdkVersion = sdkVersion.substring(0, sdkVersion.indexOf(' '));
      }

      this.service = service;
      serviceAvailable.complete();

      service.onServiceEvent.listen((e) {
        if (e.kind == EventKind.kServiceRegistered) {
          methodsForService.putIfAbsent(e.service, () => []).add(e.method);
        }
      });

      _isolateManager._service = service;
      _serviceExtensionManager._service = service;

      _stateController.add(null);
      _connectionAvailableController.add(service);

      await _isolateManager._initIsolates(vm.isolates);
      service.onIsolateEvent.listen(_isolateManager._handleIsolateEvent);
      service.onExtensionEvent
          .listen(_serviceExtensionManager._handleExtensionEvent);

      unawaited(onClosed.then((_) => vmServiceClosed()));

      final streamIds = [
        'Stdout',
        'Stderr',
        'VM',
        'Isolate',
        'Debug',
        'GC',
        'Timeline',
        'Extension',
        '_Graph',
        '_Logging',
        '_Service',
      ];
      await Future.wait(streamIds.map((id) => service.streamListen(id)));
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

  // TODO(kenzie): add hot restart method, register method in flutter_tools.

  Future<void> performHotReload() async {
    try {
      await callMulticastService('reloadSources',
          isolateId: _isolateManager.selectedIsolate.id);
    } catch (e) {
      // TODO: improve general error handling.
      print('Error during hot reload: "$e."');
      rethrow;
    }
  }
}

class IsolateManager {
  List<IsolateRef> _isolates = <IsolateRef>[];
  IsolateRef _selectedIsolate;
  VmServiceWrapper _service;
  ServiceExtensionManager _serviceExtensionManager;

  final StreamController<IsolateRef> _isolateCreatedController =
      StreamController<IsolateRef>.broadcast();
  final StreamController<IsolateRef> _isolateExitedController =
      StreamController<IsolateRef>.broadcast();
  final StreamController<IsolateRef> _selectedIsolateController =
      StreamController<IsolateRef>.broadcast();

  List<IsolateRef> get isolates => List<IsolateRef>.unmodifiable(_isolates);

  IsolateRef get selectedIsolate => _selectedIsolate;

  Stream<IsolateRef> get onIsolateCreated => _isolateCreatedController.stream;

  Stream<IsolateRef> get onSelectedIsolateChanged =>
      _selectedIsolateController.stream;

  Stream<IsolateRef> get onIsolateExited => _isolateExitedController.stream;

  void selectIsolate(String isolateRefId) {
    final IsolateRef ref = _isolates.firstWhere(
        (IsolateRef ref) => ref.id == isolateRefId,
        orElse: () => null);
    _setSelectedIsolate(ref);
  }

  Future<void> _initIsolates(List<IsolateRef> isolates) async {
    _isolates = isolates;

    await _initSelectedIsolate(isolates);

    if (_selectedIsolate != null) {
      _isolateCreatedController.add(_selectedIsolate);
      _selectedIsolateController.add(_selectedIsolate);
      // On initial connection to running app, service extensions are added from
      // here.
      await _serviceExtensionManager
          ._addRegisteredExtensionRPCs(_selectedIsolate);
    }
  }

  void _handleIsolateEvent(Event event) async {
    if (event.kind == 'IsolateStart') {
      _isolates.add(event.isolate);
      _isolateCreatedController.add(event.isolate);
      if (_selectedIsolate == null) {
        _setSelectedIsolate(event.isolate);
      }
    } else if (event.kind == 'ServiceExtensionAdded') {
      // On hot restart, service extensions are added from here.
      await _serviceExtensionManager
          ._maybeAddServiceExtension(event.extensionRPC);

      // Check to see if there is a new isolate.
      if (_selectedIsolate == null && _isFlutterExtension(event.extensionRPC)) {
        _setSelectedIsolate(event.isolate);
      }
    } else if (event.kind == 'IsolateExit') {
      _isolates.remove(event.isolate);
      _isolateExitedController.add(event.isolate);
      if (_selectedIsolate == event.isolate) {
        _selectedIsolate = _isolates.isEmpty ? null : _isolates.first;
        _selectedIsolateController.add(_selectedIsolate);
        _serviceExtensionManager.resetAvailableExtensions();
      }
    }
  }

  bool _isFlutterExtension(String extensionName) {
    return extensionName.startsWith('ext.flutter.');
  }

  Future<void> _initSelectedIsolate(List<IsolateRef> isolates) async {
    if (isolates.isEmpty) {
      return;
    }

    for (IsolateRef ref in isolates) {
      if (_selectedIsolate == null) {
        final Isolate isolate = await _service.getIsolate(ref.id);
        if (isolate.extensionRPCs != null) {
          for (String extensionName in isolate.extensionRPCs) {
            if (_isFlutterExtension(extensionName)) {
              _setSelectedIsolate(ref);
              return;
            }
          }
        }
      }
    }

    final IsolateRef ref = isolates.firstWhere((IsolateRef ref) {
      // 'foo.dart:main()'
      return ref.name.contains(':main(');
    }, orElse: () => null);

    _setSelectedIsolate(ref ?? isolates.first);
  }

  void _setSelectedIsolate(IsolateRef ref) {
    if (_selectedIsolate == ref) {
      return;
    }
    _selectedIsolate = ref;
    _selectedIsolateController.add(ref);
  }

  StreamSubscription<IsolateRef> getSelectedIsolate(
      void onData(IsolateRef ref)) {
    if (_selectedIsolate != null) {
      onData(_selectedIsolate);
    }
    return _selectedIsolateController.stream.listen(onData);
  }
}

class ServiceExtensionManager {
  VmServiceWrapper _service;
  IsolateManager _isolateManager;

  bool _firstFrameEventReceived = false;

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
  /// extensions until the first frame event has been received [_firstFrameEventReceived].
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
    if (_firstFrameEventReceived) {
      // The first frame event was already received.
      return;
    }
    _firstFrameEventReceived = true;

    _pendingServiceExtensions.forEach(_addServiceExtension);
    _pendingServiceExtensions.clear();
  }

  Future<void> _addRegisteredExtensionRPCs(IsolateRef isolateRef) async {
    if (_service == null) {
      return;
    }
    final Isolate isolate = await _service.getIsolate(isolateRef.id);
    if (isolate.extensionRPCs != null) {
      for (String extension in isolate.extensionRPCs) {
        await _maybeAddServiceExtension(extension);
      }

      if (!_firstFrameEventReceived) {
        bool didSendFirstFrameEvent = false;
        if (isServiceExtensionAvailable(extensions.didSendFirstFrameEvent)) {
          final value = await _service.callServiceExtension(
              extensions.didSendFirstFrameEvent,
              isolateId: _isolateManager.selectedIsolate.id);
          didSendFirstFrameEvent =
              value != null && value.json['enabled'] == 'true';
        } else {
          final EvalOnDartLibrary flutterLibrary = EvalOnDartLibrary(
            'package:flutter/src/widgets/binding.dart',
            _service,
          );
          final InstanceRef value = await flutterLibrary.eval(
              'WidgetsBinding.instance.debugDidSendFirstFrameEvent',
              isAlive: null);
          didSendFirstFrameEvent =
              value != null && value.valueAsString == 'true';
        }

        if (didSendFirstFrameEvent) {
          _onFrameEventReceived();
        }
      }
    }
  }

  Future<void> _maybeAddServiceExtension(String name) async {
    if (_firstFrameEventReceived) {
      assert(_pendingServiceExtensions.isEmpty);
      await _addServiceExtension(name);
    } else {
      _pendingServiceExtensions.add(name);
    }
  }

  Future<void> _addServiceExtension(String name) async {
    final StreamController<bool> streamController =
        _getServiceExtensionController(name);

    _serviceExtensions.add(name);
    streamController.add(true);

    // TODO(kenzie): query the device for service extension states. This will
    // restore extension states in DevTools on page refresh or initial start.

    // Restore any previously enabled states by calling their service extension.
    // This will restore extension states on the device after a hot restart.
    if (_enabledServiceExtensions.containsKey(name)) {
      await _callServiceExtension(name, _enabledServiceExtensions[name].value);
    }
  }

  Future<void> _callServiceExtension(String name, dynamic value) async {
    if (_service == null) {
      return;
    }

    assert(value != null);
    if (value is bool) {
      await _service.callServiceExtension(
        name,
        isolateId: _isolateManager.selectedIsolate.id,
        args: {'enabled': value},
      );
    } else if (value is String) {
      await _service.callServiceExtension(
        name,
        isolateId: _isolateManager.selectedIsolate.id,
        args: {'value': value},
      );
    } else if (value is double) {
      await _service.callServiceExtension(
        name,
        isolateId: _isolateManager.selectedIsolate.id,
        // The param name for a numeric service extension will be the last part
        // of the extension name (ext.flutter.extensionName => extensionName).
        args: {name.substring(name.lastIndexOf('.') + 1): value},
      );
    }
  }

  void resetAvailableExtensions() {
    _firstFrameEventReceived = false;
    _serviceExtensions.clear();
    _serviceExtensionController
        .forEach((String name, StreamController<bool> stream) {
      stream.add(false);
    });
  }

  /// Sets the state for a service extension and makes the call to the VMService.
  Future<void> setServiceExtensionState(
      String name, bool enabled, dynamic value) async {
    await _callServiceExtension(name, value);

    final StreamController<ServiceExtensionState> streamController =
        _getServiceExtensionStateController(name);
    streamController.add(ServiceExtensionState(enabled, value));

    // Add or remove service extension from [enabledServiceExtensions].
    if (enabled) {
      _enabledServiceExtensions[name] = ServiceExtensionState(enabled, value);
    } else {
      _enabledServiceExtensions.remove(name);
    }
  }

  bool isServiceExtensionAvailable(String name) {
    return _serviceExtensions.contains(name) ||
        _pendingServiceExtensions.contains(name);
  }

  StreamSubscription<bool> hasServiceExtension(
      String name, void onData(bool value)) {
    if (_serviceExtensions.contains(name) && onData != null) {
      onData(true);
    }
    final StreamController<bool> streamController =
        _getServiceExtensionController(name);
    return streamController.stream.listen(onData);
  }

  StreamSubscription<ServiceExtensionState> getServiceExtensionState(
      String name, void onData(ServiceExtensionState state)) {
    if (_enabledServiceExtensions.containsKey(name) && onData != null) {
      onData(_enabledServiceExtensions[name]);
    }
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
            .add(ServiceExtensionState(false, null));
      }
    });
  }

  /// Initializes a generic stream if it does not already exist for the given
  /// extension name.
  StreamController<T> _getStream<T>(
      String name, Map<String, StreamController<T>> streams,
      {@required void onFirstListenerSubscribed()}) {
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
