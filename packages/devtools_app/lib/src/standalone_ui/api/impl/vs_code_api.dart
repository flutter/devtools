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
    devicesChanged =
        events('devicesChanged').map(VsCodeDevicesEventImpl.fromJson);
  }

  static Future<VsCodeApi?> tryConnect(json_rpc_2.Peer rpc) async {
    final capabilities = await ToolApiImpl.tryGetCapabilities(rpc, _apiName);
    return capabilities != null ? VsCodeApiImpl._(rpc, capabilities) : null;
  }

  static const _apiName = 'vsCode';

  @override
  Future<void> initialize() => sendRequest('initialize');

  @override
  @protected
  String get apiName => _apiName;

  @override
  late final Stream<VsCodeDevicesEvent> devicesChanged;

  @override
  late final VsCodeCapabilities capabilities;

  @override
  Future<Object?> executeCommand(String command, [List<Object?>? arguments]) {
    return sendRequest(
      'executeCommand',
      {'command': command, 'arguments': arguments},
    );
  }

  @override
  Future<bool> selectDevice(String id) {
    return sendRequest(
      'selectDevice',
      {'id': id},
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
          id: json['id'] as String,
          name: json['name'] as String,
          category: json['category'] as String?,
          emulator: json['emulator'] as bool,
          emulatorId: json['emulatorId'] as String?,
          ephemeral: json['ephemeral'] as bool,
          platform: json['platform'] as String,
          platformType: json['platformType'] as String?,
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
        'id': id,
        'name': name,
        'category': category,
        'emulator': emulator,
        'emulatorId': emulatorId,
        'ephemeral': ephemeral,
        'platform': platform,
        'platformType': platformType,
      };
}

class VsCodeDevicesEventImpl implements VsCodeDevicesEvent {
  VsCodeDevicesEventImpl({
    required this.selectedDeviceId,
    required this.devices,
  });

  VsCodeDevicesEventImpl.fromJson(Map<String, Object?> json)
      : this(
          selectedDeviceId: json['selectedDeviceId'] as String?,
          devices: (json['devices'] as List)
              .map((item) => Map<String, Object?>.from(item))
              .map((map) => VsCodeDeviceImpl.fromJson(map))
              .toList(),
        );

  @override
  final String? selectedDeviceId;

  @override
  final List<VsCodeDevice> devices;

  Map<String, Object?> toJson() => {
        'selectedDeviceId': selectedDeviceId,
        'devices': devices,
      };
}

class VsCodeCapabilitiesImpl implements VsCodeCapabilities {
  VsCodeCapabilitiesImpl(this._raw);

  final Map<String, Object?>? _raw;

  @override
  bool get executeCommand => _raw?['executeCommand'] == true;
}
