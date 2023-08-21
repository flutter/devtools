// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:meta/meta.dart';

import '../vs_code_api.dart';
import 'dart_tooling_api.dart';

final class VsCodeApiImpl extends ToolApiImpl implements VsCodeApi {
  VsCodeApiImpl._(super.rpc, Map<String, Object?> capabilities) {
    this.capabilities = VsCodeCapabilitiesImpl(capabilities);
    devicesChanged = events(VsCodeApi.jsonDevicesChangedEvent)
        .map(VsCodeDevicesEventImpl.fromJson);
  }

  static Future<VsCodeApi?> tryConnect(json_rpc_2.Peer rpc) async {
    final capabilities =
        await ToolApiImpl.tryGetCapabilities(rpc, VsCodeApi.jsonApiName);
    return capabilities != null ? VsCodeApiImpl._(rpc, capabilities) : null;
  }

  @override
  Future<void> initialize() => sendRequest(VsCodeApi.jsonInitializeMethod);

  @override
  @protected
  String get apiName => VsCodeApi.jsonApiName;

  @override
  late final Stream<VsCodeDevicesEvent> devicesChanged;

  @override
  late final VsCodeCapabilities capabilities;

  @override
  Future<Object?> executeCommand(String command, [List<Object?>? arguments]) {
    return sendRequest(
      VsCodeApi.jsonExecuteCommandMethod,
      {
        VsCodeApi.jsonExecuteCommandCommandParameter: command,
        VsCodeApi.jsonExecuteCommandArgumentsParameter: arguments,
      },
    );
  }

  @override
  Future<bool> selectDevice(String id) {
    return sendRequest(
      VsCodeApi.jsonSelectDeviceMethod,
      {VsCodeApi.jsonSelectDeviceIdParameter: id},
    );
  }
}

class VsCodeDeviceImpl implements VsCodeDevice {
  VsCodeDeviceImpl({
    required this.id,
    required this.name,
    required this.category,
    required this.emulator,
    required this.emulatorId,
    required this.ephemeral,
    required this.platform,
    required this.platformType,
  });

  VsCodeDeviceImpl.fromJson(Map<String, Object?> json)
      : this(
          id: json[VsCodeDevice.jsonIdField] as String,
          name: json[VsCodeDevice.jsonNameField] as String,
          category: json[VsCodeDevice.jsonCategoryField] as String?,
          emulator: json[VsCodeDevice.jsonEmulatorField] as bool,
          emulatorId: json[VsCodeDevice.jsonEmulatorIdField] as String?,
          ephemeral: json[VsCodeDevice.jsonEphemeralField] as bool,
          platform: json[VsCodeDevice.jsonPlatformField] as String,
          platformType: json[VsCodeDevice.jsonPlatformTypeField] as String?,
        );

  @override
  final String id;

  @override
  final String name;

  @override
  final String? category;

  @override
  final bool emulator;

  @override
  final String? emulatorId;

  @override
  final bool ephemeral;

  @override
  final String platform;

  @override
  final String? platformType;

  Map<String, Object?> toJson() => {
        VsCodeDevice.jsonIdField: id,
        VsCodeDevice.jsonNameField: name,
        VsCodeDevice.jsonCategoryField: category,
        VsCodeDevice.jsonEmulatorField: emulator,
        VsCodeDevice.jsonEmulatorIdField: emulatorId,
        VsCodeDevice.jsonEphemeralField: ephemeral,
        VsCodeDevice.jsonPlatformField: platform,
        VsCodeDevice.jsonPlatformTypeField: platformType,
      };
}

class VsCodeDevicesEventImpl implements VsCodeDevicesEvent {
  VsCodeDevicesEventImpl({
    required this.selectedDeviceId,
    required this.devices,
  });

  VsCodeDevicesEventImpl.fromJson(Map<String, Object?> json)
      : this(
          selectedDeviceId:
              json[VsCodeDevicesEvent.jsonSelectedDeviceIdField] as String?,
          devices: (json[VsCodeDevicesEvent.jsonDevicesField] as List)
              .map((item) => Map<String, Object?>.from(item))
              .map((map) => VsCodeDeviceImpl.fromJson(map))
              .toList(),
        );

  @override
  final String? selectedDeviceId;

  @override
  final List<VsCodeDevice> devices;

  Map<String, Object?> toJson() => {
        VsCodeDevicesEvent.jsonSelectedDeviceIdField: selectedDeviceId,
        VsCodeDevicesEvent.jsonDevicesField: devices,
      };
}

class VsCodeCapabilitiesImpl implements VsCodeCapabilities {
  VsCodeCapabilitiesImpl(this._raw);

  final Map<String, Object?>? _raw;

  @override
  bool get executeCommand =>
      _raw?[VsCodeCapabilities.jsonExecuteCommandField] == true;

  @override
  bool get selectDevice =>
      _raw?[VsCodeCapabilities.jsonSelectDeviceField] == true;
}
