// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import '../../service.dart';
import '../../service_extensions.dart';
import '../../utils.dart';

final _log = Logger('service_manager');

// TODO(kenz): add an offline service manager implementation.
// TODO(jacobr): refactor all of these apis to be in terms of ValueListenable
// instead of Streams.
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

  bool get hasService => service != null;

  bool get hasConnection => hasService && connectedApp != null;

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
    final listenable = _registeredServiceNotifiers.putIfAbsent(
      name,
      () => ImmediateValueNotifier(false),
    );
    return listenable;
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

    await beforeOpenVmService(service);
    await _openVmServiceConnection(service, onClosed: onClosed);
    await afterOpenVmService();

    // This needs to be the last call in this method.
    _connectedState.value = const ConnectedState(true);
  }

  /// Shuts down the service manager's current vm service connection.
  void vmServiceClosed({
    ConnectedState connectionState = const ConnectedState(false),
  }) {
    beforeCloseVmService();
    _closeVmServiceConnection();
    afterCloseVmService();

    _connectedState.value = connectionState;
  }

  /// Callback that is called before the service manager is set up for the
  /// connection to [service].
  ///
  /// If this method is overridden by a subclass, super must be called and it
  /// should be called as the first line in the override.
  @mustCallSuper
  FutureOr<void> beforeOpenVmService(T service) {
    // It is critical we call vmServiceOpened on each manager class before
    // performing any async operations. Otherwise, we may get end up with
    // race conditions where managers cannot listen for events soon enough.
    isolateManager.vmServiceOpened(service);
    serviceExtensionManager.vmServiceOpened(service, connectedApp!);
  }

  /// Callback that is called after the service manager is set up for the
  /// connection to [service].
  ///
  /// If this method is overridden by a subclass, the override should either
  /// call `super.afterInitForVmService()` or manually call this methods content
  /// with any extra logic / parameters needed.
  Future<void> afterOpenVmService() async {
    await connectedApp!.initializeValues();
  }

  /// Callback that is called before the service manager closes the connection
  /// to [service].
  void beforeCloseVmService() {}

  /// Callback that is called after the service manager closes the connection to
  /// [service].
  ///
  /// If this method is overridden by a subclass, super must be called and it
  /// should be called as the last line in the override.
  @mustCallSuper
  void afterCloseVmService() {
    serviceExtensionManager.vmServiceClosed();
    isolateManager.handleVmServiceClosed();
    _registeredMethodsForService.clear();
    setDeviceBusy(false);
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

    await isolateManager.init(isolatesFromVm(vm));
  }

  void _closeVmServiceConnection() {
    _serviceAvailable = Completer();
    service = null;
    vm = null;
    sdkVersion = null;
    connectedApp = null;
  }

  /// Returns the list of isolates for the given [vm].
  ///
  /// This method may be overridden by a subclass to do something like
  /// conditionally including system isolates.
  List<IsolateRef> isolatesFromVm(VM? vm) {
    return vm?.isolates ?? <IsolateRef>[];
  }

  void manuallyDisconnect() {
    vmServiceClosed(
      connectionState:
          const ConnectedState(false, userInitiatedConnectionState: true),
    );
  }

  @protected
  Future<Response> callServiceOnMainIsolate(String name) async {
    final isolate = await whenValueNonNull(isolateManager.mainIsolate);
    return await callService(name, isolateId: isolate?.id);
  }

  @protected
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
    await callServiceOnMainIsolate(hotReloadServiceName);
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
