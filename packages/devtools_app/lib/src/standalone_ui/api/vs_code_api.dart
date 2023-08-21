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
  Future<Object?> executeCommand(String command, [List<Object?>? arguments]);
  Future<bool> selectDevice(String id);

  static const jsonApiName = 'vsCode';

  static const jsonInitializeMethod = 'initialize';

  static const jsonExecuteCommandMethod = 'executeCommand';
  static const jsonExecuteCommandCommandParameter = 'command';
  static const jsonExecuteCommandArgumentsParameter = 'arguments';

  static const jsonDevicesChangedEvent = 'devicesChanged';

  static const jsonSelectDeviceMethod = 'selectDevice';
  static const jsonSelectDeviceIdParameter = 'id';
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

/// This class defines the capabilities provided by the current version of the
/// Dart/Flutter extensions in VS Code.
///
/// All changes to this file should be backwards-compatible and use
/// [VsCodeCapabilities] to advertise which capabilities are available and
/// handle any changes in behaviour.
abstract interface class VsCodeCapabilities {
  bool get executeCommand;
  bool get selectDevice;

  static const jsonExecuteCommandField = 'executeCommand';
  static const jsonSelectDeviceField = 'selectDevice';
}
