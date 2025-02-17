// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// @docImport 'package:devtools_app/devtools_app.dart';
library;

import 'dart:async';

import 'package:devtools_app/src/shared/editor/api_classes.dart';
import 'package:dtd/dtd.dart';
import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A class that can simulate the part of an Editor over DTD used for testing
/// (both automated and manually via the "mock editor" stager app).
///
/// Since this class is intended to represent what real IDEs may do, any changes
/// made here to match changes made to [EditorClient] should be considered
/// carefully to ensure they are not breaking changes to already-shipped
/// editors.
class SimulatedEditor {
  SimulatedEditor(this._dtdUri) {
    // Set up some default devices.
    connectDevices();

    // Connect editor automatically at launch.
    unawaited(connectEditor());
  }

  /// The URI of the DTD instance we are connecting/connected to.
  final Uri _dtdUri;

  /// The [DartToolingDaemon] we are connected to.
  ///
  /// `null` if the connection has not yet been established.
  DartToolingDaemon? _dtd;

  /// A controller for emitting to [log].
  final _logger = StreamController<String>();

  /// A stream of protocol traffic between the editor and DTD (or postMessage
  /// API).
  Stream<String> get log => _logger.stream;

  Future<void> _registerServices() {
    return [
      _registerService(EditorMethod.getDevices, _getDevices),
      _registerService(EditorMethod.selectDevice, _selectDevice),
      _registerService(EditorMethod.getDebugSessions, _getDebugSessions),
      _registerService(EditorMethod.hotReload, _hotReload),
      _registerService(EditorMethod.hotRestart, _hotRestart),
      _registerService(
        EditorMethod.openDevToolsPage,
        _openDevToolsPage,
        capabilities: {Field.supportsForceExternal: true},
      ),
      _registerService(EditorMethod.enablePlatformType, _enablePlatformType),
    ].wait;
  }

  /// Whether the editor is currently connected to DTD.
  bool get connected => _dtd != null;

  /// Simulates an editor being connected to DTD.
  Future<void> connectEditor() async {
    _logger.add('Connecting editor to $_dtdUri');

    final rawChannel = WebSocketChannel.connect(_dtdUri);
    await rawChannel.ready;
    final rawStringChannel = rawChannel.cast<String>();

    /// A helper to create a function that can be used in stream.map() to log
    /// traffic with a prefix.
    String Function(String) logTraffic(String prefix) {
      return (String s) {
        _logger.add('$prefix $s'.trim());
        return s;
      };
    }

    // Create a channel that logs the data going through it.
    final loggedInput = rawStringChannel.stream.map(logTraffic('==>'));
    final loggedOutputController = StreamController<String>();
    unawaited(
      loggedOutputController.stream
          .map(logTraffic('<=='))
          .pipe(rawStringChannel.sink),
    );

    final loggingChannel = StreamChannel<String>(
      loggedInput,
      loggedOutputController.sink,
    );

    _dtd = DartToolingDaemon.fromStreamChannel(loggingChannel);
    await _registerServices();
  }

  /// Simulates an editor being discconnected from DTD.
  Future<void> disconnectEditor() async {
    _logger.add('Disconnecting editor...');
    await close();
    _logger.add('Disconnected!');
  }

  /// Close the connection to DTD.
  Future<void> close() async {
    await _dtd?.close();
    _dtd = null;
  }

  Future<void> _registerService(
    EditorMethod method,
    DTDServiceCallback callback, {
    Map<String, Object?>? capabilities,
  }) async {
    await _dtd?.registerService(
      editorServiceName,
      method.name,
      callback,
      capabilities: capabilities,
    );
  }

  static const _successResponse = {'type': 'Success'};

  Future<Map<String, Object?>> _getDevices(Parameters params) async {
    final result = await getDevices();
    return Future.value({'type': 'GetDevicesResult', ...result.toJson()});
  }

  Future<Map<String, Object?>> _selectDevice(Parameters params) async {
    await selectDevice(params[Field.deviceId].valueOr(null) as String?);
    return _successResponse;
  }

  Future<Map<String, Object?>> _getDebugSessions(Parameters params) async {
    final result = await getDebugSessions();
    return Future.value({'type': 'GetDebugSessionsResult', ...result.toJson()});
  }

  Future<Map<String, Object?>> _hotReload(Parameters params) async {
    await hotReload(params[Field.debugSessionId].asString);
    return _successResponse;
  }

  Future<Map<String, Object?>> _hotRestart(Parameters params) async {
    await hotRestart(params[Field.debugSessionId].asString);
    return _successResponse;
  }

  Future<Map<String, Object?>> _openDevToolsPage(Parameters params) async {
    await openDevToolsPage(
      params[Field.debugSessionId].valueOr(null) as String?,
      params[Field.page].valueOr(null) as String?,
      params[Field.forceExternal].valueOr(null) as bool? ?? false,
      params[Field.requiresDebugSession].valueOr(null) as bool? ?? false,
      params[Field.prefersDebugSession].valueOr(null) as bool? ?? false,
    );
    return _successResponse;
  }

  Future<Map<String, Object?>> _enablePlatformType(Parameters params) async {
    await enablePlatformType(params[Field.platformType].asString);
    return _successResponse;
  }

  Future<void> _postEvent(EditorEvent params) async {
    await _dtd?.postEvent(editorStreamName, params.kind.name, params.toJson());
  }

  void sendDeviceAdded(EditorDevice device) async {
    await _postEvent(DeviceAddedEvent(device: device));
  }

