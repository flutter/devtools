// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import 'config_specific/logger/logger.dart';
import 'connected_app.dart';
import 'core/message_bus.dart';
import 'eval_on_dart_library.dart';
import 'globals.dart';
import 'logging/vm_service_logger.dart';
import 'service_extensions.dart' as extensions;
import 'service_registrations.dart' as registrations;
import 'stream_value_listenable.dart';
import 'utils.dart';
import 'vm_service_wrapper.dart';

// Note: don't check this in enabled.
/// Used to debug service protocol traffic. All requests to to the VM service
/// connection are logged to the Logging page, as well as all responses and
/// events from the service protocol device.
const debugLogServiceProtocolEvents = false;

// TODO(kenz): add an offline service manager implementation.

const defaultRefreshRate = 60.0;

// TODO(jacobr): refactor all of these apis to be in terms of ValueListenable
// instead of Streams.
class ServiceConnectionManager {
  ServiceConnectionManager() {
    final isolateManager = IsolateManager();
    final serviceExtensionManager = ServiceExtensionManager();
    isolateManager._serviceExtensionManager = serviceExtensionManager;
    serviceExtensionManager._isolateManager = isolateManager;
    _isolateManager = isolateManager;
    _serviceExtensionManager = serviceExtensionManager;
  }

  final StreamController<VmServiceWrapper> _connectionAvailableController =
      StreamController<VmServiceWrapper>.broadcast();

  Completer<VmService> _serviceAvailable = Completer();

  Future<VmService> get onServiceAvailable => _serviceAvailable.future;

  bool get isServiceAvailable => _serviceAvailable.isCompleted;

  VmServiceCapabilities _serviceCapabilities;
  VmServiceTrafficLogger serviceTrafficLogger;

  Future<VmServiceCapabilities> get serviceCapabilities async {
    if (_serviceCapabilities == null) {
      await _serviceAvailable.future;
      final version = await service.getVersion();
      _serviceCapabilities = VmServiceCapabilities(version);
    }
    return _serviceCapabilities;
  }

  final _registeredServiceNotifiers = <String, ImmediateValueNotifier<bool>>{};

  Map<String, List<String>> get registeredMethodsForService =>
      _registeredMethodsForService;
  final Map<String, List<String>> _registeredMethodsForService = {};

  VmFlagManager get vmFlagManager => _vmFlagManager;
  final _vmFlagManager = VmFlagManager();

  IsolateManager get isolateManager => _isolateManager;
  IsolateManager _isolateManager;

  ServiceExtensionManager get serviceExtensionManager =>
      _serviceExtensionManager;
  ServiceExtensionManager _serviceExtensionManager;

  ConnectedApp connectedApp;

  VmServiceWrapper service;
  VM vm;
  String sdkVersion;

  bool get hasConnection =>
      service != null && connectedApp != null && connectedApp.appTypeKnown;

  Stream<bool> get onStateChange => _stateController.stream;
  final _stateController = StreamController<bool>.broadcast();

  Stream<VmServiceWrapper> get onConnectionAvailable =>
      _connectionAvailableController.stream;

  Stream<void> get onConnectionClosed => _connectionClosedController.stream;
  final _connectionClosedController = StreamController<void>.broadcast();

  final ValueNotifier<bool> _deviceBusy = ValueNotifier<bool>(false);

  /// Whether the device is currently busy - performing a long-lived, blocking
  /// operation.
  ValueListenable<bool> get deviceBusy => _deviceBusy;

  /// Set whether the device is currently busy - performing a long-lived,
  /// blocking operation.
  void setDeviceBusy(bool isBusy) {
    _deviceBusy.value = isBusy;
  }

  /// Set the device as busy during the duration of the given async task.
  Future<T> runDeviceBusyTask<T>(Future<T> task) async {
    try {
      setDeviceBusy(true);
      return await task;
    } finally {
      setDeviceBusy(false);
    }
  }

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

