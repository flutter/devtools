// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dtd/dtd.dart';

import 'api_classes.dart';

/// An interface to services provided by an editor.
///
/// Changes made to the editor services/events should be considered carefully to
/// ensure they are not breaking changes to already-shipped editors.
abstract class EditorClient {
  Future<void> close();
  bool get supportsGetDevices;
  bool get supportsSelectDevice;
  bool get supportsHotReload;
  bool get supportsHotRestart;
  bool get supportsOpenDevToolsPage;
  bool get supportsOpenDevToolsExternally;

  /// A stream of [EditorEvent]s from the editor.
  Stream<EditorEvent> get event;

  /// Gets the set of currently available devices from the editor.
  Future<List<EditorDevice>> getDevices();

  /// Gets the set of currently active debug sessions from the editor.
  Future<List<EditorDebugSession>> getDebugSessions();

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
class DtdEditorClient extends EditorClient {
  // TODO(dantup): Merge this into EditorClient once the postMessage version
  //  is removed.

  DtdEditorClient(this._dtd) {
    unawaited(initialized); // Trigger async initialization.
  }

  final DartToolingDaemon _dtd;
  late final initialized = _initialize();

  Future<void> _initialize() async {
    final editorKindMap = EditorEventKind.values.asNameMap();
    _dtd.onEvent(editorStreamName).listen((data) {
      final kind = editorKindMap[data.kind];
      switch (kind) {
        case null:
          // Unknown event. Use null here so we get exhaustiveness checking for
          // the rest.
          break;
        case EditorEventKind.deviceAdded:
          _eventController.add(DeviceAddedEvent.fromJson(data.data));
        case EditorEventKind.deviceRemoved:
          _eventController.add(DeviceRemovedEvent.fromJson(data.data));
        case EditorEventKind.deviceChanged:
          _eventController.add(DeviceChangedEvent.fromJson(data.data));
        case EditorEventKind.deviceSelected:
          _eventController.add(DeviceSelectedEvent.fromJson(data.data));
        case EditorEventKind.debugSessionStarted:
          _eventController.add(DebugSessionStartedEvent.fromJson(data.data));
        case EditorEventKind.debugSessionChanged:
          _eventController.add(DebugSessionChangedEvent.fromJson(data.data));
        case EditorEventKind.debugSessionStopped:
          _eventController.add(DebugSessionStoppedEvent.fromJson(data.data));
      }
    });

    await _dtd.streamListen(editorServiceName);
  }

  /// Close the connection to DTD.
  @override
  Future<void> close() => _dtd.close();

  // TODO(dantup): Implement these properly using a new DTD API?
  @override
  final supportsGetDevices = true;
  @override
  final supportsSelectDevice = true;
  @override
  final supportsHotReload = true;
  @override
  final supportsHotRestart = true;
  @override
  final supportsOpenDevToolsPage = true;
  @override
  final supportsOpenDevToolsExternally = true;

  /// A stream of [EditorEvent]s from the editor.
  @override
  Stream<EditorEvent> get event => _eventController.stream;
  final _eventController = StreamController<EditorEvent>();

  @override
  Future<List<EditorDevice>> getDevices() async {
    final response = await _call(
      EditorMethod.getDevices,
    );
    return (response.result['devices'] as List)
        .cast<Map<String, Object?>>()
        .map(EditorDevice.fromJson)
        .toList(growable: false);
  }

  /// Gets the set of currently active debug sessions from the editor.
  @override
  Future<List<EditorDebugSession>> getDebugSessions() async {
    final response = await _call(
      EditorMethod.getDebugSessions,
    );
    return (response.result['debugSessions'] as List)
        .cast<Map<String, Object?>>()
        .map(EditorDebugSession.fromJson)
        .toList(growable: false);
  }

  /// Requests the editor selects a specific device.
  ///
  /// It should not be assumed that calling this method succeeds (if it does, a
  /// `deviceSelected` event will provide the appropriate update).
  @override
  Future<void> selectDevice(EditorDevice? device) async {
    await _call(
      EditorMethod.selectDevice,
      params: {'deviceId': device?.id},
    );
  }

  @override
  Future<void> hotReload(String debugSessionId) async {
    await _call(
      EditorMethod.hotReload,
      params: {'debugSessionId': debugSessionId},
    );
  }

  @override
  Future<void> hotRestart(String debugSessionId) async {
    await _call(
      EditorMethod.hotRestart,
      params: {'debugSessionId': debugSessionId},
    );
  }

  @override
  Future<void> openDevToolsPage(
    String? debugSessionId, {
    String? page,
    bool? forceExternal,
  }) async {
    await _call(
      EditorMethod.openDevToolsPage,
      params: {
        'debugSessionId': debugSessionId,
        'page': page,
        'forceExternal': forceExternal,
      },
    );
  }

  @override
  Future<void> enablePlatformType(String platformType) async {
    await _call(
      EditorMethod.enablePlatformType,
      params: {'platformType': platformType},
    );
  }

  Future<DTDResponse> _call(
    EditorMethod method, {
    Map<String, Object?>? params,
  }) {
    return _dtd.call(
      editorServiceName,
      method.name,
      // TODO(dantup): Simplify this to `params: params` if the case method
      //  is updated to accept `Map<String, Object?>?` instead of
      //  `Map<String, Object>?`.
      params: params != null
          ? {
              for (final MapEntry(:key, :value) in params.entries)
                if (value != null) key: value,
            }
          : null,
    );
  }
}