  void sendDeviceChanged(EditorDevice device) async {
    await _postEvent(DeviceChangedEvent(device: device));
  }

  void sendDeviceRemoved(EditorDevice device) async {
    await _postEvent(DeviceRemovedEvent(deviceId: device.id));
  }

  void sendDeviceSelected(EditorDevice? device) async {
    await _postEvent(DeviceSelectedEvent(deviceId: device?.id));
  }

  void sendDebugSessionStarted(EditorDebugSession debugSession) async {
    await _postEvent(DebugSessionStartedEvent(debugSession: debugSession));
  }

  void sendDebugSessionChanged(EditorDebugSession debugSession) async {
    await _postEvent(DebugSessionChangedEvent(debugSession: debugSession));
  }

  void sendDebugSessionStopped(EditorDebugSession debugSession) async {
    await _postEvent(DebugSessionStoppedEvent(debugSessionId: debugSession.id));
  }

  /// The current of devices simulated as connected.
  final devices = <String, EditorDevice>{};

  /// The current of debug sessions simulated as running.
  final debugSessions = <String, EditorDebugSession>{};

  /// The number of the next debug session to start.
  var _nextDebugSessionNumber = 1;

  /// The current device simulated as selected.
  String? selectedDeviceId;

  /// Simulates devices being connected in the IDE by notifying the embedded
  /// panel about a set of test devices.
  void connectDevices() {
    devices.clear();
    for (final device in stubbedDevices) {
      devices[device.id] = device;
    }

    devices.values.forEach(sendDeviceAdded);
    sendDeviceSelected(devices.values.lastOrNull);
  }

  /// Simulates devices being disconnected in the IDE by notifying the embedded
  /// panel about a set of test devices.
  void disconnectDevices() {
    sendDeviceSelected(null);
    final devicesToRemove = devices.values.toList();
    devices.clear();
    devicesToRemove.forEach(sendDeviceRemoved);
  }

  /// Simulates a debug session starting by sending debug session update events.
  void startSession({
    required String debuggerType,
    required String deviceId,
    String? flutterMode,
  }) {
    final sessionNum = _nextDebugSessionNumber++;
    final sessionId = 'debug-$sessionNum';
    final session = EditorDebugSession(
      id: 'debug-$sessionNum',
      name: 'Session $sessionNum ($deviceId)',
      vmServiceUri: 'ws://127.0.0.1:1234/ws',
      flutterMode: flutterMode,
      flutterDeviceId: deviceId,
      debuggerType: debuggerType,
      projectRootPath: '/mock/root/path',
    );
    debugSessions[sessionId] = session;
    sendDebugSessionStarted(session);
  }

  /// Simulates ending all active debug sessions.
  void stopAllSessions() {
    final sessionsToRemove = debugSessions.values.toList();
    debugSessions.clear();
    sessionsToRemove.forEach(sendDebugSessionStopped);
  }

  FutureOr<GetDevicesResult> getDevices() {
    return GetDevicesResult(
      devices: devices.values.toList(),
      selectedDeviceId: selectedDeviceId,
    );
  }

  FutureOr<GetDebugSessionsResult> getDebugSessions() {
    return GetDebugSessionsResult(debugSessions: debugSessions.values.toList());
  }

  FutureOr<void> selectDevice(String? deviceId) {
    // Find the device the client asked us to select, select it, and then
    // send an event back to confirm it is now the selected device.
    final device = devices[deviceId];
    selectedDeviceId = deviceId;
    sendDeviceSelected(device);
  }

  FutureOr<void> enablePlatformType(String platformType) {
    for (var MapEntry(key: id, value: device) in devices.entries) {
      if (!device.supported && device.platformType == platformType) {
        device =
            devices[id] = EditorDevice.fromJson({
              ...device.toJson(),
              'supported': true,
            });
        sendDeviceChanged(device);
      }
    }
  }

  FutureOr<void> hotReload(String _) {}

  FutureOr<void> hotRestart(String _) {}

  FutureOr<void> openDevToolsPage(
    String? _,
    String? __,
    bool ___,
    bool ____,
    bool _____,
  ) {}
}

/// A set of mock devices that can be presented for testing.
final stubbedDevices = [
  EditorDevice(
    id: 'macos',
    name: 'Mac',
    category: 'desktop',
    emulator: false,
    emulatorId: null,
    ephemeral: false,
    platform: 'darwin-x64',
    platformType: 'macos',
    supported: true,
  ),
  EditorDevice(
    id: 'myPhone',
    name: 'My Android Phone',
    category: 'mobile',
    emulator: false,
    emulatorId: null,
    ephemeral: true,
    platform: 'android-x64',
    platformType: 'android',
    supported: true,
  ),
  EditorDevice(
    id: 'chrome',
    name: 'Chrome',
    category: 'web',
    emulator: false,
    emulatorId: null,
    ephemeral: true,
    platform: 'web-javascript',
    platformType: 'web',
    supported: true,
  ),
  EditorDevice(
    id: 'web-server',
    name: 'Web Server',
    category: 'web',
    emulator: false,
    emulatorId: null,
    ephemeral: true,
    platform: 'web-javascript',
    platformType: 'web',
    supported: true,
  ),
  EditorDevice(
    id: 'my-unsupported-platform',
    name: 'My Unsupported Platform',
    category: 'desktop',
    emulator: false,
    emulatorId: null,
    ephemeral: true,
    platform: 'platform-unknown',
    platformType: 'unknown',
    supported: false,
  ),
];
