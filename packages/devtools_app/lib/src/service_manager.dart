// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:core';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import 'analytics/analytics_stub.dart'
    if (dart.library.html) 'analytics/analytics.dart' as ga;
import 'auto_dispose.dart';
import 'config_specific/logger/logger.dart';
import 'connected_app.dart';
import 'core/message_bus.dart';
import 'globals.dart';
import 'logging/vm_service_logger.dart';
import 'service_extensions.dart' as extensions;
import 'service_extensions.dart';
import 'service_registrations.dart' as registrations;
import 'utils.dart';
import 'version.dart';
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
    _isolateManager = IsolateManager();
    _serviceExtensionManager =
        ServiceExtensionManager(_isolateManager.mainIsolate);
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
    this.service = service;
    connectedApp = ConnectedApp();
    // It is critical we call vmServiceOpened on each manager class before
    // performing any async operations. Otherwise, we may get end up with
    // race conditions where managers cannot listen for events soon enough.
    isolateManager.vmServiceOpened(service);
    vmFlagManager.vmServiceOpened(service);

    serviceExtensionManager.vmServiceOpened(service, connectedApp);

    if (debugLogServiceProtocolEvents) {
      serviceTrafficLogger = VmServiceTrafficLogger(service);
    }

    final serviceStreamName = await service.serviceStreamName;

    vm = await service.getVM();

    sdkVersion = vm.version;
    if (sdkVersion.contains(' ')) {
      sdkVersion = sdkVersion.substring(0, sdkVersion.indexOf(' '));
    }

    _serviceAvailable.complete(service);

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

    _stateController.add(true);

    await _isolateManager._initIsolates(vm.isolates);

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

    // This needs to be called before calling
    // `ga.setupUserApplicationDimensions()`.
    await connectedApp.initializeValues();

    // Set up analytics dimensions for the connected app.
    await ga.setupUserApplicationDimensions();

    _connectionAvailableController.add(service);
  }

  void vmServiceClosed() {
    _serviceAvailable = Completer();

    service = null;
    vm = null;
    sdkVersion = null;
    connectedApp = null;
    vmFlagManager.vmServiceClosed();
    serviceExtensionManager.vmServiceClosed();

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

  Future<Response> get flutterVersion async {
    return await callService(
      registrations.flutterVersion.service,
      isolateId: _isolateManager.selectedIsolate.id,
    );
  }

  Future<Response> get adbMemoryInfo async {
    return await callService(
      registrations.flutterMemory.service,
      isolateId: _isolateManager.selectedIsolate?.id,
    );
  }

  /// @returns view id of selected isolate's 'FlutterView'.
  /// @throws Exception if no 'FlutterView'.
  Future<String> get flutterViewId async {
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

    return flutterView['id'];
  }

  /// Flutter engine returns estimate how much memory is used by layer/picture raster
  /// cache entries in bytes.
  ///
  /// Call to returns JSON payload 'EstimateRasterCacheMemory' with two entries:
  ///   layerBytes - layer raster cache entries in bytes
  ///   pictureBytes - picture raster cache entries in bytes
  Future<Response> get rasterCacheMetrics async {
    if (connectedApp == null || !await connectedApp.isFlutterApp) {
      return null;
    }

    final viewId = await flutterViewId;

    return await service.callServiceExtension(
      registrations.flutterEngineEstimateRasterCache,
      args: <String, String>{
        'viewId': viewId,
      },
      isolateId: _isolateManager.selectedIsolate.id,
    );
  }

  Future<double> get queryDisplayRefreshRate async {
    if (connectedApp == null || !await connectedApp.isFlutterApp) {
      return null;
    }

    const unknownRefreshRate = 0.0;

    final viewId = await flutterViewId;
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

class IsolateManager extends Disposer {
  List<IsolateRef> _isolates = <IsolateRef>[];
  IsolateRef _selectedIsolate;
  VmServiceWrapper _service;

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

  final _mainIsolate = ValueNotifier<IsolateRef>(null);
  ValueListenable<IsolateRef> get mainIsolate => _mainIsolate;

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

    // It is critical that the _serviceExtensionManager is already listening
    // for events indicating that new extension rpcs are registered before this
    // call otherwise there is a race condition where service extensions are not
    // described in the selectedIsolate or recieved as an event. It is ok if a
    // service extension is included in both places as duplicate extensions are
    // handled gracefully.
    await _initSelectedIsolate(isolates);

    if (_selectedIsolate != null) {
      _isolateCreatedController.add(_selectedIsolate);
      _selectedIsolateController.add(_selectedIsolate);
    }
  }

  Future<void> _handleIsolateEvent(Event event) async {
    _sendToMessageBus(event);

    if (event.kind == EventKind.kIsolateStart &&
        !event.isolate.isSystemIsolate) {
      _isolates.add(event.isolate);
      isolateIndex(event.isolate);
      _isolateCreatedController.add(event.isolate);
      // TODO(jacobr): we assume the first isolate started is the main isolate
      // but that may not always be a safe assumption.
      _mainIsolate.value ??= event.isolate;

      if (_selectedIsolate == null) {
        await _setSelectedIsolate(event.isolate);
      }
    } else if (event.kind == EventKind.kServiceExtensionAdded) {
      // Check to see if there is a new isolate.
      if (_selectedIsolate == null &&
          extensions.isFlutterExtension(event.extensionRPC)) {
        await _setSelectedIsolate(event.isolate);
      }
    } else if (event.kind == EventKind.kIsolateExit) {
      _isolates.remove(event.isolate);
      _isolateExitedController.add(event.isolate);
      if (_mainIsolate.value == event.isolate) {
        _mainIsolate.value = null;
      }
      if (_selectedIsolate == event.isolate) {
        _selectedIsolate = _isolates.isEmpty ? null : _isolates.first;
        if (_selectedIsolate == null) {
          selectedIsolateAvailable = Completer();
        }
        _selectedIsolateController.add(_selectedIsolate);
      }
    }
  }

  void _sendToMessageBus(Event event) {
    messageBus?.addEvent(BusEvent(
      'debugger',
      data: event,
    ));
  }

  Future<void> _initSelectedIsolate(List<IsolateRef> isolates) async {
    if (isolates.isEmpty) {
      return;
    }

    _mainIsolate.value = await _computeMainIsolate(isolates);
    await _setSelectedIsolate(_mainIsolate.value);
  }

  Future<IsolateRef> _computeMainIsolate(List<IsolateRef> isolates) async {
    if (isolates.isEmpty) return null;

    for (IsolateRef ref in isolates) {
      if (_selectedIsolate == null) {
        final Isolate isolate = await _service.getIsolate(ref.id);
        if (isolate.extensionRPCs != null) {
          for (String extensionName in isolate.extensionRPCs) {
            if (extensions.isFlutterExtension(extensionName)) {
              return ref;
            }
          }
        }
      }
    }

    final IsolateRef ref = isolates.firstWhere((IsolateRef ref) {
      // 'foo.dart:main()'
      return ref.name.contains(':main(');
    }, orElse: () => null);

    return ref ?? isolates.first;
  }

  Future<void> _setSelectedIsolate(IsolateRef ref) async {
    if (_selectedIsolate == ref) {
      return;
    }

    _selectedIsolate = ref;
    // Store the library uris for the selected isolate.
    if (ref == null) {
      selectedIsolateLibraries = [];
    } else {
      try {
        final Isolate isolate = await _service.getIsolate(ref.id);
        if (_selectedIsolate == ref) {
          selectedIsolateLibraries = isolate.libraries;
        }
      } on SentinelException {
        if (_selectedIsolate == ref) {
          _selectedIsolate = null;
          if (_isolates.isNotEmpty && _isolates.first != ref) {
            await _setSelectedIsolate(_isolates.first);
          }
        }
        return;
      }
    }

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
    cancel();
    _service = null;
    _lastIsolateIndex = 0;
    _setSelectedIsolate(null);
    _isolateIndexMap.clear();
    _isolates.clear();
    _mainIsolate.value = null;
  }

  void vmServiceOpened(VmServiceWrapper service) {
    cancel();
    _service = service;
    autoDispose(service.onIsolateEvent.listen(_handleIsolateEvent));
    // We don't yet known the main isolate.
    _mainIsolate.value = null;
  }
}

/// Manager that handles tracking the service extension for the main isolate.
class ServiceExtensionManager extends Disposer {
  ServiceExtensionManager(this._mainIsolate);

  VmServiceWrapper _service;

  bool _checkForFirstFrameStarted = false;

  final ValueListenable<IsolateRef> _mainIsolate;

  bool get _firstFrameEventReceived => _firstFrameReceived.isCompleted;
  Completer<void> _firstFrameReceived = Completer();
  Future<void> get firstFrameReceived => _firstFrameReceived.future;

  final _serviceExtensionAvailable = <String, ValueNotifier<bool>>{};

  final _serviceExtensionStateController =
      <String, ValueNotifier<ServiceExtensionState>>{};

  /// All available service extensions.
  final _serviceExtensions = <String>{};

  /// All service extensions that are currently enabled.
  final _enabledServiceExtensions = <String, ServiceExtensionState>{};

  /// Temporarily stores service extensions that we need to add. We should not
  /// add extensions until the first frame event has been received
  /// [_firstFrameEventReceived].
  final _pendingServiceExtensions = <String>{};

  Map<String, List<AsyncCallback>> _callbacksOnIsolateResume = {};

  ConnectedApp get connectedApp => _connectedApp;
  ConnectedApp _connectedApp;

  Future<void> _handleIsolateEvent(Event event) async {
    if (event.kind == EventKind.kServiceExtensionAdded) {
      // On hot restart, service extensions are added from here.
      await _maybeAddServiceExtension(event.extensionRPC);
    }
  }

  Future<void> _handleExtensionEvent(Event event) async {
    switch (event.extensionKind) {
      case 'Flutter.FirstFrame':
      case 'Flutter.Frame':
        await _onFrameEventReceived();
        break;
      case 'Flutter.ServiceExtensionStateChanged':
        final name = event.json['extensionData']['extension'].toString();
        final encodedValue = event.json['extensionData']['value'].toString();
        await _updateServiceExtensionForStateChange(name, encodedValue);
        break;
      case 'HttpTimelineLoggingStateChange':
        final name = extensions.httpEnableTimelineLogging.extension;
        final encodedValue = event.json['extensionData']['enabled'].toString();
        await _updateServiceExtensionForStateChange(name, encodedValue);
        break;
      case 'SocketProfilingStateChange':
        final name = extensions.socketProfiling.extension;
        final encodedValue = event.json['extensionData']['enabled'].toString();
        await _updateServiceExtensionForStateChange(name, encodedValue);
    }
  }

  Future<void> _handleDebugEvent(Event event) async {
    if (event.kind == EventKind.kResume) {
      final isolateId = event.isolate.id;
      final callbacks = _callbacksOnIsolateResume[isolateId] ?? [];
      _callbacksOnIsolateResume = {};
      for (final callback in callbacks) {
        try {
          await callback();
        } catch (e) {
          log(
            'Error running isolate callback: $e',
            LogLevel.error,
          );
        }
      }
    }
  }

  Future<void> _updateServiceExtensionForStateChange(
    String name,
    String encodedValue,
  ) async {
    final extension = extensions.serviceExtensionsAllowlist[name];
    if (extension != null) {
      final dynamic extensionValue = _getExtensionValue(name, encodedValue);
      final enabled =
          extension is extensions.ToggleableServiceExtensionDescription
              ? extensionValue == extension.enabledValue
              // For extensions that have more than two states
              // (enabled / disabled), we will always consider them to be
              // enabled with the current value.
              : true;

      await setServiceExtensionState(
        name,
        enabled,
        extensionValue,
        callExtension: false,
      );
    }
  }

  dynamic _getExtensionValue(String name, String encodedValue) {
    final expectedValueType =
        extensions.serviceExtensionsAllowlist[name].values.first.runtimeType;
    switch (expectedValueType) {
      case bool:
        return encodedValue == 'true';
      case int:
      case double:
        return num.parse(encodedValue);
      default:
        return encodedValue;
    }
  }

  Future<void> _onFrameEventReceived() async {
    if (_firstFrameEventReceived) {
      // The first frame event was already received.
      return;
    }
    _firstFrameReceived.complete();

    final extensionsToProcess = _pendingServiceExtensions.toList();
    _pendingServiceExtensions.clear();
    await Future.wait([
      for (String extension in extensionsToProcess)
        _addServiceExtension(extension)
    ]);
  }

  Future<void> _onMainIsolateChanged() async {
    if (_mainIsolate.value == null) {
      _mainIsolateClosed();
      return;
    }
    _checkForFirstFrameStarted = false;

    final isolateRef = _mainIsolate.value;
    final Isolate isolate = await _service.getIsolate(isolateRef.id);
    if (isolateRef != _mainIsolate.value) {
      // Isolate has changed again.
      return;
    }
    if (isolate.extensionRPCs != null) {
      if (await connectedApp.isFlutterApp) {
        if (isolateRef != _mainIsolate.value) {
          // Isolate has changed again.
          return;
        }
        for (String extension in isolate.extensionRPCs) {
          await _maybeAddServiceExtension(extension);
          if (isolateRef != _mainIsolate.value) {
            // Isolate has changed again.
            return;
          }
        }
      } else {
        for (String extension in isolate.extensionRPCs) {
          await _addServiceExtension(extension);
          if (isolateRef != _mainIsolate.value) {
            // Isolate has changed again.
            return;
          }
        }
      }
    }
  }

  Future<void> _maybeCheckForFirstFlutterFrame() async {
    final _lastMainIsolate = _mainIsolate.value;
    if (_checkForFirstFrameStarted ||
        _firstFrameEventReceived ||
        _lastMainIsolate == null) return;
    if (!isServiceExtensionAvailable(extensions.didSendFirstFrameEvent)) {
      return;
    }
    _checkForFirstFrameStarted = true;

    final value = await _service.callServiceExtension(
      extensions.didSendFirstFrameEvent,
      isolateId: _lastMainIsolate.id,
    );
    if (_lastMainIsolate != _mainIsolate.value) {
      // The active isolate has changed since we started querying the first
      // frame.
      return;
    }
    final didSendFirstFrameEvent = value?.json['enabled'] == 'true';

    if (didSendFirstFrameEvent) {
      await _onFrameEventReceived();
    }
  }

  Future<void> _maybeAddServiceExtension(String name) async {
    if (_firstFrameEventReceived || !isUnsafeBeforeFirstFlutterFrame(name)) {
      await _addServiceExtension(name);
    } else {
      _pendingServiceExtensions.add(name);
    }
  }

  Future<void> _addServiceExtension(String name) async {
    if (!_serviceExtensions.add(name)) {
      // If the service extension was already added we do not need to add it
      // again. This can happen depending on the timing between when extension
      // added events were received and when we requested the list of all
      // service extensions already defined for the isolate.
      return;
    }
    _hasServiceExtension(name).value = true;

    if (_enabledServiceExtensions.containsKey(name)) {
      // Restore any previously enabled states by calling their service
      // extension. This will restore extension states on the device after a hot
      // restart. [_enabledServiceExtensions] will be empty on page refresh or
      // initial start.
      return await _callServiceExtension(
        name,
        _enabledServiceExtensions[name].value,
      );
    } else {
      // Set any extensions that are already enabled on the device. This will
      // enable extension states in DevTools on page refresh or initial start.
      return await _restoreExtensionFromDevice(name);
    }
  }

  Future<void> _restoreExtensionFromDevice(String name) async {
    final isolateRef = _mainIsolate.value;
    if (isolateRef == null) return;

    if (!extensions.serviceExtensionsAllowlist.containsKey(name)) {
      return;
    }
    final expectedValueType =
        extensions.serviceExtensionsAllowlist[name].values.first.runtimeType;

    Future<void> restore() async {
      // The restore request is obsolete if the isolate has changed.
      if (isolateRef != _mainIsolate.value) return;
      try {
        final response = await _service.callServiceExtension(
          name,
          isolateId: isolateRef.id,
        );

        if (isolateRef != _mainIsolate.value) return;

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

    if (isolateRef != _mainIsolate.value) return;

    final Isolate isolate = await _service.getIsolate(isolateRef.id);
    if (isolateRef != _mainIsolate.value) return;

    // Do not try to restore Dart IO extensions for a paused isolate.
    if (extensions.isDartIoExtension(name) &&
        isolate.pauseEvent.kind.contains('Pause')) {
      _callbacksOnIsolateResume
          .putIfAbsent(isolateRef.id, () => [])
          .add(restore);
    } else {
      await restore();
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

    final mainIsolate = _mainIsolate.value;
    Future<void> callExtension() async {
      if (_mainIsolate.value != mainIsolate) return;

      assert(value != null);
      if (value is bool) {
        Future<void> call(String isolateId, bool value) async {
          await _service.callServiceExtension(
            name,
            isolateId: isolateId,
            args: {'enabled': value},
          );
        }

        if (extensions
            .serviceExtensionsAllowlist[name].shouldCallOnAllIsolates) {
          // TODO(jacobr): be more robust instead of just assuming that if the
          // service extension is available on one isolate it is available on
          // all. For example, some isolates may still be initializing so may
          // not expose the service extension yet.
          await _service.forEachIsolate((isolate) async {
            // TODO(kenz): stop special casing http timeline logging once
            // dart io version 1.4 hits stable (when vm_service 5.3.0 hits
            // Flutter stable).
            // See https://github.com/dart-lang/sdk/issues/43628.
            if (name == extensions.httpEnableTimelineLogging.extension &&
                !(await _service.isDartIoVersionSupported(
                  supportedVersion: SemanticVersion(major: 1, minor: 4),
                  isolateId: isolate.id,
                ))) {
              await _service.httpEnableTimelineLogging(isolate.id, value);
            } else {
              await call(isolate.id, value);
            }
          });
        } else {
          await call(mainIsolate.id, value);
        }
      } else if (value is String) {
        await _service.callServiceExtension(
          name,
          isolateId: mainIsolate.id,
          args: {'value': value},
        );
      } else if (value is double) {
        await _service.callServiceExtension(
          name,
          isolateId: mainIsolate.id,
          // The param name for a numeric service extension will be the last part
          // of the extension name (ext.flutter.extensionName => extensionName).
          args: {name.substring(name.lastIndexOf('.') + 1): value},
        );
      }
    }

    final Isolate isolate = await _service.getIsolate(mainIsolate.id);
    if (_mainIsolate.value != mainIsolate) return;

    // Do not try to call Dart IO extensions for a paused isolate.
    if (extensions.isDartIoExtension(name) &&
        isolate.pauseEvent.kind.contains('Pause')) {
      _callbacksOnIsolateResume
          .putIfAbsent(mainIsolate.id, () => [])
          .add(callExtension);
    } else {
      await callExtension();
    }
  }

  void vmServiceClosed() {
    cancel();
    _mainIsolateClosed();
  }

  void _mainIsolateClosed() {
    _firstFrameReceived = Completer();
    _checkForFirstFrameStarted = false;
    _pendingServiceExtensions.clear();
    _serviceExtensions.clear();
    for (var listenable in _serviceExtensionAvailable.values) {
      listenable.value = false;
    }
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

    final state = ServiceExtensionState(enabled, value);
    _serviceExtensionState(name).value = state;

    // Add or remove service extension from [enabledServiceExtensions].
    if (enabled) {
      _enabledServiceExtensions[name] = state;
    } else {
      _enabledServiceExtensions.remove(name);
    }
  }

  bool isServiceExtensionAvailable(String name) {
    return _serviceExtensions.contains(name) ||
        _pendingServiceExtensions.contains(name);
  }

  ValueListenable<bool> hasServiceExtension(String name) {
    return _hasServiceExtension(name);
  }

  ValueNotifier<bool> _hasServiceExtension(String name) {
    return _serviceExtensionAvailable.putIfAbsent(
      name,
      () => ValueNotifier(_serviceExtensions.contains(name)),
    );
  }

  ValueListenable<ServiceExtensionState> getServiceExtensionState(String name) {
    return _serviceExtensionState(name);
  }

  ValueNotifier<ServiceExtensionState> _serviceExtensionState(String name) {
    return _serviceExtensionStateController.putIfAbsent(
      name,
      () {
        return ValueNotifier<ServiceExtensionState>(
          _enabledServiceExtensions.containsKey(name)
              ? _enabledServiceExtensions[name]
              : ServiceExtensionState(false, null),
        );
      },
    );
  }

  void vmServiceOpened(VmServiceWrapper service, ConnectedApp connectedApp) {
    _checkForFirstFrameStarted = false;
    cancel();
    _connectedApp = connectedApp;
    _service = service;
    autoDispose(service.onExtensionEvent.listen(_handleExtensionEvent));
    addAutoDisposeListener(
      hasServiceExtension(extensions.didSendFirstFrameEvent),
      _maybeCheckForFirstFlutterFrame,
    );
    addAutoDisposeListener(_mainIsolate, _onMainIsolateChanged);
    autoDispose(service.onDebugEvent.listen(_handleDebugEvent));
    autoDispose(service.onIsolateEvent.listen(_handleIsolateEvent));
    if (_mainIsolate.value != null) {
      _onMainIsolateChanged();
    }
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

  @override
  bool operator ==(Object other) {
    return other is ServiceExtensionState &&
        enabled == other.enabled &&
        value == other.value;
  }

  @override
  int get hashCode => hashValues(
        enabled,
        value,
      );
}

class VmFlagManager extends Disposer {
  VmServiceWrapper get service => _service;
  VmServiceWrapper _service;

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

  void vmServiceOpened(VmServiceWrapper service) {
    cancel();
    _service = service;
    // Upon setting the vm service, get initial values for vm flags.
    _initFlags();

    autoDispose(service.onVMEvent.listen(handleVmEvent));
  }

  void vmServiceClosed() {
    _flags.value = null;
  }
}

class VmServiceCapabilities {
  VmServiceCapabilities(this.version);

  final Version version;

  bool get supportsGetScripts =>
      version.major > 3 || (version.major == 3 && version.minor >= 12);
}
