// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import '../utils/utils.dart';
import 'connected_app.dart';
import 'flutter_version.dart';
import 'isolate_manager.dart';
import 'isolate_state.dart';
import 'service_extension_manager.dart';
import 'service_extensions.dart';
import 'service_utils.dart';

final _log = Logger('service_manager');

typedef ServiceManagerCallback<T> = FutureOr<void> Function(T? service);

enum ServiceManagerLifecycle {
  /// Lifecycle phase that occurs before the service manager is set up for
  /// connection to a [VmService].
  beforeOpenVmService,

  /// Lifecycle phase that occurs after the service manager is set up for
  /// connection to a [VmService].
  afterOpenVmService,

  /// Lifecycle phase that occurs before the service manager closes the
  /// connection to a [VmService].
  beforeCloseVmService,

  /// Lifecycle phase that occurs after the service manager closes the
  /// connection to a [VmService].
  afterCloseVmService,
}

enum ServiceManagerOverride {
  initIsolates,
}

// TODO(kenz): add an offline service manager implementation.
// TODO(https://github.com/flutter/devtools/issues/6239): try to remove this.
@sealed
class ServiceManager<T extends VmService> {
  ServiceManager() {
    _serviceExtensionManager = ServiceExtensionManager(isolateManager);
  }

  Completer<VmService> _serviceAvailable = Completer();

  // TODO(kenz): try to replace uses of this with a listener on [connectedState]
  Future<VmService> get onServiceAvailable => _serviceAvailable.future;

  bool get isServiceAvailable => _serviceAvailable.isCompleted;

  VmServiceCapabilities? _serviceCapabilities;

  Future<VmServiceCapabilities> get serviceCapabilities async {
    if (_serviceCapabilities == null) {
      await _serviceAvailable.future;
      final version = await service!.getVersion();
      _serviceCapabilities = VmServiceCapabilities(version);
    }
    return _serviceCapabilities!;
  }

  final _registeredServiceNotifiers = <String, ImmediateValueNotifier<bool>>{};

  /// Mapping of service name to service method.
  Map<String, String> get registeredMethodsForService =>
      _registeredMethodsForService;
  final Map<String, String> _registeredMethodsForService = {};

  final isolateManager = IsolateManager();

  /// Proxy to state inside the isolateManager, for code consizeness.
  ///
  /// Defaults to false if there is no main isolate.
  bool get isMainIsolatePaused =>
      isolateManager.mainIsolateState?.isPaused.value ?? false;

  Future<RootInfo?> tryToDetectMainRootInfo() async {
    await isolateManager.mainIsolateState?.waitForIsolateLoad();
    return isolateManager.mainIsolateState?.rootInfo;
  }

  RootInfo rootInfoNow() {
    return isolateManager.mainIsolateState?.rootInfo ?? RootInfo(null);
  }

  ServiceExtensionManager get serviceExtensionManager =>
      _serviceExtensionManager;
  late final ServiceExtensionManager _serviceExtensionManager;

  ConnectedApp? connectedApp;

  T? service;
  VM? vm;
  String? sdkVersion;

  bool get hasConnection => service != null && connectedApp != null;

  bool get connectedAppInitialized =>
      hasConnection && connectedApp!.connectedAppInitialized;

  ValueListenable<ConnectedState> get connectedState => _connectedState;

