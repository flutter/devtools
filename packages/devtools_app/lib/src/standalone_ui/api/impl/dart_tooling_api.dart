// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:logging/logging.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../../service/editor/api_classes.dart';
import '../../../service/editor/editor_client.dart';
import '../../../shared/config_specific/logger/logger_helpers.dart';
import '../../../shared/config_specific/post_message/post_message.dart';
import '../../../shared/constants.dart';
import '../dart_tooling_api.dart';
import '../vs_code_api.dart';
import 'vs_code_api.dart';

// TODO(https://github.com/flutter/devtools/issues/7055): migrate away from
// postMessage and use the Dart Tooling Daemon to communicate between Dart
// tooling surfaces.

/// Whether to enable verbose logging for postMessage communication.
///
/// This is useful for debugging when running inside VS Code.
///
/// TODO(dantup): Make a way for this to be enabled by users at runtime for
///  troubleshooting. This could be via a message from VS Code, or something
///  that passes a query param.
const _enablePostMessageVerboseLogging = false;

final _log = Logger('tooling_api');

/// An API used by Dart tooling surfaces to interact with Dart tools that expose
/// APIs such as Dart-Code and the LSP server.
class PostMessageToolApiImpl implements PostMessageToolApi {
  PostMessageToolApiImpl.rpc(this._rpc) {
    unawaited(_rpc.listen());
  }

  /// Connects the API using 'postMessage'. This is only available when running
  /// on web and hosted inside an iframe (such as inside a VS Code webview).
  factory PostMessageToolApiImpl.postMessage() {
    if (_enablePostMessageVerboseLogging) {
      setDevToolsLoggingLevel(verboseLoggingLevel);
    }
    final postMessageController = StreamController<Object?>();
    postMessageController.stream.listen((message) {
      // TODO(dantup): Using fine here doesn't work even though the
      // `setDevToolsLoggingLevel` call above seems like it should show finest
      // logs. For now, use info (which always logs) with a condition here
      // and below.
      if (_enablePostMessageVerboseLogging) {
        _log.info('==> $message');
      }
      postMessage(message, '*');
    });
    final channel = StreamChannel(
      onPostMessage.map((event) {
        if (_enablePostMessageVerboseLogging) {
          _log.info('<== ${jsonEncode(event.data)}');
        }
        return event.data;
      }),
      postMessageController,
    );
    return PostMessageToolApiImpl.rpc(
      json_rpc_2.Peer.withoutJson(channel),
    );
  }

  final json_rpc_2.Peer _rpc;

  /// An API that provides Access to APIs related to VS Code, such as executing
  /// VS Code commands or interacting with the Dart/Flutter extensions.
  ///
  /// Lazy-initialized and completes with `null` if VS Code is not available.
  @override
  late final vsCode = VsCodeApiImpl.tryConnect(_rpc);

  @override
  void dispose() {
    unawaited(_rpc.close());
  }
}

/// A client for interacting with the legacy postMessage API with the same
/// interface as the newer DTD-based [EditorClient].
///
/// This class allows the sidebar to use the new [EditorClient] APIs while still
/// being compatible with postMessage based clients.
class PostMessageEditorClient implements EditorClient {
  PostMessageEditorClient(this._api) {
    // In PostMessage world, we just get events with the entire new list so
    // we must figure out what the actual changes are so we can produce the
    // same kinds of events as the new DTD version.
    _api.devicesChanged.listen(_devicesChanged);
    _api.debugSessionsChanged.listen(_debugSessionsChanged);

    // Trigger the initial initialization now we have the handlers set up.
    // In the old postMessage world, this is how we get the initial set of
    // devices/sessions.
    unawaited(_api.initialize());
  }

