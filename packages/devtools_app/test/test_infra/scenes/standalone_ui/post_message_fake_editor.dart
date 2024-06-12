// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/service/editor/api_classes.dart';
import 'package:devtools_app/src/service/editor/editor_server.dart';
import 'package:devtools_app/src/standalone_ui/api/impl/vs_code_api.dart';
import 'package:devtools_app/src/standalone_ui/api/vs_code_api.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:stream_channel/stream_channel.dart';

import '../../test_data/editor_service/fake_editor.dart';

/// An implementation of [EditorServer] that wraps the legacy `postMessage` APIs.
///
/// This is used by the legacy stager app for testing the sidebar in postMessage
/// mode.
class PostMessageFakeEditor extends EditorServer with FakeEditor {
  PostMessageFakeEditor() {
    // Set up channels where we can act as the server in-process without really
    // going over postMessage or a WebSocket (since in the mock environment we
    // can't do either).
    final clientStreams = StreamController<String>();
    final serverStreams = StreamController<String>();

    // Capture traffic in both directions to aid development/debugging.
    final log = StreamController<String>();
    var logLine = 1;
    Stream<String> logStream(Stream<String> stream, String prefix) {
      return stream.map((item) {
        log.add('${logLine++} $prefix $item');
        return item;
      });
    }

    final clientChannel = StreamChannel(
      logStream(serverStreams.stream, '<=='),
      clientStreams.sink,
    );
    final serverChannel = StreamChannel(
      logStream(clientStreams.stream, '==>'),
      serverStreams.sink,
    );

    client = json_rpc_2.Peer(clientChannel);
    server = json_rpc_2.Peer(serverChannel);
    this.log = log.stream;
    unawaited(server.listen());

    // Register methods as they'll be available in a real host.
    server.registerMethod('vsCode.getCapabilities', () async {
      return {
        'selectDevice': true,
        'openDevToolsPage': true,
        'openDevToolsExternally': true,
        'hotReload': true,
        'hotRestart': true,
      };
    });
    server.registerMethod('vsCode.initialize', _initialize);
    server.registerMethod('vsCode.selectDevice', _selectDevice);
    server.registerMethod('vsCode.enablePlatformType', _enablePlatformType);
    server.registerMethod('vsCode.openDevToolsPage', _noOpHandler);
    server.registerMethod('vsCode.hotReload', _noOpHandler);
    server.registerMethod('vsCode.hotRestart', _noOpHandler);
  }

  late final json_rpc_2.Peer client;
  late final json_rpc_2.Peer server;

  @override
  late final Stream<String> log;

  /// Simulates executing a VS Code command requested by the embedded panel.
  void _initialize() {
    connectDevices();
  }

  /// Simulates changing the selected device to [id] as requested by the
  /// embedded panel.
  Future<bool> _selectDevice(json_rpc_2.Parameters parameters) async {
    final params = parameters.asMap;
    selectDevice(params['id'] as String?);
    return true;
  }

  /// Simulates a request to enable a platform type to allow additional devices
  /// to be used.
  Future<bool> _enablePlatformType(json_rpc_2.Parameters parameters) async {
    final params = parameters.asMap;
    enablePlatformType(params['platformType'] as String);
    return true;
  }

  /// A no-op handler for method handlers that don't require an implementation
  /// but need to exist so that the request/response is successful.
  void _noOpHandler(json_rpc_2.Parameters _) {}

  @override
  Future<void> close() => client.close();

  @override
  void sendDebugSessionStarted(EditorDebugSession debugSession) =>
      _sendDebugSessionsChanged();

  @override
  void sendDebugSessionStopped(EditorDebugSession debugSession) =>
      _sendDebugSessionsChanged();

  @override
  void sendDebugSessionChanged(EditorDebugSession debugSession) =>
      _sendDebugSessionsChanged();

  void _sendDevicesChanged() {
    server.sendNotification(
      '${VsCodeApi.jsonApiName}.${VsCodeApi.jsonDevicesChangedEvent}',
      VsCodeDevicesEventImpl(
        devices: devices.values.where((device) => device.supported).toList(),
        unsupportedDevices:
            devices.values.where((device) => !device.supported).toList(),
        selectedDeviceId: selectedDeviceId,
      ).toJson(),
    );
  }

  void _sendDebugSessionsChanged() {
    server.sendNotification(
      '${VsCodeApi.jsonApiName}.${VsCodeApi.jsonDebugSessionsChangedEvent}',
      VsCodeDebugSessionsEventImpl(
        sessions: debugSessions.values.toList(),
      ).toJson(),
    );
  }

  @override
  void sendDeviceAdded(EditorDevice device) => _sendDevicesChanged();

  @override
  void sendDeviceChanged(EditorDevice device) => _sendDevicesChanged();

  @override
  void sendDeviceRemoved(EditorDevice device) => _sendDevicesChanged();

  @override
  void sendDeviceSelected(EditorDevice? device) => _sendDevicesChanged();
}
