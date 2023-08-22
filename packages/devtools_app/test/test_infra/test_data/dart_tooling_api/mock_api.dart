// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/standalone_ui/api/impl/dart_tooling_api.dart';
import 'package:devtools_app/src/standalone_ui/api/impl/vs_code_api.dart';
import 'package:devtools_app/src/standalone_ui/api/vs_code_api.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:stream_channel/stream_channel.dart';

/// A [DartToolingApi] that acts as a stand-in host IDE to simplify the
/// development workflow when working on embedded tooling.
///
/// This API will handle requests with canned responses and can generate
/// events in a similar way to the IDE would. It is used by
/// [VsCodeFlutterPanelMock] which provides a UI onto this functionality and a
/// log of recent requests.
class MockDartToolingApi extends DartToolingApiImpl {
  factory MockDartToolingApi() {
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

    final clientPeer = json_rpc_2.Peer(clientChannel);
    final serverPeer = json_rpc_2.Peer(serverChannel);
    unawaited(serverPeer.listen());

    return MockDartToolingApi._(
      client: clientPeer,
      server: serverPeer,
      log: log.stream,
    );
  }

  MockDartToolingApi._({
    required this.client,
    required this.server,
    required this.log,
  }) : super.rpc(client) {
    // Register methods as they'll be available in a real host.
    server.registerMethod('vsCode.getCapabilities', () async {
      return {
        'executeCommand': true,
        'selectDevice': true,
      };
    });
    server.registerMethod('vsCode.initialize', initialize);
    server.registerMethod('vsCode.executeCommand', executeCommand);
    server.registerMethod('vsCode.selectDevice', selectDevice);
  }

  final json_rpc_2.Peer client;
  final json_rpc_2.Peer server;

  /// A set of mock devices that can be presented for testing.
  final _mockDevices = <VsCodeDevice>[
    VsCodeDeviceImpl(
      id: 'myMac',
      name: 'Mac',
      category: 'desktop',
      emulator: false,
      emulatorId: null,
      ephemeral: false,
      platform: 'darwin-x64',
      platformType: 'macos',
    ),
    VsCodeDeviceImpl(
      id: 'myPhone',
      name: 'My Android Phone',
      category: 'mobile',
      emulator: false,
      emulatorId: null,
      ephemeral: true,
      platform: 'android-x64',
      platformType: 'android',
    ),
  ];

  /// The current set of devices being presented to the embedded panel.
  final _devices = <VsCodeDevice>[];

  /// The currently selected device presented to the embedded panel.
  String? _selectedDeviceId;

  /// A stream of log events for debugging.
  final Stream<String> log;

  /// Simulates executing a VS Code command requested by the embedded panel.
  void initialize() {
    connectDevices();
  }

  /// Simulates executing a VS Code command requested by the embedded panel.
  Future<Object?> executeCommand(json_rpc_2.Parameters parameters) async {
    final params = parameters.asMap;
    final command = params['command'];
    switch (command) {
      case 'flutter.createProject':
        return null;
      case 'flutter.doctor':
        return null;
      default:
        throw 'Unknown command $command';
    }
  }

  /// Simulates changing the selected device to [id] as requested by the
  /// embedded panel.
  Future<bool> selectDevice(json_rpc_2.Parameters parameters) async {
    final params = parameters.asMap;
    _selectedDeviceId = params['id'] as String?;
    _sendDevicesChanged();
    return true;
  }

  /// Simulates devices being connected in the IDE by notifying the embedded
  /// panel about a set of test devices.
  void connectDevices() {
    _devices
      ..clear()
      ..addAll(_mockDevices);
    _selectedDeviceId = _devices.lastOrNull?.id;
    _sendDevicesChanged();
  }

  /// Simulates devices being disconnected in the IDE by notifying the embedded
  /// panel about a now-empty set of devices.
  void disconnectDevices() {
    _devices.clear();
    _selectedDeviceId = null;
    _sendDevicesChanged();
  }

  void _sendDevicesChanged() {
    server.sendNotification(
      'vsCode.devicesChanged',
      VsCodeDevicesEventImpl(
        devices: _devices,
        selectedDeviceId: _selectedDeviceId,
      ).toJson(),
    );
  }
}
