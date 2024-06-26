// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:meta/meta.dart';

import '../../../service/editor/api_classes.dart';
import '../vs_code_api.dart';

final class VsCodeApiImpl implements VsCodeApi {
  VsCodeApiImpl._(this.rpc, Map<String, Object?> capabilities) {
    this.capabilities = VsCodeCapabilitiesImpl(capabilities);
    devicesChanged = events(VsCodeApi.jsonDevicesChangedEvent)
        .map(VsCodeDevicesEventImpl.fromJson);

    debugSessionsChanged = events(VsCodeApi.jsonDebugSessionsChangedEvent)
        .map(VsCodeDebugSessionsEventImpl.fromJson);
  }

  static Future<VsCodeApi?> tryConnect(json_rpc_2.Peer rpc) async {
    final capabilities =
        await VsCodeApiImpl.tryGetCapabilities(rpc, VsCodeApi.jsonApiName);
    return capabilities != null ? VsCodeApiImpl._(rpc, capabilities) : null;
  }

  static Future<Map<String, Object?>?> tryGetCapabilities(
    json_rpc_2.Peer rpc,
    String apiName,
  ) async {
    try {
      final response = await rpc.sendRequest('$apiName.getCapabilities')
          as Map<Object?, Object?>;
      return response.cast<String, Object?>();
    } catch (_) {
      // Any error initializing should disable this functionality.
      return null;
    }
  }

  @protected
  final json_rpc_2.Peer rpc;

  @protected
  Future<T> sendRequest<T>(String method, [Object? parameters]) async {
    return (await rpc.sendRequest('$apiName.$method', parameters)) as T;
  }

  /// Listens for an event '[apiName].[name]' that has a Map for parameters.
  @protected
  Stream<Map<String, Object?>> events(String name) {
    final streamController = StreamController<Map<String, Object?>>.broadcast();
    unawaited(rpc.done.then((_) => streamController.close()));
    rpc.registerMethod('$apiName.$name', (json_rpc_2.Parameters parameters) {
      streamController.add(parameters.asMap.cast<String, Object?>());
    });
    return streamController.stream;
  }

  @override
  Future<void> initialize() => sendRequest(VsCodeApi.jsonInitializeMethod);

  String get apiName => VsCodeApi.jsonApiName;

  @override
  late final Stream<VsCodeDevicesEvent> devicesChanged;

  @override
  late final Stream<VsCodeDebugSessionsEvent> debugSessionsChanged;

  @override
  late final VsCodeCapabilities capabilities;

  @override
  Future<bool> selectDevice(String id) {
    return sendRequest(
      VsCodeApi.jsonSelectDeviceMethod,
      {VsCodeApi.jsonIdParameter: id},
    );
  }

  @override
  Future<bool> enablePlatformType(String platformType) {
    return sendRequest(
      VsCodeApi.jsonEnablePlatformTypeMethod,
      {VsCodeApi.jsonPlatformTypeParameter: platformType},
    );
  }

  @override
  Future<void> openDevToolsPage(
    String? debugSessionId, {
    String? page,
    bool? forceExternal,
    bool? requiresDebugSession,
    bool? prefersDebugSession,
  }) {
    return sendRequest(
      VsCodeApi.jsonOpenDevToolsPageMethod,
      {
        VsCodeApi.jsonDebugSessionIdParameter: debugSessionId,
        VsCodeApi.jsonPageParameter: page,
        VsCodeApi.jsonForceExternalParameter: forceExternal,
        VsCodeApi.jsonRequiresDebugSessionParameter: requiresDebugSession,
        VsCodeApi.jsonPrefersDebugSessionParameter: prefersDebugSession,
      },
    );
  }

  @override
  Future<void> hotReload(String debugSessionId) {
    return sendRequest(
      VsCodeApi.jsonHotReloadMethod,
      {
        VsCodeApi.jsonDebugSessionIdParameter: debugSessionId,
      },
    );
  }

  @override
  Future<void> hotRestart(String debugSessionId) {
    return sendRequest(
      VsCodeApi.jsonHotRestartMethod,
      {
        VsCodeApi.jsonDebugSessionIdParameter: debugSessionId,
      },
    );
  }
}

class VsCodeDevicesEventImpl implements VsCodeDevicesEvent {
  VsCodeDevicesEventImpl({
    required this.selectedDeviceId,
    required this.devices,
    required this.unsupportedDevices,
  });

  VsCodeDevicesEventImpl.fromJson(Map<String, Object?> json)
      : this(
          selectedDeviceId:
              json[VsCodeDevicesEvent.jsonSelectedDeviceIdField] as String?,
          devices: (json[VsCodeDevicesEvent.jsonDevicesField] as List)
              .map((item) => Map<String, Object?>.from(item))
              .map(
                (map) => EditorDevice.fromJson({
                  'supported': true,
                  ...map,
                }),
              )
              .toList(),
          unsupportedDevices:
              (json[VsCodeDevicesEvent.jsonUnsupportedDevicesField] as List?)
                  ?.map((item) => Map<String, Object?>.from(item))
                  .map(
                    (map) => EditorDevice.fromJson({
                      'supported': false,
                      ...map,
                    }),
                  )
                  .toList(),
        );

  @override
  final String? selectedDeviceId;

  @override
  final List<EditorDevice> devices;

  @override
  final List<EditorDevice>? unsupportedDevices;

  Map<String, Object?> toJson() => {
        VsCodeDevicesEvent.jsonSelectedDeviceIdField: selectedDeviceId,
        VsCodeDevicesEvent.jsonDevicesField: devices,
        VsCodeDevicesEvent.jsonUnsupportedDevicesField: unsupportedDevices,
      };
}

class VsCodeDebugSessionsEventImpl implements VsCodeDebugSessionsEvent {
  VsCodeDebugSessionsEventImpl({
    required this.sessions,
  });

  VsCodeDebugSessionsEventImpl.fromJson(Map<String, Object?> json)
      : this(
          sessions: (json[VsCodeDebugSessionsEvent.jsonSessionsField] as List)
              .map((item) => Map<String, Object?>.from(item))
              .map((map) => EditorDebugSession.fromJson(map))
              .toList(),
        );

  @override
  final List<EditorDebugSession> sessions;

  Map<String, Object?> toJson() => {
        VsCodeDebugSessionsEvent.jsonSessionsField: sessions,
      };
}

class VsCodeCapabilitiesImpl implements VsCodeCapabilities {
  VsCodeCapabilitiesImpl(this._raw);

  final Map<String, Object?>? _raw;

  @override
  bool get selectDevice =>
      _raw?[VsCodeCapabilities.jsonSelectDeviceField] == true;

  @override
  bool get openDevToolsPage =>
      _raw?[VsCodeCapabilities.openDevToolsPageField] == true;

  @override
  bool get openDevToolsExternally =>
      _raw?[VsCodeCapabilities.openDevToolsExternallyField] == true;

  @override
  bool get openDevToolsWithOptionalDebugSessionFlags =>
      _raw?[
          VsCodeCapabilities.openDevToolsWithOptionalDebugSessionFlagsField] ==
      true;

  @override
  bool get hotReload => _raw?[VsCodeCapabilities.hotReloadField] == true;

  @override
  bool get hotRestart => _raw?[VsCodeCapabilities.hotRestartField] == true;
}
