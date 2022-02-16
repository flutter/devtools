// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'dart:async';
import 'dart:core';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import '../analytics/analytics.dart' as ga;
import '../config_specific/logger/logger.dart';
import '../inspector/inspector_service.dart';
import '../logging/vm_service_logger.dart';
import '../performance/timeline_streams.dart';
import '../primitives/auto_dispose.dart';
import '../primitives/message_bus.dart';
import '../primitives/utils.dart';
import 'connected_app.dart';
import 'console_service.dart';
import 'error_badge_manager.dart';
import 'globals.dart';
import 'service_extensions.dart' as extensions;
import 'service_extensions.dart';
import 'service_registrations.dart' as registrations;
import 'title.dart';
import 'version.dart';
import 'vm_flags.dart';
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
    _serviceExtensionManager = ServiceExtensionManager(isolateManager);
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

  final vmFlagManager = VmFlagManager();

  final timelineStreamManager = TimelineStreamManager();

  final isolateManager = IsolateManager();

  final consoleService = ConsoleService();

  InspectorServiceBase get inspectorService => _inspectorService;
  InspectorServiceBase _inspectorService;

  ErrorBadgeManager get errorBadgeManager => _errorBadgeManager;
  final _errorBadgeManager = ErrorBadgeManager();

  ServiceExtensionManager get serviceExtensionManager =>
      _serviceExtensionManager;
  ServiceExtensionManager _serviceExtensionManager;

  ConnectedApp connectedApp;

  VmServiceWrapper service;
  VM vm;
  String sdkVersion;

  bool get hasConnection => service != null && connectedApp != null;

  bool get connectedAppInitialized =>
      hasConnection && connectedApp.connectedAppInitialized;

  ValueListenable<ConnectedState> get connectedState => _connectedState;

  final ValueNotifier<ConnectedState> _connectedState =
      ValueNotifier(const ConnectedState(false));

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
    assert(isolateId != null);
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
    if (service == this.service) {
      // Service already opened.
      return;
    }
    this.service = service;
    await service.initServiceVersions();
    if (_serviceAvailable.isCompleted) {
      _serviceAvailable = Completer();
    }

    connectedApp = ConnectedApp();
    // It is critical we call vmServiceOpened on each manager class before
    // performing any async operations. Otherwise, we may get end up with
    // race conditions where managers cannot listen for events soon enough.
    isolateManager.vmServiceOpened(service);
    consoleService.vmServiceOpened(service);
    serviceExtensionManager.vmServiceOpened(service, connectedApp);
    await vmFlagManager.vmServiceOpened(service);
    await timelineStreamManager.vmServiceOpened(service, connectedApp);
    // This needs to be called last in the above group of `vmServiceOpened`
    // calls.
    errorBadgeManager.vmServiceOpened(service);

    if (debugLogServiceProtocolEvents) {
      serviceTrafficLogger = VmServiceTrafficLogger(service);
    }

    _inspectorService?.dispose();
    _inspectorService = null;

    final serviceStreamName = await service.serviceStreamName;
    if (service != this.service) {
      // A different service has been opened.
      return;
    }

    vm = await service.getVM();

    if (service != this.service) {
      // A different service has been opened.
      return;
    }
    sdkVersion = vm.version;
    if (sdkVersion.contains(' ')) {
      sdkVersion = sdkVersion.substring(0, sdkVersion.indexOf(' '));
    }

    if (_serviceAvailable.isCompleted) {
      return;
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

    for (final id in streamIds) {
      try {
        unawaited(service.streamListen(id));
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
    }
    if (service != this.service) {
      // A different service has been opened.
      return;
    }

    _connectedState.value = const ConnectedState(true);

    final isolates = [
      ...vm.isolates,
      if (preferences.vmDeveloperModeEnabled.value) ...vm.systemIsolates,
    ];

    await isolateManager.init(isolates);
    if (service != this.service) {
      // A different service has been opened.
      return;
    }

    // This needs to be called before calling
    // `ga.setupUserApplicationDimensions()`.
    await connectedApp.initializeValues();
    if (service != this.service) {
      // A different service has been opened.
      return;
    }

    _inspectorService = devToolsExtensionPoints.inspectorServiceProvider();

    // Set up analytics dimensions for the connected app.
    await ga.setupUserApplicationDimensions();
    if (service != this.service) {
      // A different service has been opened.
      return;
    }

    _connectionAvailableController.add(service);
  }

  void manuallyDisconnect() {
    vmServiceClosed(
      connectionState:
          const ConnectedState(false, userInitiatedConnectionState: true),
    );
  }

  void vmServiceClosed({
    ConnectedState connectionState = const ConnectedState(false),
  }) {
    _serviceAvailable = Completer();

    service = null;
    vm = null;
    sdkVersion = null;
    connectedApp = null;
    generateDevToolsTitle();

    vmFlagManager.vmServiceClosed();
    timelineStreamManager.vmServiceClosed();
    serviceExtensionManager.vmServiceClosed();

    serviceTrafficLogger?.dispose();

    isolateManager._handleVmServiceClosed();
    consoleService.handleVmServiceClosed();
    setDeviceBusy(false);

    _connectedState.value = connectionState;
    _connectionClosedController.add(null);

    _inspectorService?.onIsolateStopped();
    _inspectorService?.dispose();
    _inspectorService = null;
  }

  /// This can throw an [RPCError].
  Future<void> performHotReload() async {
    return await _callServiceOnMainIsolate(
      registrations.hotReload.service,
    );
  }

  /// This can throw an [RPCError].
  Future<void> performHotRestart() async {
    return await _callServiceOnMainIsolate(
      registrations.hotRestart.service,
    );
  }

  Future<Response> get flutterVersion async {
    return await _callServiceOnMainIsolate(
      registrations.flutterVersion.service,
    );
  }

  Future<void> sendDwdsEvent({
    @required String screen,
    @required String action,
  }) async {
    if (!kIsWeb) return;
    return await _callServiceExtensionOnMainIsolate(registrations.dwdsSendEvent,
        args: {
          'type': 'DevtoolsEvent',
          'payload': {
            'screen': screen,
            'action': action,
          },
        });
  }

  Future<Response> _callServiceOnMainIsolate(String name) async {
    final isolate = await whenValueNonNull(isolateManager.mainIsolate);
    return await callService(name, isolateId: isolate.id);
  }

  Future<Response> _callServiceExtensionOnMainIsolate(
    String method, {
    Map<String, dynamic> args,
  }) async {
    final isolate = await whenValueNonNull(isolateManager.mainIsolate);

    return await service.callServiceExtension(
      method,
      args: args,
      isolateId: isolate.id,
    );
  }

  Future<Response> get adbMemoryInfo async {
    return await _callServiceOnMainIsolate(
      registrations.flutterMemory.service,
    );
  }

  /// @returns view id of selected isolate's 'FlutterView'.
  /// @throws Exception if no 'FlutterView'.
  Future<String> get flutterViewId async {
    final flutterViewListResponse = await _callServiceExtensionOnMainIsolate(
        registrations.flutterListViews);
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

    return await _callServiceExtensionOnMainIsolate(
      registrations.flutterEngineEstimateRasterCache,
      args: <String, String>{
        'viewId': viewId,
      },
    );
  }

  Future<double> get queryDisplayRefreshRate async {
    if (connectedApp == null || !await connectedApp.isFlutterApp) {
      return null;
    }

    const unknownRefreshRate = 0.0;

    final viewId = await flutterViewId;
    final displayRefreshRateResponse = await _callServiceExtensionOnMainIsolate(
      registrations.displayRefreshRate,
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
    assert(serviceManager.isolateManager.mainIsolate.value != null);
    final isolate = isolateManager.mainIsolateDebuggerState.isolateNow;
    assert(isolate != null);
    return isolate.libraries
        .map((ref) => ref.uri)
        .toList()
        .any((u) => u.startsWith(uri));
  }

  Future<bool> libraryUriAvailable(String uri) async {
    assert(_serviceAvailable.isCompleted);
    await whenValueNonNull(isolateManager.mainIsolate);
    return libraryUriAvailableNow(uri);
  }
}

class IsolateState {
  IsolateState(this.isolateRef);

  ValueListenable<bool> get isPaused => _isPaused;

  final IsolateRef isolateRef;

  Future<Isolate> get isolate => _isolate.future;
  Completer<Isolate> _isolate = Completer();

  Isolate get isolateNow => _isolateNow;
  Isolate _isolateNow;

  /// Paused is null until we know whether the isolate is paused or not.
  final _isPaused = ValueNotifier<bool>(null);

  void onIsolateLoaded(Isolate isolate) {
    _isolateNow = isolate;
    _isolate.complete(isolate);
    if (_isPaused.value == null) {
      if (isolate.pauseEvent != null &&
          isolate.pauseEvent.kind != EventKind.kResume) {
        _isPaused.value = true;
      } else {
        _isPaused.value = false;
      }
    }
  }

  void dispose() {
    _isolateNow = null;
    if (!_isolate.isCompleted) {
      _isolate.complete(null);
    } else {
      _isolate = Completer()..complete(null);
    }
  }
}

class IsolateManager extends Disposer {
  final _isolateStates = <IsolateRef, IsolateState>{};
  VmServiceWrapper _service;

  final StreamController<IsolateRef> _isolateCreatedController =
      StreamController<IsolateRef>.broadcast();
  final StreamController<IsolateRef> _isolateExitedController =
      StreamController<IsolateRef>.broadcast();

  ValueListenable<IsolateRef> get selectedIsolate => _selectedIsolate;
  final _selectedIsolate = ValueNotifier<IsolateRef>(null);

  int _lastIsolateIndex = 0;
  final Map<String, int> _isolateIndexMap = {};

  ValueListenable<List<IsolateRef>> get isolates => _isolates;
  final _isolates = ListValueNotifier(const <IsolateRef>[]);

  Stream<IsolateRef> get onIsolateCreated => _isolateCreatedController.stream;

  Stream<IsolateRef> get onIsolateExited => _isolateExitedController.stream;

  ValueListenable<IsolateRef> get mainIsolate => _mainIsolate;
  final _mainIsolate = ValueNotifier<IsolateRef>(null);

  final _isolateRunnableCompleters = <String, Completer<void>>{};

  Future<void> init(List<IsolateRef> isolates) async {
    // Re-initialize isolates when VM developer mode is enabled/disabled to
    // display/hide system isolates.
    addAutoDisposeListener(preferences.vmDeveloperModeEnabled, () async {
      final vmDeveloperModeEnabled = preferences.vmDeveloperModeEnabled.value;
      final vm = await serviceManager.service.getVM();
      final isolates = [
        ...vm.isolates,
        if (vmDeveloperModeEnabled) ...vm.systemIsolates,
      ];
      if (selectedIsolate.value.isSystemIsolate && !vmDeveloperModeEnabled) {
        selectIsolate(_isolates.value.first);
      }
      await _initIsolates(isolates);
    });
    await _initIsolates(isolates);
  }

  IsolateState get mainIsolateDebuggerState {
    return _isolateStates[_mainIsolate.value];
  }

  IsolateState isolateDebuggerState(IsolateRef isolate) {
    return _isolateStates[isolate];
  }

  IsolateState get selectedIsolateState {
    return _isolateStates[_mainIsolate.value];
  }

  /// Return a unique, monotonically increasing number for this Isolate.
  int isolateIndex(IsolateRef isolateRef) {
    if (!_isolateIndexMap.containsKey(isolateRef.id)) {
      _isolateIndexMap[isolateRef.id] = ++_lastIsolateIndex;
    }
    return _isolateIndexMap[isolateRef.id];
  }

  void selectIsolate(IsolateRef isolateRef) {
    _setSelectedIsolate(isolateRef);
  }

  Future<void> _initIsolates(List<IsolateRef> isolates) async {
    _clearIsolateStates();

    await Future.wait([
      for (final isolateRef in isolates) _registerIsolate(isolateRef),
    ]);

    // It is critical that the _serviceExtensionManager is already listening
    // for events indicating that new extension rpcs are registered before this
    // call otherwise there is a race condition where service extensions are not
    // described in the selectedIsolate or recieved as an event. It is ok if a
    // service extension is included in both places as duplicate extensions are
    // handled gracefully.
    await _initSelectedIsolate();
  }

  Future<void> _registerIsolate(IsolateRef isolateRef) async {
    assert(!_isolateStates.containsKey(isolateRef));
    _isolateStates[isolateRef] = IsolateState(isolateRef);
    _isolates.add(isolateRef);
    isolateIndex(isolateRef);
    await _loadIsolateState(isolateRef);
  }

  Future<void> _loadIsolateState(IsolateRef isolateRef) async {
    final service = _service;
    var isolate = await _service.getIsolate(isolateRef.id);
    if (!isolate.runnable) {
      final isolateRunnableCompleter = _isolateRunnableCompleters.putIfAbsent(
        isolate.id,
        () => Completer<void>(),
      );
      if (!isolateRunnableCompleter.isCompleted) {
        await isolateRunnableCompleter.future;
        isolate = await _service.getIsolate(isolate.id);
      }
    }
    if (service != _service) return;
    final state = _isolateStates[isolateRef];
    if (state != null) {
      // Isolate might have already been closed.
      state.onIsolateLoaded(isolate);
    }
  }

  Future<void> _handleIsolateEvent(Event event) async {
    _sendToMessageBus(event);
    if (event.kind == EventKind.kIsolateRunnable) {
      final isolateRunnable = _isolateRunnableCompleters.putIfAbsent(
        event.isolate.id,
        () => Completer<void>(),
      );
      isolateRunnable.complete();
    } else if (event.kind == EventKind.kIsolateStart &&
        !event.isolate.isSystemIsolate) {
      await _registerIsolate(event.isolate);
      _isolateCreatedController.add(event.isolate);
      // TODO(jacobr): we assume the first isolate started is the main isolate
      // but that may not always be a safe assumption.
      _mainIsolate.value ??= event.isolate;

      if (_selectedIsolate.value == null) {
        _setSelectedIsolate(event.isolate);
      }
    } else if (event.kind == EventKind.kServiceExtensionAdded) {
      // Check to see if there is a new isolate.
      if (_selectedIsolate.value == null &&
          extensions.isFlutterExtension(event.extensionRPC)) {
        _setSelectedIsolate(event.isolate);
      }
    } else if (event.kind == EventKind.kIsolateExit) {
      _isolateStates.remove(event.isolate)?.dispose();
      _isolates.remove(event.isolate);
      _isolateExitedController.add(event.isolate);
      if (_mainIsolate.value == event.isolate) {
        _mainIsolate.value = null;
      }
      if (_selectedIsolate.value == event.isolate) {
        _selectedIsolate.value =
            _isolateStates.isEmpty ? null : _isolateStates.keys.first;
      }
      _isolateRunnableCompleters.remove(event.isolate.id);
    }
  }

  void _sendToMessageBus(Event event) {
    messageBus?.addEvent(BusEvent(
      'debugger',
      data: event,
    ));
  }

  Future<void> _initSelectedIsolate() async {
    if (_isolateStates.isEmpty) {
      return;
    }
    _mainIsolate.value = null;
    final service = _service;
    final mainIsolate = await _computeMainIsolate();
    if (service != _service) return;
    _mainIsolate.value = mainIsolate;
    _setSelectedIsolate(_mainIsolate.value);
  }

  Future<IsolateRef> _computeMainIsolate() async {
    if (_isolateStates.isEmpty) return null;

    final service = _service;
    for (var isolateState in _isolateStates.values) {
      if (_selectedIsolate.value == null) {
        final isolate = await isolateState.isolate;
        if (service != _service) return null;
        if (isolate.extensionRPCs != null) {
          for (String extensionName in isolate.extensionRPCs) {
            if (extensions.isFlutterExtension(extensionName)) {
              return isolateState.isolateRef;
            }
          }
        }
      }
    }

    final IsolateRef ref = _isolateStates.keys.firstWhere((IsolateRef ref) {
      // 'foo.dart:main()'
      return ref.name.contains(':main(');
    }, orElse: () => null);

    return ref ?? _isolateStates.keys.first;
  }

  void _setSelectedIsolate(IsolateRef ref) {
    _selectedIsolate.value = ref;
  }

  void _handleVmServiceClosed() {
    cancelStreamSubscriptions();
    _selectedIsolate.value = null;
    _service = null;
    _lastIsolateIndex = 0;
    _setSelectedIsolate(null);
    _isolateIndexMap.clear();
    _clearIsolateStates();
    _mainIsolate.value = null;
    _isolateRunnableCompleters.clear();
  }

  void _clearIsolateStates() {
    for (var isolateState in _isolateStates.values) {
      isolateState.dispose();
    }
    _isolateStates.clear();
    _isolates.clear();
  }

  void vmServiceOpened(VmServiceWrapper service) {
    _selectedIsolate.value = null;

    cancelStreamSubscriptions();
    _service = service;
    autoDisposeStreamSubscription(
        service.onIsolateEvent.listen(_handleIsolateEvent));
    autoDisposeStreamSubscription(
        service.onDebugEvent.listen(_handleDebugEvent));

    // We don't yet known the main isolate.
    _mainIsolate.value = null;
  }

  Future<Isolate> getIsolateCached(IsolateRef isolateRef) {
    final isolateState =
        _isolateStates.putIfAbsent(isolateRef, () => IsolateState(isolateRef));
    return isolateState.isolate;
  }

  void _handleDebugEvent(Event event) {
    final isolate = event.isolate;
    final isolateState = _isolateStates[isolate];
    assert(isolateState != null);
    if (isolateState == null) {
      return;
    }

    switch (event.kind) {
      case EventKind.kResume:
        isolateState._isPaused.value = false;
        break;
      case EventKind.kPauseStart:
      case EventKind.kPauseExit:
      case EventKind.kPauseBreakpoint:
      case EventKind.kPauseInterrupted:
      case EventKind.kPauseException:
      case EventKind.kPausePostRequest:
        isolateState._isPaused.value = true;
        break;
    }
  }
}

/// Manager that handles tracking the service extension for the main isolate.
class ServiceExtensionManager extends Disposer {
  ServiceExtensionManager(this._isolateManager);

  VmServiceWrapper _service;

  bool _checkForFirstFrameStarted = false;

  final IsolateManager _isolateManager;

  Future<void> get firstFrameReceived => _firstFrameReceived.future;
  Completer<void> _firstFrameReceived = Completer();

  bool get _firstFrameEventReceived => _firstFrameReceived.isCompleted;

  final _serviceExtensionAvailable = <String, ValueNotifier<bool>>{};

  final _serviceExtensionStateController =
      <String, ValueNotifier<ServiceExtensionState>>{};

  /// All available service extensions.
  final _serviceExtensions = <String>{};

  /// All service extensions that are currently enabled.
  final _enabledServiceExtensions = <String, ServiceExtensionState>{};

  /// Map from service extension name to [Completer] that completes when the
  /// service extension is registered or the isolate shuts down.
  final _maybeRegisteringServiceExtensions = <String, Completer<bool>>{};

  /// Temporarily stores service extensions that we need to add. We should not
  /// add extensions until the first frame event has been received
  /// [_firstFrameEventReceived].
  final _pendingServiceExtensions = <String>{};

  Map<IsolateRef, List<AsyncCallback>> _callbacksOnIsolateResume = {};

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
      final isolateRef = event.isolate;
      final callbacks = _callbacksOnIsolateResume[isolateRef] ?? [];
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
        enabled: enabled,
        value: extensionValue,
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
    if (_isolateManager.mainIsolate.value == null) {
      _mainIsolateClosed();
      return;
    }
    _checkForFirstFrameStarted = false;

    final isolateRef = _isolateManager.mainIsolate.value;
    final Isolate isolate = await _isolateManager.getIsolateCached(isolateRef);

    await _registerMainIsolate(isolate, isolateRef);
  }

  Future<void> _registerMainIsolate(
      Isolate mainIsolate, IsolateRef expectedMainIsolateRef) async {
    if (expectedMainIsolateRef != _isolateManager.mainIsolate.value) {
      // Isolate has changed again.
      return;
    }

    if (mainIsolate.extensionRPCs != null) {
      if (await connectedApp.isFlutterApp) {
        if (expectedMainIsolateRef != _isolateManager.mainIsolate.value) {
          // Isolate has changed again.
          return;
        }
        await Future.wait([
          for (String extension in mainIsolate.extensionRPCs)
            _maybeAddServiceExtension(extension)
        ]);
      } else {
        await Future.wait([
          for (String extension in mainIsolate.extensionRPCs)
            _addServiceExtension(extension)
        ]);
      }
    }
  }

  Future<void> _maybeCheckForFirstFlutterFrame() async {
    final _lastMainIsolate = _isolateManager.mainIsolate.value;
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
    if (_lastMainIsolate != _isolateManager.mainIsolate.value) {
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
    final isolateRef = _isolateManager.mainIsolate.value;
    if (isolateRef == null) return;

    if (!extensions.serviceExtensionsAllowlist.containsKey(name)) {
      return;
    }
    final expectedValueType =
        extensions.serviceExtensionsAllowlist[name].values.first.runtimeType;

    Future<void> restore() async {
      // The restore request is obsolete if the isolate has changed.
      if (isolateRef != _isolateManager.mainIsolate.value) return;
      try {
        final response = await _service.callServiceExtension(
          name,
          isolateId: isolateRef.id,
        );

        if (isolateRef != _isolateManager.mainIsolate.value) return;

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

    if (isolateRef != _isolateManager.mainIsolate.value) return;

    final Isolate isolate = await _isolateManager.getIsolateCached(isolateRef);
    if (isolateRef != _isolateManager.mainIsolate.value) return;

    // Do not try to restore Dart IO extensions for a paused isolate.
    if (extensions.isDartIoExtension(name) &&
        isolate.pauseEvent.kind.contains('Pause')) {
      _callbacksOnIsolateResume.putIfAbsent(isolateRef, () => []).add(restore);
    } else {
      await restore();
    }
  }

  Future<void> _maybeRestoreExtension(String name, dynamic value) async {
    final extensionDescription = extensions.serviceExtensionsAllowlist[name];
    if (extensionDescription
        is extensions.ToggleableServiceExtensionDescription) {
      if (value == extensionDescription.enabledValue) {
        await setServiceExtensionState(
          name,
          enabled: true,
          value: value,
          callExtension: false,
        );
      }
    } else {
      await setServiceExtensionState(
        name,
        enabled: true,
        value: value,
        callExtension: false,
      );
    }
  }

  Future<void> _callServiceExtension(String name, dynamic value) async {
    if (_service == null) {
      return;
    }

    final mainIsolate = _isolateManager.mainIsolate.value;
    Future<void> callExtension() async {
      if (_isolateManager.mainIsolate.value != mainIsolate) return;

      assert(value != null);
      if (value is bool) {
        Future<void> call(String isolateId, bool value) async {
          await _service.callServiceExtension(
            name,
            isolateId: isolateId,
            args: {'enabled': value},
          );
        }

        final description = extensions.serviceExtensionsAllowlist[name];
        if (description?.shouldCallOnAllIsolates ?? false) {
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

    if (mainIsolate == null) return;
    final Isolate isolate = await _isolateManager.getIsolateCached(mainIsolate);
    if (_isolateManager.mainIsolate.value != mainIsolate) return;

    // Do not try to call Dart IO extensions for a paused isolate.
    if (extensions.isDartIoExtension(name) &&
        isolate.pauseEvent.kind.contains('Pause')) {
      _callbacksOnIsolateResume
          .putIfAbsent(mainIsolate, () => [])
          .add(callExtension);
    } else {
      await callExtension();
    }
  }

  void vmServiceClosed() {
    cancelStreamSubscriptions();
    _mainIsolateClosed();
  }

  void _mainIsolateClosed() {
    _firstFrameReceived = Completer();
    _checkForFirstFrameStarted = false;
    _pendingServiceExtensions.clear();
    _serviceExtensions.clear();

    // If the isolate has closed, there is no need to wait any longer for
    // service extensions that might be registered.
    for (var completer in _maybeRegisteringServiceExtensions.values) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }
    _maybeRegisteringServiceExtensions.clear();

    for (var listenable in _serviceExtensionAvailable.values) {
      listenable.value = false;
    }
  }

  /// Sets the state for a service extension and makes the call to the VMService.
  Future<void> setServiceExtensionState(
    String name, {
    @required bool enabled,
    @required dynamic value,
    bool callExtension = true,
  }) async {
    if (callExtension && _serviceExtensions.contains(name)) {
      await _callServiceExtension(name, value);
    } else if (callExtension) {
      log('Attempted to call extension \'$name\', but no service with that name exists');
    }

    final state = ServiceExtensionState(enabled: enabled, value: value);
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

  Future<bool> waitForServiceExtensionAvailable(String name) {
    if (isServiceExtensionAvailable(name)) return Future.value(true);

    Completer<bool> createCompleter() {
      // Listen for when the service extension is added and use it.
      final completer = Completer<bool>();
      final listenable = hasServiceExtension(name);
      VoidCallback listener;
      listener = () {
        if (listenable.value || completer.isCompleted) {
          listenable.removeListener(listener);
          completer.complete(true);
        }
      };
      hasServiceExtension(name).addListener(listener);
      return completer;
    }

    _maybeRegisteringServiceExtensions[name] ??= createCompleter();
    return _maybeRegisteringServiceExtensions[name].future;
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
              : ServiceExtensionState(enabled: false, value: null),
        );
      },
    );
  }

  void vmServiceOpened(
      VmServiceWrapper service, ConnectedApp connectedApp) async {
    _checkForFirstFrameStarted = false;
    cancelStreamSubscriptions();
    cancelListeners();
    _connectedApp = connectedApp;
    _service = service;
    // TODO(kenz): do we want to listen with event history here?
    autoDisposeStreamSubscription(
        service.onExtensionEvent.listen(_handleExtensionEvent));
    addAutoDisposeListener(
      hasServiceExtension(extensions.didSendFirstFrameEvent),
      _maybeCheckForFirstFlutterFrame,
    );
    addAutoDisposeListener(_isolateManager.mainIsolate, _onMainIsolateChanged);
    autoDisposeStreamSubscription(
        service.onDebugEvent.listen(_handleDebugEvent));
    autoDisposeStreamSubscription(
        service.onIsolateEvent.listen(_handleIsolateEvent));
    final mainIsolateRef = _isolateManager.mainIsolate.value;
    if (mainIsolateRef != null) {
      _checkForFirstFrameStarted = false;
      final mainIsolate =
          await _isolateManager.getIsolateCached(mainIsolateRef);
      await _registerMainIsolate(mainIsolate, mainIsolateRef);
    }
  }
}

class ServiceExtensionState {
  ServiceExtensionState({@required this.enabled, @required this.value}) {
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

class VmServiceCapabilities {
  VmServiceCapabilities(this.version);

  final Version version;

  bool get supportsGetScripts =>
      version.major > 3 || (version.major == 3 && version.minor >= 12);
}

class ConnectedState {
  const ConnectedState(
    this.connected, {
    this.userInitiatedConnectionState = false,
  });

  final bool connected;

  /// Whether this [ConnectedState] was manually initiated by the user.
  final bool userInitiatedConnectionState;
}
