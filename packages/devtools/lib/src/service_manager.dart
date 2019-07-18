// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import 'connected_app.dart';
import 'eval_on_dart_library.dart';
import 'service_extensions.dart' as extensions;
import 'service_registrations.dart' as registrations;
import 'vm_service_wrapper.dart';

// TODO(kenzie): add an offline service manager implementation.

class ServiceConnectionManager {
  ServiceConnectionManager() {
    final isolateManager = IsolateManager();
    final serviceExtensionManager = ServiceExtensionManager();
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

  VmServiceCapabilities _serviceCapabilities;

  Future<VmServiceCapabilities> get serviceCapabilities async {
    if (_serviceCapabilities == null) {
      await serviceAvailable.future;
      final version = await service.getVersion();
      _serviceCapabilities = new VmServiceCapabilities(version);
    }
    return _serviceCapabilities;
  }

  final Map<String, StreamController<bool>> _serviceRegistrationController =
      <String, StreamController<bool>>{};
  final Map<String, List<String>> _registeredMethodsForService = {};

  Map<String, List<String>> get registeredMethodsForService =>
      _registeredMethodsForService;

  IsolateManager _isolateManager;
  ServiceExtensionManager _serviceExtensionManager;

  IsolateManager get isolateManager => _isolateManager;

  ServiceExtensionManager get serviceExtensionManager =>
      _serviceExtensionManager;

  ConnectedApp connectedApp;

  VmServiceWrapper service;
  VM vm;
  String sdkVersion;

  bool get hasConnection => service != null;

  Stream<Null> get onStateChange => _stateController.stream;

  Stream<VmServiceWrapper> get onConnectionAvailable =>
      _connectionAvailableController.stream;

  Stream<Null> get onConnectionClosed => _connectionClosedController.stream;

  /// Call a service that is registered by exactly one client.
  Future<Response> callService(
    String name, {
    String isolateId,
    Map args,
  }) async {
    final registered = _registeredMethodsForService[name] ?? const [];
    if (registered.isEmpty) {
      throw Exception('There are no registered methods for service "$name"');
    }
    return service.callMethod(
      registered.first,
      isolateId: isolateId,
      args: args,
    );
  }

  StreamSubscription<bool> hasRegisteredService(
    String name,
    void onData(bool value),
  ) {
    if (_registeredMethodsForService.containsKey(name) && onData != null) {
      onData(true);
    }
    final StreamController<bool> streamController =
        _getServiceRegistrationController(name);
    return streamController.stream.listen(onData);
  }

  StreamController<bool> _getServiceRegistrationController(String name) {
    return _getStreamController(
      name,
      _serviceRegistrationController,
      onFirstListenerSubscribed: () {
        _serviceRegistrationController[name]
            .add(_registeredMethodsForService.containsKey(name));
      },
    );
  }

  Future<void> vmServiceOpened(
    VmServiceWrapper service, {
    @required Future<void> onClosed,
  }) async {
    final serviceStreamName = await service.serviceStreamName;

    final vm = await service.getVM();
    this.vm = vm;
    sdkVersion = vm.version;
    if (sdkVersion.contains(' ')) {
      sdkVersion = sdkVersion.substring(0, sdkVersion.indexOf(' '));
    }

    this.service = service;
    serviceAvailable.complete();

    connectedApp = ConnectedApp();

    void handleServiceEvent(Event e) {
      if (e.kind == EventKind.kServiceRegistered) {
        if (!_registeredMethodsForService.containsKey(e.service)) {
          _registeredMethodsForService[e.service] = [e.method];
          final StreamController<bool> streamController =
              _getServiceRegistrationController(e.service);
          streamController.add(true);
        } else {
          _registeredMethodsForService[e.service].add(e.method);
        }
      }
    }

    service.onEvent(serviceStreamName).listen(handleServiceEvent);

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
      EventStreams.kStdout,
      EventStreams.kStderr,
      EventStreams.kVM,
      EventStreams.kIsolate,
      EventStreams.kDebug,
      EventStreams.kGC,
      EventStreams.kTimeline,
      EventStreams.kExtension,
      serviceStreamName
    ];

    // The following streams are not yet supported by Flutter Web.
    if (!await connectedApp.isFlutterWebApp) {
      streamIds.addAll(['_Graph', '_Logging', EventStreams.kLogging]);
    }

    await Future.wait(streamIds.map((String id) async {
      try {
        await service.streamListen(id);
      } catch (e) {
        // TODO(devoncarew): Remove this check on or after approx. Oct 1 2019.
        if (id.endsWith('Logging')) {
          // Don't complain about '_Logging' or 'Logging' events (new VMs don't
          // have the private names, and older ones don't have the public ones).
        } else {
          print("Service client stream not supported: '$id'\n  $e");
        }
      }
    }));
  }

  void vmServiceClosed() {
    service = null;
    vm = null;
    sdkVersion = null;
    connectedApp = null;

    _stateController.add(null);
    _connectionClosedController.add(null);
  }

