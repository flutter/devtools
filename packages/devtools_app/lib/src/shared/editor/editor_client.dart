// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/foundation.dart';
import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:logging/logging.dart';

import '../analytics/constants.dart';
import 'api_classes.dart';

final _log = Logger('editor_client');

/// A client wrapper that connects to an editor over DTD.
///
/// Changes made to the editor services/events should be considered carefully to
/// ensure they are not breaking changes to already-shipped editors.
class EditorClient extends DisposableController
    with AutoDisposeControllerMixin {
  EditorClient(this._dtd) {
    unawaited(initialized); // Trigger async initialization.
  }

  final DartToolingDaemon _dtd;
  late final initialized = _initialize();

  String get gaId => EditorSidebar.id;

  Future<void> _initialize() async {
    autoDisposeStreamSubscription(
      _dtd.onEvent('Service').listen((data) {
        final kind = data.kind;
        if (kind != 'ServiceRegistered' && kind != 'ServiceUnregistered') {
          return;
        }

        final service = data.data['service'] as String?;
        if (service == null ||
            (service != editorServiceName && service != lspServiceName)) {
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
          // TODO(https://github.com/flutter/devtools/issues/8804): Switch support
          // to non-experimental LSP methods.
        } else if (method == LspMethod.editArgument.experimentalMethodName) {
          _editArgumentMethodName.value =
              LspMethod.editArgument.experimentalMethodName;
        } else if (method ==
            LspMethod.editableArguments.experimentalMethodName) {
          _editableArgumentsMethodName.value =
              LspMethod.editableArguments.experimentalMethodName;
        } else {
          return;
        }

        final info =
            isRegistered
                ? ServiceRegistered(
                  service: service,
                  method: method,
                  capabilities: capabilities,
                )
                : ServiceUnregistered(service: service, method: method);
        _editorServiceChangedController.add(info);
      }),
    );

    final editorKindMap = EditorEventKind.values.asNameMap();
    autoDisposeStreamSubscription(
      _dtd.onEvent(editorStreamName).listen((data) {
        final kind = editorKindMap[data.kind];
        final event = switch (kind) {
          // Unknown event. Use null here so we get exhaustiveness checking for
          // the rest.
          null => null,
          EditorEventKind.deviceAdded => DeviceAddedEvent.fromJson(data.data),
          EditorEventKind.deviceRemoved => DeviceRemovedEvent.fromJson(
            data.data,
          ),
          EditorEventKind.deviceChanged => DeviceChangedEvent.fromJson(
            data.data,
          ),
          EditorEventKind.deviceSelected => DeviceSelectedEvent.fromJson(
            data.data,
          ),
          EditorEventKind.debugSessionStarted =>
            DebugSessionStartedEvent.fromJson(data.data),
          EditorEventKind.debugSessionChanged =>
            DebugSessionChangedEvent.fromJson(data.data),
          EditorEventKind.debugSessionStopped =>
            DebugSessionStoppedEvent.fromJson(data.data),
          EditorEventKind.themeChanged => ThemeChangedEvent.fromJson(data.data),
          EditorEventKind.activeLocationChanged =>
            ActiveLocationChangedEvent.fromJson(data.data),
        };
        // Add [ActiveLocationChangedEvent]s to a new stream to be ingested by
        // the property editor.
        if (event?.kind == EditorEventKind.activeLocationChanged) {
          _activeLocationChangedController.add(
            event as ActiveLocationChangedEvent,
          );
        }
        if (event != null) {
          _eventController.add(event);
        }
      }),
    );
    await [
      _dtd.streamListen('Service'),
      _dtd.streamListen(editorStreamName).catchError((_) {
        // Because we currently call streamListen in two places (here and
        // ThemeManager) this can fail. It doesn't matter if this happens,
        // however we should refactor this code to better support using the DTD
        // connection in multiple places without them having to coordinate.
      }),
    ].wait;
  }

  /// Close the connection to DTD.
  Future<void> close() => _dtd.close();

  bool get supportsGetDevices => _supportsGetDevices;
  var _supportsGetDevices = false;

  bool get supportsGetDebugSessions => _supportsGetDebugSessions;
  var _supportsGetDebugSessions = false;

  bool get supportsSelectDevice => _supportsSelectDevice;
  var _supportsSelectDevice = false;

  bool get supportsHotReload => _supportsHotReload;
  var _supportsHotReload = false;

  bool get supportsHotRestart => _supportsHotRestart;
  var _supportsHotRestart = false;

  bool get supportsOpenDevToolsPage => _supportsOpenDevToolsPage;
  var _supportsOpenDevToolsPage = false;

  bool get supportsOpenDevToolsForceExternal =>
      _supportsOpenDevToolsForceExternal;
  var _supportsOpenDevToolsForceExternal = false;

  ValueListenable<String?> get editArgumentMethodName =>
      _editArgumentMethodName;
  final _editArgumentMethodName = ValueNotifier<String?>(null);

  ValueListenable<String?> get editableArgumentsMethodName =>
      _editableArgumentsMethodName;
  final _editableArgumentsMethodName = ValueNotifier<String?>(null);

  /// A stream of [ActiveLocationChangedEvent]s from the edtior.
  Stream<ActiveLocationChangedEvent> get activeLocationChangedStream =>
      _activeLocationChangedController.stream;
  final _activeLocationChangedController =
      StreamController<ActiveLocationChangedEvent>();

  /// A stream of [EditorEvent]s from the editor.
  Stream<EditorEvent> get event => _eventController.stream;
  final _eventController = StreamController<EditorEvent>();

  /// A stream of events of when editor services are registrered or
  /// unregistered.
  Stream<ServiceRegistrationChange> get editorServiceChanged =>
      _editorServiceChangedController.stream;
  final _editorServiceChangedController =
      StreamController<ServiceRegistrationChange>();

  Future<GetDevicesResult> getDevices() async {
    final response = await _call(EditorMethod.getDevices);
    return GetDevicesResult.fromJson(response.result);
  }

  /// Gets the set of currently active debug sessions from the editor.
  Future<GetDebugSessionsResult> getDebugSessions() async {
    final response = await _call(EditorMethod.getDebugSessions);
    return GetDebugSessionsResult.fromJson(response.result);
  }

  /// Requests the editor selects a specific device.
  ///
  /// It should not be assumed that calling this method succeeds (if it does, a
  /// `deviceSelected` event will provide the appropriate update).
  Future<void> selectDevice(EditorDevice? device) async {
    await _call(
      EditorMethod.selectDevice,
      params: {Field.deviceId: device?.id},
    );
  }

  Future<void> hotReload(String debugSessionId) async {
    await _call(
      EditorMethod.hotReload,
      params: {Field.debugSessionId: debugSessionId},
    );
  }

  Future<void> hotRestart(String debugSessionId) async {
    await _call(
      EditorMethod.hotRestart,
      params: {Field.debugSessionId: debugSessionId},
    );
  }

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

  Future<void> enablePlatformType(String platformType) async {
    await _call(
      EditorMethod.enablePlatformType,
      params: {Field.platformType: platformType},
    );
  }

  /// Gets the editable arguments from the Analysis Server.
  Future<EditableArgumentsResult?> getEditableArguments({
    required TextDocument textDocument,
    required CursorPosition position,
  }) async {
    final method = editableArgumentsMethodName.value;
    if (method == null) return null;
    final response = await _callLspApi(
      method,
      params: {
        'type': 'Object', // This is required by DTD.
        'textDocument': textDocument.toJson(),
        'position': position.toJson(),
      },
    );
    final result = response.result[Field.result];
    return result != null
        ? EditableArgumentsResult.fromJson(result as Map<String, Object?>)
        : null;
  }

  /// Requests that the Analysis Server makes a code edit for an argument.
  Future<EditArgumentResponse> editArgument<T>({
    required TextDocument textDocument,
    required CursorPosition position,
    required String name,
    required T value,
  }) async {
    final method = editArgumentMethodName.value;
    if (method == null) {
      return EditArgumentResponse(
        success: false,
        errorMessage: 'API is unavailable.',
      );
    }
    try {
      await _callLspApi(
        method,
        params: {
          'type': 'Object', // This is required by DTD.
          'textDocument': textDocument.toJson(),
          'position': position.toJson(),
          'edit': {'name': name, 'newValue': value},
        },
      );
      return EditArgumentResponse(success: true);
    } on RpcException catch (e) {
      final errorMessage = e.message;
      _log.severe(errorMessage);
      return EditArgumentResponse(
        success: false,
        errorCode: e.code,
        errorMessage: errorMessage,
      );
    } catch (e) {
      final errorMessage = 'Unknown error: $e';
      _log.severe(errorMessage);
      return EditArgumentResponse(
        success: false,
        errorMessage: 'Unknown error: $e',
      );
    }
  }

  Future<DTDResponse> _call(
    EditorMethod method, {
    Map<String, Object?>? params,
  }) {
    return _dtd.call(editorServiceName, method.name, params: params);
  }

  Future<DTDResponse> _callLspApi(
    String methodName, {
    Map<String, Object?>? params,
  }) {
    return _dtd.call(lspServiceName, methodName, params: params);
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
  ServiceUnregistered({required super.service, required super.method});
}
