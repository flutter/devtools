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
class FakeDartToolingApi extends DartToolingApiImpl {
  factory FakeDartToolingApi() {
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

    return FakeDartToolingApi._(
      client: clientPeer,
      server: serverPeer,
      log: log.stream,
    );
  }

  FakeDartToolingApi._({
    required this.client,
    required this.server,
    required this.log,
  }) : super.rpc(client) {
    // Register methods as they'll be available in a real host.
    server.registerMethod('vsCode.getCapabilities', () async {
      return {
        'executeCommand': true,
        'selectDevice': true,
        'openDevToolsPage': true,
        'openDevToolsExternally': true,
        'hotReload': true,
        'hotRestart': true,
      };
    });
    server.registerMethod('vsCode.initialize', initialize);
    server.registerMethod('vsCode.executeCommand', executeCommand);
    server.registerMethod('vsCode.selectDevice', selectDevice);
    server.registerMethod('vsCode.enablePlatformType', enablePlatformType);
    server.registerMethod('vsCode.openDevToolsPage', noOpHandler);
    server.registerMethod('vsCode.hotReload', noOpHandler);
    server.registerMethod('vsCode.hotRestart', noOpHandler);
  }

  final json_rpc_2.Peer client;
  final json_rpc_2.Peer server;

  /// The current set of enabled platform types.
  ///
  /// Defaults are set in [connectDevices].
  final _enabledPlatformTypes = <String>{};

  /// The current set of devices being presented to the embedded panel.
  final _devices = <VsCodeDevice>[];

  /// The current set of devices whose platform types are enabled.
  List<VsCodeDevice> get _enabledDevices => _devices
      .where((device) => _enabledPlatformTypes.contains(device.platformType))
      .toList();

  /// The current set of devices whose platform types are not enabled.
  List<VsCodeDevice> get _disabledDevices => _devices
      .where((device) => !_enabledPlatformTypes.contains(device.platformType))
      .toList();

  /// The current set of debug sessions that are running.
  final _debugSessions = <VsCodeDebugSession>[];

  /// The number of the next debug session to start.
  var _nextDebugSessionNumber = 1;

  /// The currently selected device presented to the embedded panel.
  String? _selectedDeviceId;

  /// A stream of log events for debugging.
  final Stream<String> log;

  /// Simulates executing a VS Code command requested by the embedded panel.
  void initialize() {
    connectDevices();
  }

  /// Simulates executing a VS Code command requested by the embedded panel.
  Future<Object?> executeCommand(json_rpc_2.Parameters parameters) {
    final params = parameters.asMap;
    final command = params['command'];
    switch (command) {
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

  /// Simulates a request to enable a platform type to allow additional devices
  /// to be used.
  Future<bool> enablePlatformType(json_rpc_2.Parameters parameters) async {
    final params = parameters.asMap;
    _enabledPlatformTypes.add(params['platformType'] as String);
    // Add some delay because the real impl will need to prompt + run
    // `flutter create`.
    await Future.delayed(const Duration(seconds: 1));
    _sendDevicesChanged();
    return true;
  }

  /// A no-op handler for method handlers that don't require an implementation
  /// but need to exist so that the request/response is successful.
  void noOpHandler(json_rpc_2.Parameters _) {}

  /// Simulates devices being connected in the IDE by notifying the embedded
  /// panel about a set of test devices.
  void connectDevices() {
    _devices
      ..clear()
      ..addAll(stubbedDevices);
    _enabledPlatformTypes
      ..clear()
      ..addAll(['macos', 'android']);
    _selectedDeviceId = _enabledDevices.lastOrNull?.id;
    _sendDevicesChanged();
  }

  /// Simulates starting a debug session.
  ///
  /// [debuggerType] should match one of the available values for [VsCodeDebugSession.debuggerType].
  ///
  /// [deviceId] can be any id for a flutter device. This should be null if [debuggerType]
  /// is not 'Flutter'.
  ///
  /// [flutterMode] should match one of the available values for [VsCodeDebugSession.flutterMode].
  /// This should be null if [debuggerType] is not 'Flutter'.
  void startSession({
    required String debuggerType,
    required String deviceId,
    String? flutterMode,
  }) {
    final sessionNum = _nextDebugSessionNumber++;
    _debugSessions.add(
      VsCodeDebugSessionImpl(
        id: 'debug-$sessionNum',
        name: 'Session $sessionNum ($deviceId)',
        vmServiceUri: 'ws://127.0.0.1:1234/ws',
        flutterMode: flutterMode,
        flutterDeviceId: deviceId,
        debuggerType: debuggerType,
        projectRootPath: '/mock/root/path',
      ),
    );
    _sendDebugSessionsChanged();
  }

  /// Simulates ending all debug sessions.
  void endSessions() {
    _debugSessions.clear();
    _sendDebugSessionsChanged();
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
      '${VsCodeApi.jsonApiName}.${VsCodeApi.jsonDevicesChangedEvent}',
      VsCodeDevicesEventImpl(
        devices: _enabledDevices,
        unsupportedDevices: _disabledDevices,
        selectedDeviceId: _selectedDeviceId,
      ).toJson(),
    );
  }

  void _sendDebugSessionsChanged() {
    server.sendNotification(
      '${VsCodeApi.jsonApiName}.${VsCodeApi.jsonDebugSessionsChangedEvent}',
      VsCodeDebugSessionsEventImpl(
        sessions: _debugSessions,
      ).toJson(),
    );
  }
}

/// A set of mock devices that can be presented for testing.
final stubbedDevices = <VsCodeDevice>[
  VsCodeDeviceImpl(
    id: 'macos',
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
  VsCodeDeviceImpl(
    id: 'chrome',
    name: 'Chrome',
    category: 'web',
    emulator: false,
    emulatorId: null,
    ephemeral: true,
    platform: 'web-javascript',
    platformType: 'web',
  ),
  VsCodeDeviceImpl(
    id: 'web-server',
    name: 'Web Server',
    category: 'web',
    emulator: false,
    emulatorId: null,
    ephemeral: true,
    platform: 'web-javascript',
    platformType: 'web',
  ),
];