  ValueListenable<bool> registeredServiceListenable(String name) {
    final listenable = _registeredServiceNotifiers.putIfAbsent(
      name,
      () => ImmediateValueNotifier(false),
    );
    return listenable;
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

    if (debugLogServiceProtocolEvents) {
      serviceTrafficLogger = VmServiceTrafficLogger(service);
    }

    _serviceAvailable.complete(service);

    connectedApp = ConnectedApp();
    serviceExtensionManager.connectedApp = connectedApp;

    setDeviceBusy(false);

    unawaited(onClosed.then((_) => vmServiceClosed()));

    void handleServiceEvent(Event e) {
      if (e.kind == EventKind.kServiceRegistered) {
        final serviceName = e.service;
        _registeredMethodsForService
            .putIfAbsent(serviceName, () => [])
            .add(e.method);
        final serviceNotifier = _registeredServiceNotifiers.putIfAbsent(
          serviceName,
          () => ImmediateValueNotifier(true),
        );
        serviceNotifier.value = true;
      }

      if (e.kind == EventKind.kServiceUnregistered) {
        final serviceName = e.service;
        _registeredMethodsForService.remove(serviceName);
        final serviceNotifier = _registeredServiceNotifiers.putIfAbsent(
          serviceName,
          () => ImmediateValueNotifier(false),
        );
        serviceNotifier.value = false;
      }
    }

    service.onEvent(serviceStreamName).listen(handleServiceEvent);

    _isolateManager._service = service;
    _serviceExtensionManager._service = service;
    _vmFlagManager.service = service;

    _stateController.add(true);

    await _isolateManager._initIsolates(vm.isolates);
    service.onIsolateEvent.listen(_isolateManager._handleIsolateEvent);
    service.onExtensionEvent
        .listen(_serviceExtensionManager._handleExtensionEvent);
    service.onVMEvent.listen(_vmFlagManager.handleVmEvent);

    final streamIds = [
      EventStreams.kDebug,
      EventStreams.kExtension,
      EventStreams.kGC,
      EventStreams.kIsolate,
      EventStreams.kLogging,
      EventStreams.kStderr,
      EventStreams.kStdout,
      EventStreams.kTimeline,
      EventStreams.kVM,
      serviceStreamName,
    ];

    await Future.wait(streamIds.map((String id) async {
      try {
        await service.streamListen(id);
      } catch (e) {
        if (id.endsWith('Logging')) {
          // Don't complain about '_Logging' or 'Logging' events (new VMs don't
          // have the private names, and older ones don't have the public ones).
        } else {
          log(
            "Service client stream not supported: '$id'\n  $e",
            LogLevel.error,
          );
        }
      }
    }));

    await connectedApp.initializeValues();
    _connectionAvailableController.add(service);
  }