  final ValueNotifier<ConnectedState> _connectedState =
      ValueNotifier(const ConnectedState(false));

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
  Future<V> runDeviceBusyTask<V>(Future<V> task) async {
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
  }) {
    final registeredMethod = _registeredMethodsForService[name];
    if (registeredMethod == null) {
      throw Exception('There is no registered method for service "$name"');
    }
    return service!.callMethod(
      registeredMethod,
      isolateId: isolateId,
      args: args,
    );
  }

  ValueListenable<bool> registeredServiceListenable(String name) {
    return _registeredServiceNotifiers.putIfAbsent(
      name,
      () => ImmediateValueNotifier(false),
    );
  }

  final _lifecycleCallbacks =
      <ServiceManagerLifecycle, List<ServiceManagerCallback<T>>>{};

  /// Registers a callback that will be called at a particular phase in the
  /// lifecycle of opening or closing a [VmService] connection.
  ///
  /// See [ServiceManagerLifecycle].
  void registerLifecycleCallback(
    ServiceManagerLifecycle lifecycle,
    ServiceManagerCallback<T> callback,
  ) {
    _lifecycleCallbacks
        .putIfAbsent(
          lifecycle,
          () => <ServiceManagerCallback<T>>[],
        )
        .add(callback);
  }

  @protected
  FutureOr<void> callLifecycleCallbacks(
    ServiceManagerLifecycle lifecycle,
    T? service,
  ) async {
    final callbacks =
        _lifecycleCallbacks[lifecycle] ?? <ServiceManagerCallback<T>>[];
    await Future.wait(callbacks.map((c) async => await c.call(service)));
  }

  final _overrides = <ServiceManagerOverride, ServiceManagerCallback<T>>{};

  /// Registers a callback that will be called in place of the default
  /// [ServiceManager] logic for a codeblock defined by a
  /// [ServiceManagerOverride].
  void registerOverride(
    ServiceManagerOverride override,
    ServiceManagerCallback<T> callback,
  ) {
    _overrides[override] = callback;
  }

  /// Initializes the service manager for a new vm service connection [service].
  Future<void> vmServiceOpened(
    T service, {
    required Future<void> onClosed,
  }) async {
    if (service == this.service) {
      // Service already opened.
      return;
    }
    this.service = service;
    if (_serviceAvailable.isCompleted) {
      _serviceAvailable = Completer();
    }

    connectedApp = ConnectedApp(this);

    // It is critical we call vmServiceOpened on each manager class before
    // performing any async operations. Otherwise, we may get end up with
    // race conditions where managers cannot listen for events soon enough.
    isolateManager.vmServiceOpened(service);
    serviceExtensionManager.vmServiceOpened(service, connectedApp!);

    await callLifecycleCallbacks(
      ServiceManagerLifecycle.beforeOpenVmService,
      service,
    );
    await _openVmServiceConnection(service, onClosed: onClosed);
    await callLifecycleCallbacks(
      ServiceManagerLifecycle.afterOpenVmService,
      service,
    );

    await connectedApp!.initializeValues();

    // This needs to be the last call in this method.
    _connectedState.value = const ConnectedState(true);
  }

  /// Shuts down the service manager's current vm service connection.
  FutureOr<void> vmServiceClosed({
    ConnectedState connectionState = const ConnectedState(false),
  }) async {
    await callLifecycleCallbacks(
      ServiceManagerLifecycle.beforeCloseVmService,
      this.service,
    );
    _closeVmServiceConnection();
    await callLifecycleCallbacks(
      ServiceManagerLifecycle.afterCloseVmService,
      this.service,
    );

    serviceExtensionManager.vmServiceClosed();
    isolateManager.handleVmServiceClosed();
    _registeredMethodsForService.clear();
    _registeredServiceNotifiers.clear();
    setDeviceBusy(false);

    _connectedState.value = connectionState;
  }

  /// Initializes the service manager for [service], including setting up other
  /// managers, initializing stream listeners, and setting up connection state.
  Future<void> _openVmServiceConnection(
    T service, {
    required Future<void> onClosed,
  }) async {
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
      _log.fine('ServiceEvent: [${e.kind}] - ${e.service}');
      if (e.kind == EventKind.kServiceRegistered) {
        final serviceName = e.service!;
        _registeredMethodsForService[serviceName] = e.method!;
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
      } catch (e, st) {
        if (id.endsWith('Logging')) {
          // Don't complain about '_Logging' or 'Logging' events (new VMs don't
          // have the private names, and older ones don't have the public ones).
        } else {
          _log.shout("Service client stream not supported: '$id'\n  $e", e, st);
        }
      }
    }
    if (service != this.service) {
      // A different service has been opened.
      return;
    }

    final override = _overrides[ServiceManagerOverride.initIsolates];
    if (override != null) {
      await override.call(service);
    } else {
      await isolateManager.init(vm?.isolates ?? <IsolateRef>[]);
    }
  }

  void _closeVmServiceConnection() {
    _serviceAvailable = Completer();
    service = null;
    vm = null;
    sdkVersion = null;
    connectedApp = null;
  }

  Future<void> manuallyDisconnect() async {
    await vmServiceClosed(
      connectionState:
          const ConnectedState(false, userInitiatedConnectionState: true),
    );
  }

  Future<Response> callServiceOnMainIsolate(String name) async {
    final isolate = await whenValueNonNull(isolateManager.mainIsolate);
    return await callService(name, isolateId: isolate?.id);
  }

  Future<Response> callServiceExtensionOnMainIsolate(
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

  bool libraryUriAvailableNow(String? uri) {
    if (uri == null) return false;
    assert(isServiceAvailable);
    assert(isolateManager.mainIsolate.value != null);
    final isolate = isolateManager.mainIsolateState?.isolateNow;
    return (isolate?.libraries ?? [])
        .map((ref) => ref.uri)
        .toList()
        .any((u) => u?.startsWith(uri) == true);
  }

  Future<bool> libraryUriAvailable(String uri) async {
    assert(isServiceAvailable);
    await whenValueNonNull(isolateManager.mainIsolate);
    return libraryUriAvailableNow(uri);
  }

  Future<Response> get flutterVersion async {
    return await callServiceOnMainIsolate(
      flutterVersionService.service,
    );
  }

  /// This can throw an [RPCError].
  Future<void> performHotReload() async {
    if (connectedApp?.isFlutterAppNow ?? false) {
      await callServiceOnMainIsolate(hotReloadServiceName);
    } else {
      final serviceLocal = service;
      await serviceLocal?.forEachIsolate((isolate) async {
        await serviceLocal.reloadSources(isolate.id!);
      });
    }
  }

  /// This can throw an [RPCError].
  Future<void> performHotRestart() async {
    await callServiceOnMainIsolate(hotRestartServiceName);
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

  @override
  bool operator ==(Object? other) {
    return other is ConnectedState &&
        other.connected == connected &&
        other.userInitiatedConnectionState == userInitiatedConnectionState;
  }

  @override
  int get hashCode => Object.hash(connected, userInitiatedConnectionState);

  @override
  String toString() =>
      'ConnectedState(connected: $connected, userInitiated: $userInitiatedConnectionState)';
}
