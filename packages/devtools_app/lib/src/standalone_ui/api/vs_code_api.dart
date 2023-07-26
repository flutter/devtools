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
}

abstract interface class VsCodeDevice {
  String get id;
  String get name;
  String? get category;
  bool get emulator;
  String? get emulatorId;
  bool get ephemeral;
  String get platform;
  String? get platformType;
}

abstract interface class VsCodeDevicesEvent {
  String? get selectedDeviceId;
  List<VsCodeDevice> get devices;
}

abstract interface class VsCodeCapabilities {
  bool get executeCommand;
}
