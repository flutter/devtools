// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/service/editor/api_classes.dart';
import 'package:devtools_app/src/service/editor/editor_server.dart';

/// An mixin for [EditorServer]s that provides some useful mock editor
/// functionality to allow working on the sidebar with a Stager app without
/// needing to be connected to a real editor.
mixin FakeEditor on EditorServer {
  /// The current of devices simulated as connected.
  final devices = <String, EditorDevice>{};

  /// The current of debug sessions simulated as running.
  final debugSessions = <String, EditorDebugSession>{};

  /// The number of the next debug session to start.
  var _nextDebugSessionNumber = 1;

  /// The current device simulated as selected.
  String? selectedDeviceId;

  Stream<String> get log;

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

  @override
  FutureOr<List<EditorDevice>> getDevices() {
    return devices.values.toList();
  }

  @override
  FutureOr<void> selectDevice(String? deviceId) {
    // Find the device the client asked us to select, select it, and then
    // send an event back to confirm it is now the selected device.
    final device = devices[deviceId];
    selectedDeviceId = deviceId;
    sendDeviceSelected(device);
  }

  @override
  FutureOr<void> enablePlatformType(String platformType) {
    for (var MapEntry(key: id, value: device) in devices.entries) {
      if (!device.supported && device.platformType == platformType) {
        device = devices[id] = EditorDevice.fromJson(
          {
            ...device.toJson(),
            'supported': true,
          },
        );
        sendDeviceChanged(device);
      }
    }
  }

  @override
  FutureOr<void> hotReload(String debugSessionId) {}

  @override
  FutureOr<void> hotRestart(String debugSessionId) {}

  @override
  FutureOr<void> openDevToolsPage(
    String debugSessionId,
    String? page,
    bool forceExternal,
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
