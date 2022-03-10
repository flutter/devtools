// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:async';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import '../analytics/analytics.dart' as ga;
import '../config_specific/logger/logger.dart';
import '../primitives/utils.dart';
import '../screens/inspector/inspector_service.dart';
import '../screens/logging/vm_service_logger.dart';
import '../screens/performance/timeline_streams.dart';
import '../shared/connected_app.dart';
import '../shared/console_service.dart';
import '../shared/error_badge_manager.dart';
import '../shared/globals.dart';
import '../shared/title.dart';
import 'isolate_manager.dart';
import 'service_extension_manager.dart';
import 'service_registrations.dart' as registrations;
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

  VmServiceCapabilities? _serviceCapabilities;
  VmServiceTrafficLogger? serviceTrafficLogger;

  Future<VmServiceCapabilities> get serviceCapabilities async {
    if (_serviceCapabilities == null) {
      await _serviceAvailable.future;
      final version = await service!.getVersion();
      _serviceCapabilities = VmServiceCapabilities(version);
    }
    return _serviceCapabilities!;
  }

  final _registeredServiceNotifiers = <String, ImmediateValueNotifier<bool>>{};

  Map<String, List<String>> get registeredMethodsForService =>
      _registeredMethodsForService;
  final Map<String, List<String>> _registeredMethodsForService = {};

  final vmFlagManager = VmFlagManager();

  final timelineStreamManager = TimelineStreamManager();

  final isolateManager = IsolateManager();

  final consoleService = ConsoleService();

  InspectorServiceBase? get inspectorService => _inspectorService;
  InspectorServiceBase? _inspectorService;

  ErrorBadgeManager get errorBadgeManager => _errorBadgeManager;
  final _errorBadgeManager = ErrorBadgeManager();

  ServiceExtensionManager get serviceExtensionManager =>
      _serviceExtensionManager;
  late final ServiceExtensionManager _serviceExtensionManager;

  ConnectedApp? connectedApp;

  VmServiceWrapper? service;
  VM? vm;
  String? sdkVersion;

  bool get hasConnection => service != null && connectedApp != null;

  bool get connectedAppInitialized =>
      hasConnection && connectedApp!.connectedAppInitialized;

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
    String? isolateId,
    Map<String, dynamic>? args,
  }) async {
    final registered = _registeredMethodsForService[name] ?? const [];
    if (registered.isEmpty) {
      throw Exception('There are no registered methods for service "$name"');
    }
    return service!.callMethod(
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
    required Future<void> onClosed,
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
    serviceExtensionManager.vmServiceOpened(service, connectedApp!);
    await vmFlagManager.vmServiceOpened(service);
    await timelineStreamManager.vmServiceOpened(service, connectedApp!);
    // This needs to be called last in the above group of `vmServiceOpened`
    // calls.
    errorBadgeManager.vmServiceOpened(service);

    if (debugLogServiceProtocolEvents) {
      serviceTrafficLogger = VmServiceTrafficLogger(service);
    }

    _inspectorService?.dispose();
    _inspectorService = null;

    if (service != this.service) {
      // A different service has been opened.
      return;
    }

    vm = await service.getVM();

    if (service != this.service) {
      // A different service has been opened.
      return;
    }
    sdkVersion = vm!.version;
    if (sdkVersion?.contains(' ') == true) {
      sdkVersion = sdkVersion!.substring(0, sdkVersion!.indexOf(' '));
    }

    if (_serviceAvailable.isCompleted) {
      return;
    }
    _serviceAvailable.complete(service);

    setDeviceBusy(false);

    unawaited(onClosed.then((_) => vmServiceClosed()));

    void handleServiceEvent(Event e) {
      if (e.kind == EventKind.kServiceRegistered) {
        final serviceName = e.service!;
        _registeredMethodsForService
            .putIfAbsent(serviceName, () => [])
            .add(e.method!);
        final serviceNotifier = _registeredServiceNotifiers.putIfAbsent(
          serviceName,
          () => ImmediateValueNotifier(true),
        );
        serviceNotifier.value = true;
      }

      if (e.kind == EventKind.kServiceUnregistered) {
        final serviceName = e.service!;
        _registeredMethodsForService.remove(serviceName);
        final serviceNotifier = _registeredServiceNotifiers.putIfAbsent(
          serviceName,
          () => ImmediateValueNotifier(false),
        );
        serviceNotifier.value = false;
      }
    }

    service.onEvent(EventStreams.kService).listen(handleServiceEvent);

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
      EventStreams.kService,
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

    final isolates = <IsolateRef>[
      ...vm?.isolates ?? [],
      if (preferences.vmDeveloperModeEnabled.value) ...vm?.systemIsolates ?? [],
    ];

    await isolateManager.init(isolates);
    if (service != this.service) {
      // A different service has been opened.
      return;
    }

    // This needs to be called before calling
    // `ga.setupUserApplicationDimensions()`.
    await connectedApp!.initializeValues();
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

    isolateManager.handleVmServiceClosed();
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
    await _callServiceOnMainIsolate(
      registrations.hotReload.service,
    );
  }

  /// This can throw an [RPCError].
  Future<void> performHotRestart() async {
    await _callServiceOnMainIsolate(
      registrations.hotRestart.service,
    );
  }

  Future<Response> get flutterVersion async {
    return await _callServiceOnMainIsolate(
      registrations.flutterVersion.service,
    );
  }

  Future<void> sendDwdsEvent({
    required String screen,
    required String action,
  }) async {
    if (!kIsWeb) return;
    await _callServiceExtensionOnMainIsolate(registrations.dwdsSendEvent,
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
    return await callService(name, isolateId: isolate?.id);
  }

  Future<Response> _callServiceExtensionOnMainIsolate(
    String method, {
    Map<String, dynamic>? args,
  }) async {
    final isolate = await whenValueNonNull(isolateManager.mainIsolate);

    return await service!.callServiceExtension(
      method,
      args: args,
      isolateId: isolate?.id,
    );
  }

  Future<Response> get adbMemoryInfo async {
    return await _callServiceOnMainIsolate(
      registrations.flutterMemoryInfo.service,
    );
  }

  /// @returns view id of selected isolate's 'FlutterView'.
  /// @throws Exception if no 'FlutterView'.
  Future<String> get flutterViewId async {
    final flutterViewListResponse = await _callServiceExtensionOnMainIsolate(
        registrations.flutterListViews);
    final List<dynamic> views =
        flutterViewListResponse.json!['views'].cast<Map<String, dynamic>>();

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
  Future<Response?> get rasterCacheMetrics async {
    if (connectedApp == null || !await connectedApp!.isFlutterApp) {
      return null;
    }

    final viewId = await flutterViewId;

    return await _callServiceExtensionOnMainIsolate(
      registrations.flutterEngineEstimateRasterCache,
      args: {
        'viewId': viewId,
      },
    );
  }

  Future<double?> get queryDisplayRefreshRate async {
    if (connectedApp == null || !await connectedApp!.isFlutterApp) {
      return null;
    }

    const unknownRefreshRate = 0.0;

    final viewId = await flutterViewId;
    final displayRefreshRateResponse = await _callServiceExtensionOnMainIsolate(
      registrations.displayRefreshRate,
      args: {'viewId': viewId},
    );
    final double fps = displayRefreshRateResponse.json!['fps'];

    // The Flutter engine returns 0.0 if the refresh rate is unknown. Return
    // [defaultRefreshRate] instead.
    if (fps == unknownRefreshRate) {
      return defaultRefreshRate;
    }

    return fps.roundToDouble();
  }

  bool libraryUriAvailableNow(String? uri) {
    if (uri == null) return false;
    assert(_serviceAvailable.isCompleted);
    assert(serviceManager.isolateManager.mainIsolate.value != null);
    final isolate = isolateManager.mainIsolateDebuggerState!.isolateNow!;
    return (isolate.libraries ?? [])
        .map((ref) => ref.uri)
        .toList()
        .any((u) => u?.startsWith(uri) == true);
  }

  Future<bool> libraryUriAvailable(String uri) async {
    assert(_serviceAvailable.isCompleted);
    await whenValueNonNull(isolateManager.mainIsolate);
    return libraryUriAvailableNow(uri);
  }
}

class VmServiceCapabilities {
  VmServiceCapabilities(this.version);

  final Version version;

  bool get supportsGetScripts =>
      version.major! > 3 || (version.major == 3 && version.minor! >= 12);
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
