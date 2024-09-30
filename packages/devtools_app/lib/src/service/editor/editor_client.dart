// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:dtd/dtd.dart';

import '../../shared/analytics/constants.dart';
import 'api_classes.dart';

/// An interface to services provided by an editor.
///
/// Changes made to the editor services/events should be considered carefully to
/// ensure they are not breaking changes to already-shipped editors.
abstract class EditorClient extends DisposableController {
  Future<void> close();

  /// The ID to use for analytics events.
  String get gaId;

  /// Whether the connected editor supports the `getDevices` method.
  bool get supportsGetDevices;

  /// Whether the connected editor supports the `getDebugSessions` method.
  bool get supportsGetDebugSessions;

  /// Whether the connected editor supports the `selectDevice` method.
  bool get supportsSelectDevice;

  /// Whether the connected editor supports the `hotReload` method.
  bool get supportsHotReload;

  /// Whether the connected editor supports the `hotRestart` method.
  bool get supportsHotRestart;

  /// Whether the connected editor supports the `openDevToolsPage` method.
  bool get supportsOpenDevToolsPage;

  /// Whether the connected editor supports the `forceExternal` flag in the
  /// params for `openDevToolsPage`.
  bool get supportsOpenDevToolsForceExternal;

  /// A stream of [EditorEvent]s from the editor.
  Stream<EditorEvent> get event;

  /// A stream of events of when editor service methods/capabilities change.
  Stream<ServiceRegistrationChange> get editorServiceChanged;

  /// Gets the set of currently available devices from the editor.
  Future<GetDevicesResult> getDevices();

  /// Gets the set of currently active debug sessions from the editor.
  Future<GetDebugSessionsResult> getDebugSessions();

  /// Requests the editor selects a specific device.
  ///
  /// It should not be assumed that calling this method succeeds (if it does, a
  /// `deviceSelected` event will provide the appropriate update).
  Future<void> selectDevice(EditorDevice? device);

  /// Requests the editor Hot Reloads the given debug session.
  Future<void> hotReload(String debugSessionId);

  /// Requests the editor Hot Restarts the given debug session.
  Future<void> hotRestart(String debugSessionId);

  /// Requests the editor opens a DevTools page for the given debug session.
  Future<void> openDevToolsPage(
    String? debugSessionId, {
    String? page,
    bool? forceExternal,
    bool? requiresDebugSession,
    bool? prefersDebugSession,
  });

  /// Requests the editor enables a new platform (for example by running
  /// `flutter create` to add the native project files).
  ///
  /// This action may prompt the user so it should not be assumed that calling
  /// this method succeeds (if it does, a `deviceChanged` event will provide
  /// the appropriate updates).
  Future<void> enablePlatformType(String platformType);
}

/// An implementation of [EditorClient] that connects to an editor over DTD.
///
/// Changes made to the editor services/events should be considered carefully to
/// ensure they are not breaking changes to already-shipped editors.
class DtdEditorClient extends EditorClient with AutoDisposeControllerMixin {
  // TODO(dantup): Merge this into EditorClient once the postMessage version
  //  is removed.

  DtdEditorClient(this._dtd) {
    unawaited(initialized); // Trigger async initialization.
  }

  final DartToolingDaemon _dtd;
  late final initialized = _initialize();

  @override
  String get gaId => EditorSidebar.id;

  Future<void> _initialize() async {
    autoDisposeStreamSubscription(
      _dtd.onEvent('Service').listen((data) {
        final kind = data.kind;
        if (kind != 'ServiceRegistered' && kind != 'ServiceUnregistered') {
          return;
        }

        final service = data.data['service'] as String?;
        if (service == null || service != editorServiceName) {
          return;
        }

        final isRegistered = kind == 'ServiceRegistered';
        final method = data.data['method'] as String;
        final capabilities = data.data['capabilities'] as Map<String, Object?>?;

        if (method == EditorMethod.getDevices.name) {
          _supportsGetDevices = isRegistered;
        } else if (method == EditorMethod.getDebugSessions.name) {
          _supportsGetDebugSessions = isRegistered;
        } else if (method == EditorMethod.selectDevice.name) {
          _supportsSelectDevice = isRegistered;
        } else if (method == EditorMethod.hotReload.name) {
          _supportsHotReload = isRegistered;
        } else if (method == EditorMethod.hotRestart.name) {
          _supportsHotRestart = isRegistered;
        } else if (method == EditorMethod.openDevToolsPage.name) {
          _supportsOpenDevToolsPage = isRegistered;
          _supportsOpenDevToolsForceExternal =
              capabilities?[Field.supportsForceExternal] == true;
        } else {
          return;
        }

        final info = isRegistered
            ? ServiceRegistered(
                service: service,
                method: method,
                capabilities: capabilities,
              )
            : ServiceUnregistered(
                service: service,
                method: method,
              );
        _editorServiceChangedController.add(info);
      }),
    );

    final editorKindMap = EditorEventKind.values.asNameMap();
    autoDisposeStreamSubscription(
      _dtd.onEvent(editorStreamName).listen((data) {
        final kind = editorKindMap[data.kind];

        // Unable to do this from IJ
        final event = switch (kind) {
          // Unknown event. Use null here so we get exhaustiveness checking for
          // the rest.
          null => null,
          EditorEventKind.deviceAdded => DeviceAddedEvent.fromJson(data.data),
          EditorEventKind.deviceRemoved =>
            DeviceRemovedEvent.fromJson(data.data),
          EditorEventKind.deviceChanged =>
            DeviceChangedEvent.fromJson(data.data),
          EditorEventKind.deviceSelected =>
            DeviceSelectedEvent.fromJson(data.data),
          EditorEventKind.debugSessionStarted =>
            DebugSessionStartedEvent.fromJson(data.data),
          EditorEventKind.debugSessionChanged =>
            DebugSessionChangedEvent.fromJson(data.data),
          EditorEventKind.debugSessionStopped =>
            DebugSessionStoppedEvent.fromJson(data.data),
          EditorEventKind.themeChanged => ThemeChangedEvent.fromJson(data.data),
        };
        if (event != null) {
          _eventController.add(event);
        }
      }),
    );
    await Future.wait([
      _dtd.streamListen('Service'),
      _dtd.streamListen(editorServiceName),
    ]);
  }