  void vmServiceClosed() {
    _serviceAvailable = Completer();

    service = null;
    vm = null;
    sdkVersion = null;
    connectedApp = null;
    serviceExtensionManager.connectedApp = null;
    serviceExtensionManager.resetAvailableExtensions();

    serviceTrafficLogger?.dispose();

    _isolateManager._handleVmServiceClosed();
    setDeviceBusy(false);

    _stateController.add(false);
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

  Future<Response> getFlutterVersion() async {
    return await callService(
      registrations.flutterVersion.service,
      isolateId: _isolateManager.selectedIsolate.id,
    );
  }

  Future<Response> getAdbMemoryInfo() async {
    return await callService(
      registrations.flutterMemory.service,
      isolateId: _isolateManager.selectedIsolate.id,
    );
  }

  Future<double> getDisplayRefreshRate() async {
    if (connectedApp == null || !await connectedApp.isFlutterApp) {
      return null;
    }

    const unknownRefreshRate = 0.0;

    final flutterViewListResponse = await service.callServiceExtension(
      registrations.flutterListViews,
      isolateId: _isolateManager.selectedIsolate.id,
    );
    final List<dynamic> views =
        flutterViewListResponse.json['views'].cast<Map<String, dynamic>>();

    // Each isolate should only have one FlutterView.
    final flutterView = views.firstWhere(
      (view) => view['type'] == 'FlutterView',
      orElse: () => null,
    );

    if (flutterView == null) {
      final message =
          'No Flutter Views to query: ${flutterViewListResponse.json}';
      log(message, LogLevel.error);
      throw Exception(message);
    }

    final viewId = flutterView['id'];
    final displayRefreshRateResponse = await service.callServiceExtension(
      registrations.displayRefreshRate,
      isolateId: _isolateManager.selectedIsolate.id,
      args: {'viewId': viewId},
    );
    final double fps = displayRefreshRateResponse.json['fps'];

    // The Flutter engine returns 0.0 if the refresh rate is unknown. Return
    // [defaultRefreshRate] instead.
    if (fps == unknownRefreshRate) {
      return defaultRefreshRate;
    }

    return fps.roundToDouble();
  }

  bool libraryUriAvailableNow(String uri) {
    assert(_serviceAvailable.isCompleted);
    assert(isolateManager.selectedIsolateAvailable.isCompleted);
    return isolateManager.selectedIsolateLibraries
        .map((ref) => ref.uri)
        .toList()
        .any((u) => u.startsWith(uri));
  }

  Future<bool> libraryUriAvailable(String uri) async {
    assert(_serviceAvailable.isCompleted);
    await isolateManager.selectedIsolateAvailable.future;
    return libraryUriAvailableNow(uri);
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

  var selectedIsolateAvailable = Completer<void>();

  int _lastIsolateIndex = 0;
  final Map<String, int> _isolateIndexMap = {};

  List<LibraryRef> selectedIsolateLibraries;

  List<IsolateRef> get isolates => List<IsolateRef>.unmodifiable(_isolates);

  IsolateRef get selectedIsolate => _selectedIsolate;

  Stream<IsolateRef> get onIsolateCreated => _isolateCreatedController.stream;

  Stream<IsolateRef> get onSelectedIsolateChanged =>
      _selectedIsolateController.stream;

  Stream<IsolateRef> get onIsolateExited => _isolateExitedController.stream;

  /// Return a unique, monotonically increasing number for this Isolate.
  int isolateIndex(IsolateRef isolateRef) {
    if (!_isolateIndexMap.containsKey(isolateRef.id)) {
      _isolateIndexMap[isolateRef.id] = ++_lastIsolateIndex;
    }
    return _isolateIndexMap[isolateRef.id];
  }

  void selectIsolate(String isolateRefId) {
    final IsolateRef ref = _isolates.firstWhere(
        (IsolateRef ref) => ref.id == isolateRefId,
        orElse: () => null);
    _setSelectedIsolate(ref);
  }

  Future<void> _initIsolates(List<IsolateRef> isolates) async {
    _isolates = isolates;
    _isolates.forEach(isolateIndex);

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
    _sendToMessageBus(event);

    if (event.kind == EventKind.kIsolateStart) {
      _isolates.add(event.isolate);
      isolateIndex(event.isolate);
      _isolateCreatedController.add(event.isolate);
      if (_selectedIsolate == null) {
        await _setSelectedIsolate(event.isolate);
      }
    } else if (event.kind == EventKind.kServiceExtensionAdded) {
      // On hot restart, service extensions are added from here.
      await _serviceExtensionManager
          ._maybeAddServiceExtension(event.extensionRPC);

      // Check to see if there is a new isolate.
      if (_selectedIsolate == null && _isFlutterExtension(event.extensionRPC)) {
        await _setSelectedIsolate(event.isolate);
      }
    } else if (event.kind == EventKind.kIsolateExit) {
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

  void _sendToMessageBus(Event event) {
    messageBus.addEvent(BusEvent(
      'debugger',
      data: event,
    ));
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
    if (ref == null) {
      selectedIsolateLibraries = [];
    } else {
      final Isolate isolate = await _service.getIsolate(ref.id);
      selectedIsolateLibraries = isolate.libraries;
    }

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

  void _handleVmServiceClosed() {
    _lastIsolateIndex = 0;
    _setSelectedIsolate(null);
    _isolateIndexMap.clear();
    _isolates.clear();
  }
}

class ServiceExtensionManager {
  VmServiceWrapper _service;
  IsolateManager _isolateManager;

  bool _firstFrameEventReceived = false;

  final Map<String, StreamController<bool>> _serviceExtensionController = {};
  final Map<String, StreamController<ServiceExtensionState>>
      _serviceExtensionStateController = {};

  final Map<String, ValueListenable<bool>> _serviceExtensionListenables = {};

  /// All available service extensions.
  final Set<String> _serviceExtensions = {};

  /// All service extensions that are currently enabled.
  final Map<String, ServiceExtensionState> _enabledServiceExtensions = {};

  /// Temporarily stores service extensions that we need to add. We should not
  /// add extensions until the first frame event has been received
  /// [_firstFrameEventReceived].
  final _pendingServiceExtensions = <String>{};

  var extensionStatesUpdated = Completer<void>();

  ConnectedApp connectedApp;

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

        final extension = extensions.serviceExtensionsAllowlist[name];
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
        extensions.serviceExtensionsAllowlist[name].values.first.runtimeType;
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

    final extensionsToProcess = _pendingServiceExtensions.toList();
    _pendingServiceExtensions.clear();
    await Future.wait([
      for (String extension in extensionsToProcess)
        _addServiceExtension(extension)
    ]);
    extensionStatesUpdated.complete();
  }

  Future<void> _addRegisteredExtensionRPCs(IsolateRef isolateRef) async {
    if (_service == null) {
      return;
    }
    final Isolate isolate = await _service.getIsolate(isolateRef.id);
    if (isolate.extensionRPCs != null) {
      if (await connectedApp.isFlutterApp) {
        for (String extension in isolate.extensionRPCs) {
          await _maybeAddServiceExtension(extension);
        }

        if (_pendingServiceExtensions.isEmpty) {
          extensionStatesUpdated.complete();
        }

        if (!_firstFrameEventReceived) {
          bool didSendFirstFrameEvent = false;
          if (isServiceExtensionAvailable(extensions.didSendFirstFrameEvent)) {
            // We listen for the result here in a Future, instead of awaiting
            // the call, so that we don't block the connection initialization.
            // If the app is paused, this call won't return until the app is
            // resumed.
            unawaited(_service
                .callServiceExtension(
              extensions.didSendFirstFrameEvent,
              isolateId: _isolateManager.selectedIsolate.id,
            )
                .then((value) async {
              didSendFirstFrameEvent = value?.json['enabled'] == 'true';

              if (didSendFirstFrameEvent) {
                await _onFrameEventReceived();
              }
            }));
          } else {
            final EvalOnDartLibrary flutterLibrary = EvalOnDartLibrary(
              ['package:flutter/src/widgets/binding.dart'],
              _service,
            );
            final InstanceRef value = await flutterLibrary.eval(
              'WidgetsBinding?.instance?.debugDidSendFirstFrameEvent ?? false',
              isAlive: null,
            );

            didSendFirstFrameEvent = value?.valueAsString == 'true';
            if (didSendFirstFrameEvent) {
              await _onFrameEventReceived();
            }
          }
        }
      } else {
        for (String extension in isolate.extensionRPCs) {
          await _addServiceExtension(extension);
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

  Future<void> _addServiceExtension(String name) {
    final streamController = _getServiceExtensionController(name);

    _serviceExtensions.add(name);
    streamController.add(true);

    if (_enabledServiceExtensions.containsKey(name)) {
      // Restore any previously enabled states by calling their service
      // extension. This will restore extension states on the device after a hot
      // restart. [_enabledServiceExtensions] will be empty on page refresh or
      // initial start.
      return _callServiceExtension(name, _enabledServiceExtensions[name].value);
    } else {
      // Set any extensions that are already enabled on the device. This will
      // enable extension states in DevTools on page refresh or initial start.
      return _restoreExtensionFromDevice(name);
    }
  }

  Future<void> _restoreExtensionFromDevice(String name) async {
    if (!extensions.serviceExtensionsAllowlist.containsKey(name)) {
      return;
    }
    final expectedValueType =
        extensions.serviceExtensionsAllowlist[name].values.first.runtimeType;

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
    final extensionDescription = extensions.serviceExtensionsAllowlist[name];
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
    _pendingServiceExtensions.clear();
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
    if (callExtension && _serviceExtensions.contains(name)) {
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

  ValueListenable<bool> hasServiceExtensionListener(String name) {
    return _serviceExtensionListenables.putIfAbsent(
      name,
      () => StreamValueListenable<bool>(
        (notifier) {
          return hasServiceExtension(name, (value) {
            notifier.value = value;
          });
        },
        () => _hasServiceExtensionNow(name),
      ),
    );
  }

  bool _hasServiceExtensionNow(String name) {
    return _serviceExtensions.contains(name);
  }

  StreamSubscription<bool> hasServiceExtension(
    String name,
    void onData(bool value),
  ) {
    if (_hasServiceExtensionNow(name) && onData != null) {
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

class VmFlagManager {
  VmServiceWrapper get service => _service;
  VmServiceWrapper _service;

  set service(VmServiceWrapper service) {
    _service = service;
    // Upon setting the vm service, get initial values for vm flags.
    _initFlags();
  }

  ValueListenable get flags => _flags;
  final _flags = ValueNotifier<FlagList>(null);

  final _flagNotifiers = <String, ValueNotifier<Flag>>{};

  ValueNotifier<Flag> flag(String name) {
    return _flagNotifiers.containsKey(name) ? _flagNotifiers[name] : null;
  }

  void _initFlags() async {
    final flagList = await service.getFlagList();
    _flags.value = flagList;
    if (flagList == null) return;

    final flags = <String, Flag>{};
    for (var flag in flagList.flags) {
      flags[flag.name] = flag;
      _flagNotifiers[flag.name] = ValueNotifier<Flag>(flag);
    }
  }

  @visibleForTesting
  void handleVmEvent(Event event) async {
    if (event.kind == EventKind.kVMFlagUpdate) {
      if (_flagNotifiers.containsKey(event.flag)) {
        final currentFlag = _flagNotifiers[event.flag].value;
        _flagNotifiers[event.flag].value = Flag.parse({
          'name': currentFlag.name,
          'comment': currentFlag.comment,
          'modified': true,
          'valueAsString': event.newValue,
        });
        _flags.value = await service.getFlagList();
      }
    }
  }
}

class VmServiceCapabilities {
  VmServiceCapabilities(this.version);

  final Version version;

  bool get supportsGetScripts =>
      version.major > 3 || (version.major == 3 && version.minor >= 12);
}
