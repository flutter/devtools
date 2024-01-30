// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import '../utils/auto_dispose.dart';
import 'connected_app.dart';
import 'isolate_manager.dart';
import 'service_extensions.dart' as extensions;
import 'service_utils.dart';

final _log = Logger('service_extension_manager');

/// Manager that handles tracking the service extension for the main isolate.
final class ServiceExtensionManager with DisposerMixin {
  ServiceExtensionManager(this._isolateManager);

  VmService? _service;

  bool _checkForFirstFrameStarted = false;

  final IsolateManager _isolateManager;

  Completer<void> _firstFrameReceived = Completer();

  bool get _firstFrameEventReceived => _firstFrameReceived.isCompleted;

  final _serviceExtensionAvailable = <String, ValueNotifier<bool>>{};

  final _serviceExtensionStates =
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

  ConnectedApp get connectedApp => _connectedApp!;
  ConnectedApp? _connectedApp;

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
        final name = event.json!['extensionData']['extension'].toString();
        final encodedValue = event.json!['extensionData']['value'].toString();
        await _updateServiceExtensionForStateChange(name, encodedValue);
        break;
      case 'HttpTimelineLoggingStateChange':
        final name = extensions.httpEnableTimelineLogging.extension;
        final encodedValue = event.json!['extensionData']['enabled'].toString();
        await _updateServiceExtensionForStateChange(name, encodedValue);
        break;
      case 'SocketProfilingStateChange':
        final name = extensions.socketProfiling.extension;
        final encodedValue = event.json!['extensionData']['enabled'].toString();
        await _updateServiceExtensionForStateChange(name, encodedValue);
    }
  }

  Future<void> _handleDebugEvent(Event event) async {
    if (event.kind == EventKind.kResume) {
      final isolateRef = event.isolate!;
      final callbacks = _callbacksOnIsolateResume[isolateRef] ?? [];
      _callbacksOnIsolateResume = {};
      for (final callback in callbacks) {
        try {
          await callback();
        } catch (e, st) {
          _log.shout('Error running isolate callback: $e', e, st);
        }
      }
    }
  }

  Future<void> _updateServiceExtensionForStateChange(
    String name,
    String encodedValue,
  ) async {
    final ext = extensions.serviceExtensionsAllowlist[name];
    if (ext != null) {
      final extensionValue = _getExtensionValue(name, encodedValue);
      final enabled = ext is extensions.ToggleableServiceExtension
          ? extensionValue == ext.enabledValue
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

  Object? _getExtensionValue(String name, String encodedValue) {
    final expectedValueType =
        extensions.serviceExtensionsAllowlist[name]!.values.first.runtimeType;
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
        _addServiceExtension(extension),
    ]);
  }

  Future<void> _onMainIsolateChanged() async {
    if (_isolateManager.mainIsolate.value == null) {
      _mainIsolateClosed();
      return;
    }
    _checkForFirstFrameStarted = false;

    final isolateRef = _isolateManager.mainIsolate.value!;
    final Isolate? isolate =
        await _isolateManager.isolateState(isolateRef).isolate;

    if (isolate == null) return;

    await _registerMainIsolate(isolate, isolateRef);
  }

  Future<void> _registerMainIsolate(
    Isolate mainIsolate,
    IsolateRef? expectedMainIsolateRef,
  ) async {
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
          for (String extension in mainIsolate.extensionRPCs!)
            _maybeAddServiceExtension(extension),
        ]);
      } else {
        await Future.wait([
          for (String extension in mainIsolate.extensionRPCs!)
            _addServiceExtension(extension),
        ]);
      }
    }
  }

  Future<void> _maybeCheckForFirstFlutterFrame() async {
    final IsolateRef? lastMainIsolate = _isolateManager.mainIsolate.value;
    if (_checkForFirstFrameStarted ||
        _firstFrameEventReceived ||
        lastMainIsolate == null) return;
    if (!isServiceExtensionAvailable(extensions.didSendFirstFrameEvent)) {
      return;
    }
    _checkForFirstFrameStarted = true;

    final value = await _service!.callServiceExtension(
      extensions.didSendFirstFrameEvent,
      isolateId: lastMainIsolate.id,
    );
    if (lastMainIsolate != _isolateManager.mainIsolate.value) {
      // The active isolate has changed since we started querying the first
      // frame.
      return;
    }
    final didSendFirstFrameEvent = value.json!['enabled'] == 'true';

    if (didSendFirstFrameEvent) {
      await _onFrameEventReceived();
    }
  }

  Future<void> _maybeAddServiceExtension(String? name) async {
    if (name == null) return;
    if (_firstFrameEventReceived ||
        !extensions.isUnsafeBeforeFirstFlutterFrame(name)) {
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
      try {
        return await _callServiceExtension(
          name,
          _enabledServiceExtensions[name]!.value,
        );
      } on SentinelException catch (_) {
        // Service extension stopped existing while calling, so do nothing.
        // This typically happens during hot restarts.
      }
    } else {
      // Set any extensions that are already enabled on the device. This will
      // enable extension states in DevTools on page refresh or initial start.
      return await _restoreExtensionFromDevice(name);
    }
  }

  IsolateRef? get _mainIsolate => _isolateManager.mainIsolate.value;

  Future<void> _restoreExtensionFromDevice(String name) async {
    final isolateRef = _isolateManager.mainIsolate.value;
    if (isolateRef == null) return;

    if (!extensions.serviceExtensionsAllowlist.containsKey(name)) {
      return;
    }
    final expectedValueType =
        extensions.serviceExtensionsAllowlist[name]!.values.first.runtimeType;

    Future<void> restore() async {
      // The restore request is obsolete if the isolate has changed.
      if (isolateRef != _mainIsolate) return;
      try {
        final response = await _service!.callServiceExtension(
          name,
          isolateId: isolateRef.id,
        );

        if (isolateRef != _mainIsolate) return;

        switch (expectedValueType) {
          case bool:
            final bool enabled =
                response.json!['enabled'] == 'true' ? true : false;
            await _maybeRestoreExtension(name, enabled);
            return;
          case String:
            final String? value = response.json!['value'];
            await _maybeRestoreExtension(name, value);
            return;
          case int:
          case double:
            final num value = num.parse(
              response.json![name.substring(name.lastIndexOf('.') + 1)],
            );
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

    if (isolateRef != _mainIsolate) return;

    final Isolate? isolate =
        await _isolateManager.isolateState(isolateRef).isolate;
    if (isolateRef != _mainIsolate) return;

    // Do not try to restore Dart IO extensions for a paused isolate.
    if (extensions.isDartIoExtension(name) &&
        isolate?.pauseEvent?.kind?.contains('Pause') == true) {
      _callbacksOnIsolateResume.putIfAbsent(isolateRef, () => []).add(restore);
    } else {
      await restore();
    }
  }

  Future<void> _maybeRestoreExtension(String name, Object? value) async {
    final extensionDescription = extensions.serviceExtensionsAllowlist[name];
    if (extensionDescription is extensions.ToggleableServiceExtension) {
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

  Future<void> _callServiceExtension(String name, Object? value) async {
    if (_service == null) {
      return;
    }

    final mainIsolate = _isolateManager.mainIsolate.value;
    Future<void> callExtension() async {
      if (_isolateManager.mainIsolate.value != mainIsolate) return;

      assert(value != null);
      if (value is bool) {
        Future<void> call(String? isolateId, bool value) async {
          await _service!.callServiceExtension(
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
          await _service!.forEachIsolate((isolate) async {
            await call(isolate.id, value);
          });
        } else {
          await call(mainIsolate?.id, value);
        }
      } else if (value is String) {
        await _service!.callServiceExtension(
          name,
          isolateId: mainIsolate?.id,
          args: {'value': value},
        );
      } else if (value is double) {
        await _service!.callServiceExtension(
          name,
          isolateId: mainIsolate?.id!,
          // The param name for a numeric service extension will be the last part
          // of the extension name (ext.flutter.extensionName => extensionName).
          args: {name.substring(name.lastIndexOf('.') + 1): value},
        );
      }
    }

    if (mainIsolate == null) return;
    final Isolate? isolate =
        await _isolateManager.isolateState(mainIsolate).isolate;
    if (_isolateManager.mainIsolate.value != mainIsolate) return;

    // Do not try to call Dart IO extensions for a paused isolate.
    if (extensions.isDartIoExtension(name) &&
        isolate?.pauseEvent?.kind?.contains('Pause') == true) {
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

    _enabledServiceExtensions.clear();
    _callbacksOnIsolateResume.clear();
    _connectedApp = null;
  }

  void _mainIsolateClosed() {
    _firstFrameReceived = Completer();
    _checkForFirstFrameStarted = false;
    _pendingServiceExtensions.clear();
    _serviceExtensions.clear();

    // If the isolate has closed, there is no need to wait any longer for
    // service extensions that might be registered.
    _performActionAndClearMap<Completer<bool>>(
      _maybeRegisteringServiceExtensions,
      action: (completer) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    _performActionAndClearMap<ValueNotifier<bool>>(
      _serviceExtensionAvailable,
      action: (listenable) => listenable.value = false,
    );

    _performActionAndClearMap(
      _serviceExtensionStates,
      action: (state) => state.value = ServiceExtensionState(
        enabled: false,
        value: null,
      ),
    );
  }

  /// Performs [action] over the values in [map], and then clears the [map] once
  /// finished.
  void _performActionAndClearMap<T>(
    Map<Object, T> map, {
    required void Function(T) action,
  }) {
    map
      ..values.forEach(action)
      ..clear();
  }

  /// Sets the state for a service extension and makes the call to the VMService.
  Future<void> setServiceExtensionState(
    String name, {
    required bool enabled,
    required Object? value,
    bool callExtension = true,
  }) async {
    if (callExtension && _serviceExtensions.contains(name)) {
      await _callServiceExtension(name, value);
    } else if (callExtension) {
      _log.info(
        'Attempted to call extension \'$name\', but no service with that name exists',
      );
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
      late VoidCallback listener;
      listener = () {
        if (listenable.value || !completer.isCompleted) {
          listenable.removeListener(listener);
          completer.complete(true);
        }
      };
      hasServiceExtension(name).addListener(listener);
      return completer;
    }

    _maybeRegisteringServiceExtensions[name] ??= createCompleter();
    return _maybeRegisteringServiceExtensions[name]!.future;
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
    return _serviceExtensionStates.putIfAbsent(
      name,
      () {
        return ValueNotifier<ServiceExtensionState>(
          _enabledServiceExtensions.containsKey(name)
              ? _enabledServiceExtensions[name]!
              : ServiceExtensionState(enabled: false, value: null),
        );
      },
    );
  }

  void vmServiceOpened(
    VmService service,
    ConnectedApp connectedApp,
  ) async {
    _checkForFirstFrameStarted = false;
    cancelStreamSubscriptions();
    cancelListeners();
    _connectedApp = connectedApp;
    _service = service;
    // TODO(kenz): do we want to listen with event history here?
    autoDisposeStreamSubscription(
      service.onExtensionEvent.listen(_handleExtensionEvent),
    );
    addAutoDisposeListener(
      hasServiceExtension(extensions.didSendFirstFrameEvent),
      _maybeCheckForFirstFlutterFrame,
    );
    addAutoDisposeListener(_isolateManager.mainIsolate, _onMainIsolateChanged);
    autoDisposeStreamSubscription(
      service.onDebugEvent.listen(_handleDebugEvent),
    );
    autoDisposeStreamSubscription(
      service.onIsolateEvent.listen(_handleIsolateEvent),
    );
    final mainIsolateRef = _isolateManager.mainIsolate.value;
    if (mainIsolateRef != null) {
      _checkForFirstFrameStarted = false;
      final mainIsolate =
          await _isolateManager.isolateState(mainIsolateRef).isolate;
      if (mainIsolate != null) {
        await _registerMainIsolate(mainIsolate, mainIsolateRef);
      }
    }
  }
}

class ServiceExtensionState {
  ServiceExtensionState({required this.enabled, required this.value}) {
    if (value is bool) {
      assert(enabled == value);
    }
  }

  // For boolean service extensions, [enabled] should equal [value].
  final bool enabled;
  final Object? value;

  @override
  bool operator ==(Object other) {
    return other is ServiceExtensionState &&
        enabled == other.enabled &&
        value == other.value;
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        value,
      );

  @override
  String toString() {
    return 'ServiceExtensionState(enabled: $enabled, value: $value)';
  }
}

@visibleForTesting
base mixin TestServiceExtensionManager implements ServiceExtensionManager {}