  /// Close the connection to DTD.
  @override
  Future<void> close() => _dtd.close();

  @override
  bool get supportsGetDevices => _supportsGetDevices;
  var _supportsGetDevices = false;

  @override
  bool get supportsGetDebugSessions => _supportsGetDebugSessions;
  var _supportsGetDebugSessions = false;

  @override
  bool get supportsSelectDevice => _supportsSelectDevice;
  var _supportsSelectDevice = false;

  @override
  bool get supportsHotReload => _supportsHotReload;
  var _supportsHotReload = false;

  @override
  bool get supportsHotRestart => _supportsHotRestart;
  var _supportsHotRestart = false;

  @override
  bool get supportsOpenDevToolsPage => _supportsOpenDevToolsPage;
  var _supportsOpenDevToolsPage = false;

  @override
  bool get supportsOpenDevToolsForceExternal =>
      _supportsOpenDevToolsForceExternal;
  var _supportsOpenDevToolsForceExternal = false;

  /// A stream of [EditorEvent]s from the editor.
  @override
  Stream<EditorEvent> get event => _eventController.stream;
  final _eventController = StreamController<EditorEvent>();

  /// A stream of events of when editor services are registrered or
  /// unregistered.
  @override
  Stream<ServiceRegistrationChange> get editorServiceChanged =>
      _editorServiceChangedController.stream;
  final _editorServiceChangedController =
      StreamController<ServiceRegistrationChange>();

  @override
  Future<GetDevicesResult> getDevices() async {
    final response = await _call(EditorMethod.getDevices);
    return GetDevicesResult.fromJson(response.result);
  }

  /// Gets the set of currently active debug sessions from the editor.
  @override
  Future<GetDebugSessionsResult> getDebugSessions() async {
    final response = await _call(EditorMethod.getDebugSessions);
    return GetDebugSessionsResult.fromJson(response.result);
  }

  /// Requests the editor selects a specific device.
  ///
  /// It should not be assumed that calling this method succeeds (if it does, a
  /// `deviceSelected` event will provide the appropriate update).
  @override
  Future<void> selectDevice(EditorDevice? device) async {
    await _call(
      EditorMethod.selectDevice,
      params: {Field.deviceId: device?.id},
    );
  }

  @override
  Future<void> hotReload(String debugSessionId) async {
    await _call(
      EditorMethod.hotReload,
      params: {Field.debugSessionId: debugSessionId},
    );
  }

  @override
  Future<void> hotRestart(String debugSessionId) async {
    await _call(
      EditorMethod.hotRestart,
      params: {Field.debugSessionId: debugSessionId},
    );
  }

  @override
  Future<void> openDevToolsPage(
    String? debugSessionId, {
    String? page,
    bool? forceExternal,
    bool? requiresDebugSession,
    bool? prefersDebugSession,
  }) async {
    await _call(
      EditorMethod.openDevToolsPage,
      params: {
        Field.debugSessionId: debugSessionId,
        Field.page: page,
        Field.forceExternal: forceExternal,
        Field.requiresDebugSession: requiresDebugSession,
        Field.prefersDebugSession: prefersDebugSession,
      },
    );
  }

  @override
  Future<void> enablePlatformType(String platformType) async {
    await _call(
      EditorMethod.enablePlatformType,
      params: {Field.platformType: platformType},
    );
  }

  Future<DTDResponse> _call(
    EditorMethod method, {
    Map<String, Object?>? params,
  }) {
    return _dtd.call(
      editorServiceName,
      method.name,
      params: params,
    );
  }
}

/// Represents a service method that was registered or unregistered.
///
/// See [ServiceRegistered] for registration information.
/// See [ServiceUnregistered] for unregistration information.
sealed class ServiceRegistrationChange {
  ServiceRegistrationChange({required this.service, required this.method});

  final String service;
  final String method;
}

/// Represents a service method that was registered.
class ServiceRegistered extends ServiceRegistrationChange {
  ServiceRegistered({
    required super.service,
    required super.method,
    required this.capabilities,
  });

  final Map<String, Object?>? capabilities;
}

/// Represents a service method that was unregistered.
class ServiceUnregistered extends ServiceRegistrationChange {
  ServiceUnregistered({
    required super.service,
    required super.method,
  });
}