  /// Handles the `postMessage` [VsCodeDevicesEvent] and converts the updates
  /// into events in the format of the new DTD `editor` event stream.
  void _devicesChanged(VsCodeDevicesEvent e) {
    final supportedDevices = e.devices.map(
      (d) => EditorDevice.fromJson({...d.toJson(), 'supported': true}),
    );
    final unsupportedDevices = e.unsupportedDevices?.map(
          (d) => EditorDevice.fromJson({...d.toJson(), 'supported': false}),
        ) ??
        <EditorDevice>[];
    final newDevices = supportedDevices.followedBy(unsupportedDevices).toList();
    final newIds = newDevices.map((d) => d.id).toSet();
    final oldIds = _currentDevices.map((d) => d.id).toSet();

    // Devices that are not in the new set have been removed.
    for (final id in oldIds.difference(newIds)) {
      _eventController.add(DeviceRemovedEvent(deviceId: id));
    }
    // Devices in the new set have either been changed or were added.
    for (final device in newDevices) {
      if (oldIds.contains(device.id)) {
        _eventController.add(DeviceChangedEvent(device: device));
      } else {
        _eventController.add(DeviceAddedEvent(device: device));
      }
    }
    // And record the updated set.
    _currentDevices
      ..clear()
      ..addAll(newDevices);

    // Finally, handle if the selection changed.
    if (e.selectedDeviceId != _currentSelectedDeviceId) {
      _currentSelectedDeviceId = e.selectedDeviceId;
      _eventController.add(
        DeviceSelectedEvent(deviceId: _currentSelectedDeviceId),
      );
    }
  }

  /// Handles the `postMessage` [VsCodeDebugSessionsEvent] and converts the
  /// updates into events in the format of the new DTD `editor` event stream.
  void _debugSessionsChanged(VsCodeDebugSessionsEvent e) {
    final newIds = e.sessions.map((d) => d.id).toSet();
    final oldIds = _currentDebugSessions.map((d) => d.id).toSet();

    // Sessions that are not in the new set have been removed.
    for (final id in oldIds.difference(newIds)) {
      _eventController.add(DebugSessionStoppedEvent(debugSessionId: id));
    }
    // Sessions in the new set have either been changed or were added.
    for (final session in e.sessions) {
      if (oldIds.contains(session.id)) {
        _eventController.add(DebugSessionChangedEvent(debugSession: session));
      } else {
        _eventController.add(DebugSessionStartedEvent(debugSession: session));
      }
    }
    // And record the updated set.
    _currentDebugSessions
      ..clear()
      ..addAll(e.sessions);
  }

  final VsCodeApi _api;
  final _currentDevices = <EditorDevice>[];
  String? _currentSelectedDeviceId;
  final _currentDebugSessions = <EditorDebugSession>[];
  final _eventController = StreamController<EditorEvent>();

  @override
  Future<void> close() async {}

  @override
  Future<void> enablePlatformType(String platformType) async {
    await _api.enablePlatformType(platformType);
  }

  @override
  Stream<EditorEvent> get event => _eventController.stream;

  @override
  Future<List<EditorDevice>> getDevices() async {
    return _currentDevices;
  }

  @override
  Future<List<EditorDebugSession>> getDebugSessions() async {
    return _currentDebugSessions;
  }

  @override
  Future<void> hotReload(String debugSessionId) async {
    await _api.hotReload(debugSessionId);
  }

  @override
  Future<void> hotRestart(String debugSessionId) async {
    await _api.hotRestart(debugSessionId);
  }

  @override
  Future<void> openDevToolsPage(
    String? debugSessionId, {
    String? page,
    bool? forceExternal,
    bool? requiresDebugSession,
    bool? prefersDebugSession,
  }) async {
    await _api.openDevToolsPage(
      debugSessionId,
      page: page,
      forceExternal: forceExternal,
      requiresDebugSession: requiresDebugSession,
      prefersDebugSession: prefersDebugSession,
    );
  }

  @override
  Future<void> selectDevice(EditorDevice? device) async {
    await _api.selectDevice(device!.id);
  }

  @override
  bool get supportsGetDevices => true; // Always true because we handle locally.

  @override
  bool get supportsSelectDevice => _api.capabilities.selectDevice;

  @override
  bool get supportsHotReload => _api.capabilities.hotReload;

  @override
  bool get supportsHotRestart => _api.capabilities.hotRestart;

  @override
  bool get supportsOpenDevToolsExternally =>
      _api.capabilities.openDevToolsExternally;

  @override
  bool get supportsOpenDevToolsPage => _api.capabilities.openDevToolsPage;
}