  /// This can throw an [RPCError].
  Future<void> performHotReload() async {
    await callService(
      registrations.hotReload.service,
      isolateId: _isolateManager.selectedIsolate.id,
    );
  }

  /// This can throw an [RPCError].
  Future<void> performHotRestart() async {
    await callService(
      registrations.hotRestart.service,
      isolateId: _isolateManager.selectedIsolate.id,
    );
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

  Completer<Null> selectedIsolateAvailable = Completer();

  List<LibraryRef> selectedIsolateLibraries;

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

  Future<void> _handleIsolateEvent(Event event) async {
    if (event.kind == 'IsolateStart') {
      _isolates.add(event.isolate);
      _isolateCreatedController.add(event.isolate);
      if (_selectedIsolate == null) {
        await _setSelectedIsolate(event.isolate);
      }
    } else if (event.kind == 'ServiceExtensionAdded') {
      // On hot restart, service extensions are added from here.
      await _serviceExtensionManager
          ._maybeAddServiceExtension(event.extensionRPC);

      // Check to see if there is a new isolate.
      if (_selectedIsolate == null && _isFlutterExtension(event.extensionRPC)) {
        await _setSelectedIsolate(event.isolate);
      }
    } else if (event.kind == 'IsolateExit') {
      _isolates.remove(event.isolate);
      _isolateExitedController.add(event.isolate);
      if (_selectedIsolate == event.isolate) {
        _selectedIsolate = _isolates.isEmpty ? null : _isolates.first;
        if (_selectedIsolate == null) {
          selectedIsolateAvailable = Completer();
        }
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
              await _setSelectedIsolate(ref);
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

    await _setSelectedIsolate(ref ?? isolates.first);
  }

  Future<void> _setSelectedIsolate(IsolateRef ref) async {
    if (_selectedIsolate == ref) {
      return;
    }

    // Store the library uris for the selected isolate.
    final Isolate isolate = await _service.getIsolate(ref.id);
    selectedIsolateLibraries = isolate.libraries;

    _selectedIsolate = ref;
    if (!selectedIsolateAvailable.isCompleted) {
      selectedIsolateAvailable.complete();
    }
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
  // ignore: prefer_collection_literals
  final Set<String> _serviceExtensions = Set<String>();

  /// All service extensions that are currently enabled.
  final Map<String, ServiceExtensionState> _enabledServiceExtensions =
      <String, ServiceExtensionState>{};

  /// Temporarily stores service extensions that we need to add. We should not
  /// add extensions until the first frame event has been received
  /// [_firstFrameEventReceived].
  // ignore: prefer_collection_literals
  final Set<String> _pendingServiceExtensions = Set<String>();

  Completer<Null> extensionStatesUpdated = Completer();

  Future<void> _handleExtensionEvent(Event event) async {
    switch (event.extensionKind) {
      case 'Flutter.FirstFrame':
      case 'Flutter.Frame':
        await _onFrameEventReceived();
        break;
      case 'Flutter.ServiceExtensionStateChanged':
        final String name = event.json['extensionData']['extension'].toString();
        final String valueFromJson =
            event.json['extensionData']['value'].toString();

        final extension = extensions.serviceExtensionsWhitelist[name];
        if (extension != null) {
          final dynamic value = _getExtensionValueFromJson(name, valueFromJson);

          final enabled =
              extension is extensions.ToggleableServiceExtensionDescription
                  ? value == extension.enabledValue
                  // For extensions that have more than two states
                  // (enabled / disabled), we will always consider them to be
                  // enabled with the current value.
                  : true;

          await setServiceExtensionState(
            name,
            enabled,
            value,
            callExtension: false,
          );
        }
    }
  }

  dynamic _getExtensionValueFromJson(String name, String valueFromJson) {
    final expectedValueType =
        extensions.serviceExtensionsWhitelist[name].values.first.runtimeType;
    switch (expectedValueType) {
      case bool:
        return valueFromJson == 'true' ? true : false;
      case int:
      case double:
        return num.parse(valueFromJson);
      default:
        return valueFromJson;
    }
  }

  Future<void> _onFrameEventReceived() async {
    if (_firstFrameEventReceived) {
      // The first frame event was already received.
      return;
    }
    _firstFrameEventReceived = true;

    for (String extension in _pendingServiceExtensions) {
      await _addServiceExtension(extension);
    }
    extensionStatesUpdated.complete();
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

      if (_pendingServiceExtensions.isEmpty) {
        extensionStatesUpdated.complete();
      }

      if (!_firstFrameEventReceived) {
        bool didSendFirstFrameEvent = false;
        if (isServiceExtensionAvailable(extensions.didSendFirstFrameEvent)) {
          final value = await _service.callServiceExtension(
            extensions.didSendFirstFrameEvent,
            isolateId: _isolateManager.selectedIsolate.id,
          );
          didSendFirstFrameEvent =
              value != null && value.json['enabled'] == 'true';
        } else {
          final EvalOnDartLibrary flutterLibrary = EvalOnDartLibrary(
            [
              'package:flutter/src/widgets/binding.dart',
              'package:flutter_web/src/widgets/binding.dart',
            ],
            _service,
          );
          final InstanceRef value = await flutterLibrary.eval(
            'WidgetsBinding.instance.debugDidSendFirstFrameEvent',
            isAlive: null,
          );

          didSendFirstFrameEvent =
              value != null && value.valueAsString == 'true';
        }

        if (didSendFirstFrameEvent) {
          await _onFrameEventReceived();
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

    if (_enabledServiceExtensions.containsKey(name)) {
      // Restore any previously enabled states by calling their service
      // extension. This will restore extension states on the device after a hot
      // restart. [_enabledServiceExtensions] will be empty on page refresh or
      // initial start.
      await _callServiceExtension(name, _enabledServiceExtensions[name].value);
    } else {
      // Set any extensions that are already enabled on the device. This will
      // enable extension states in DevTools on page refresh or initial start.
      await _restoreExtensionFromDevice(name);
    }
  }

  Future<void> _restoreExtensionFromDevice(String name) async {
    if (!extensions.serviceExtensionsWhitelist.containsKey(name)) {
      return;
    }
    final expectedValueType =
        extensions.serviceExtensionsWhitelist[name].values.first.runtimeType;

    try {
      final response = await _service.callServiceExtension(
        name,
        isolateId: _isolateManager.selectedIsolate.id,
      );
      switch (expectedValueType) {
        case bool:
          final bool enabled =
              response.json['enabled'] == 'true' ? true : false;
          await _maybeRestoreExtension(name, enabled);
          return;
        case String:
          final String value = response.json['value'];
          await _maybeRestoreExtension(name, value);
          return;
        case int:
        case double:
          final num value = num.parse(
              response.json[name.substring(name.lastIndexOf('.') + 1)]);
          await _maybeRestoreExtension(name, value);
          return;
        default:
          return;
      }
    } catch (e) {
      // Do not report an error if the VMService has gone away or the
      // selectedIsolate has been closed probably due to a hot restart.
      // There is no need
      // TODO(jacobr): validate that the exception is one of a short list
      // of allowed network related exceptions rather than ignoring all
      // exceptions.
    }
  }

  Future<void> _maybeRestoreExtension(String name, dynamic value) async {
    final extensionDescription = extensions.serviceExtensionsWhitelist[name];
    if (extensionDescription
        is extensions.ToggleableServiceExtensionDescription) {
      if (value == extensionDescription.enabledValue) {
        await setServiceExtensionState(name, true, value, callExtension: false);
      }
    } else {
      await setServiceExtensionState(name, true, value, callExtension: false);
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
    extensionStatesUpdated = Completer();
    _firstFrameEventReceived = false;
    _serviceExtensions.clear();
    _serviceExtensionController
        .forEach((String name, StreamController<bool> stream) {
      stream.add(false);
    });
  }

  /// Sets the state for a service extension and makes the call to the VMService.
  Future<void> setServiceExtensionState(
    String name,
    bool enabled,
    dynamic value, {
    bool callExtension = true,
  }) async {
    if (callExtension) {
      await _callServiceExtension(name, value);
    }

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
    String name,
    void onData(bool value),
  ) {
    if (_serviceExtensions.contains(name) && onData != null) {
      onData(true);
    }
    final StreamController<bool> streamController =
        _getServiceExtensionController(name);
    return streamController.stream.listen(onData);
  }

  StreamSubscription<ServiceExtensionState> getServiceExtensionState(
    String name,
    void onData(ServiceExtensionState state),
  ) {
    if (_enabledServiceExtensions.containsKey(name) && onData != null) {
      onData(_enabledServiceExtensions[name]);
    }
    final StreamController<ServiceExtensionState> streamController =
        _getServiceExtensionStateController(name);
    return streamController.stream.listen(onData);
  }

  StreamController<bool> _getServiceExtensionController(String name) {
    return _getStreamController(
      name,
      _serviceExtensionController,
      onFirstListenerSubscribed: () {
        // If the service extension is in [_serviceExtensions], then we have been
        // waiting for a listener to add the initial true event. Otherwise, the
        // service extension is not available, so we should add a false event.
        _serviceExtensionController[name]
            .add(_serviceExtensions.contains(name));
      },
    );
  }

  StreamController<ServiceExtensionState> _getServiceExtensionStateController(
      String name) {
    return _getStreamController(
      name,
      _serviceExtensionStateController,
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
      },
    );
  }
}

/// Given a map of Strings to StreamControllers [streamControllers], get the
/// stream controller for the given name. If it does not exist, initialize a
/// generic stream controller and map it to the name.
StreamController<T> _getStreamController<T>(
    String name, Map<String, StreamController<T>> streamControllers,
    {@required void onFirstListenerSubscribed()}) {
  streamControllers.putIfAbsent(
    name,
    () => StreamController<T>.broadcast(onListen: onFirstListenerSubscribed),
  );
  return streamControllers[name];
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

class VmServiceCapabilities {
  VmServiceCapabilities(this.version);

  final Version version;

  bool get supportsGetScripts =>
      version.major > 3 || (version.major == 3 && version.minor >= 12);
}
