// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// This class defines the API exposed by the Dart/Flutter extensions in VS
/// Code (and must match the implementation there).
///
/// All changes to this file should be backwards-compatible and use
/// [VsCodeCapabilities] to advertise which capabilities are available and
/// handle any changes in behaviour.
abstract interface class VsCodeApi {
  VsCodeCapabilities get capabilities;
  Future<void> initialize();
  Stream<VsCodeDevicesEvent> get devicesChanged;
  Stream<VsCodeDebugSessionsEvent> get debugSessionsChanged;
  Future<Object?> executeCommand(String command, [List<Object?>? arguments]);
  Future<bool> selectDevice(String id);
  Future<void> openDevToolsPage(String debugSessionId, String page);

  static const jsonApiName = 'vsCode';

  static const jsonInitializeMethod = 'initialize';

  static const jsonExecuteCommandMethod = 'executeCommand';
  static const jsonExecuteCommandCommandParameter = 'command';
  static const jsonExecuteCommandArgumentsParameter = 'arguments';

  static const jsonDevicesChangedEvent = 'devicesChanged';

  static const jsonSelectDeviceMethod = 'selectDevice';
  static const jsonSelectDeviceIdParameter = 'id';

  static const openDevToolsPageMethod = 'openDevToolsPage';
  static const openDevToolsPageDebugSessionIdParameter = 'debugSessionId';
  static const openDevToolsPagePageParameter = 'page';

  static const jsonDebugSessionsChangedEvent = 'debugSessionsChanged';
}

/// This class defines a device exposed by the Dart/Flutter extensions in VS
/// Code (and must match the implementation there).
///
/// All changes to this file should be backwards-compatible and use
/// [VsCodeCapabilities] to advertise which capabilities are available and
/// handle any changes in behaviour.
abstract interface class VsCodeDevice {
  String get id;
  String get name;
  String? get category;
  bool get emulator;
  String? get emulatorId;
  bool get ephemeral;
  String get platform;
  String? get platformType;

  static const jsonIdField = 'id';
  static const jsonNameField = 'name';
  static const jsonCategoryField = 'category';
  static const jsonEmulatorField = 'emulator';
  static const jsonEmulatorIdField = 'emulatorId';
  static const jsonEphemeralField = 'ephemeral';
  static const jsonPlatformField = 'platform';
  static const jsonPlatformTypeField = 'platformType';
}

/// This class defines a debug session exposed by the Dart/Flutter extensions in
/// VS Code (and must match the implementation there).
///
/// All changes to this file should be backwards-compatible and use
/// [VsCodeCapabilities] to advertise which capabilities are available and
/// handle any changes in behaviour.
abstract interface class VsCodeDebugSession {
  String get id;
  String get name;
  String? get vmServiceUri;

  /// The mode the app is running in.
  ///
  /// These values are defined by Flutter and at the time of writing can include
  /// 'debug', 'profile', 'release' and 'jit_release'.
  ///
  /// This value may be unavailable (`null`) for older SDKs or for Dart/Test
  /// sessions.
  String? get flutterMode;

  /// The ID of the device the Flutter app is running on, if available.
  String? get flutterDeviceId;

  /// The type of debugger session. If available, this is usually one of:
  ///
  /// - Dart        (dart run)
  /// - DartTest    (dart test)
  /// - Flutter     (flutter run)
  /// - FlutterTest (flutter test)
  /// - Web         (webdev serve)
  /// - WebTest     (webdev test)
  String? get debuggerType;

  static const jsonIdField = 'id';
  static const jsonNameField = 'name';
  static const jsonVmServiceUriField = 'vmServiceUri';
  static const jsonFlutterModeField = 'flutterMode';
  static const jsonFlutterDeviceIdField = 'flutterDeviceId';
  static const jsonDebuggerTypeField = 'debuggerType';
}

/// This class defines a device event sent by the Dart/Flutter extensions in VS
/// Code (and must match the implementation there).
///
/// All changes to this file should be backwards-compatible and use
/// [VsCodeCapabilities] to advertise which capabilities are available and
/// handle any changes in behaviour.
abstract interface class VsCodeDevicesEvent {
  String? get selectedDeviceId;
  List<VsCodeDevice> get devices;

  static const jsonSelectedDeviceIdField = 'selectedDeviceId';
  static const jsonDevicesField = 'devices';
}

/// This class defines a debug session event sent by the Dart/Flutter extensions
/// in VS Code (and must match the implementation there).
///
/// All changes to this file should be backwards-compatible and use
/// [VsCodeCapabilities] to advertise which capabilities are available and
/// handle any changes in behaviour.
abstract interface class VsCodeDebugSessionsEvent {
  List<VsCodeDebugSession> get sessions;

  static const jsonSessionsField = 'sessions';
}

/// This class defines the capabilities provided by the current version of the
/// Dart/Flutter extensions in VS Code.
///
/// All changes to this file should be backwards-compatible and use
/// [VsCodeCapabilities] to advertise which capabilities are available and
/// handle any changes in behaviour.
abstract interface class VsCodeCapabilities {
  bool get executeCommand;
  bool get selectDevice;
  bool get openDevToolsPage;

  static const jsonExecuteCommandField = 'executeCommand';
  static const jsonSelectDeviceField = 'selectDevice';
  static const openDevToolsPageField = 'openDevToolsPage';
}
