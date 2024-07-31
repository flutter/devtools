// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/service/editor/api_classes.dart';
import 'package:dtd/dtd.dart';
import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A base for classes that can act as an Editor (agnostic to the communication
/// channel).
///
/// This class is for the part of an editor connected to DTD that is providing
/// the editor services. It is the opposite of [EditorClient] which is for
/// consuming the services provided by the editor(server).
abstract class SimulatedEditorBase {
  /// A stream of protocol traffic between the editor and DTD (or postMessage
  /// API).
  Stream<String> get log;

  /// Close any communication channel.
  Future<void> close();

  /// Overridden by subclasses to provide an implementation of the getDevices
  /// method that can be called by a DTD client.
  FutureOr<GetDevicesResult> getDevices();

  /// Overridden by subclasses to provide an implementation of the
  /// getDebugSessions method that can be called by a DTD client.
  FutureOr<GetDebugSessionsResult> getDebugSessions();

  /// Overridden by subclasses to provide an implementation of the selectDevice
  /// method that can be called by a DTD client.
  FutureOr<void> selectDevice(String? deviceId);

  /// Overridden by subclasses to provide an implementation of the hotReload
  /// method that can be called by a DTD client.
  FutureOr<void> hotReload(String debugSessionId);

  /// Overridden by subclasses to provide an implementation of the hotRestart
  /// method that can be called by a DTD client.
  FutureOr<void> hotRestart(String debugSessionId);

  /// Overridden by subclasses to provide an implementation of the openDevTools
  /// method that can be called by a DTD client.
  FutureOr<void> openDevToolsPage(
    String? debugSessionId,
    String? page,
    bool forceExternal,
    bool requiresDebugSession,
    bool prefersDebugSession,
  );

  /// Overridden by subclasses to provide an implementation of the
  /// enablePlatformType method that can be called by a DTD client.
  FutureOr<void> enablePlatformType(String platformType);

  /// Implemented by subclasses to provide the implementation to send a
  /// `deviceAdded` event.
  void sendDeviceAdded(EditorDevice device);

  /// Implemented by subclasses to provide the implementation to send a
  /// `deviceChanged` event.
  void sendDeviceChanged(EditorDevice device);

  /// Implemented by subclasses to provide the implementation to send a
  /// `deviceRemoved` event.
  void sendDeviceRemoved(EditorDevice device);

  /// Implemented by subclasses to provide the implementation to send a
  /// `deviceSelected` event.
  void sendDeviceSelected(EditorDevice? device);

  /// Implemented by subclasses to provide the implementation to send a
  /// `debugSessionStarted` event.
  void sendDebugSessionStarted(EditorDebugSession debugSession);

  /// Implemented by subclasses to provide the implementation to send a
  /// `debugSessionChanged` event.
  void sendDebugSessionChanged(EditorDebugSession debugSession);

  /// Implemented by subclasses to provide the implementation to send a
  /// `debugSessionStopped` event.
  void sendDebugSessionStopped(EditorDebugSession debugSession);
}

/// A wrapper over DTD for providing editor functionality.
///
/// This class is useful for tests and the "mock editor" but could in theory
/// also be used by an editor directly (if it was written in Dart, and had
/// access to this class).
///
/// Since this class is intended to represent what real IDEs may do, any changes
/// made here to match changes made to [EditorClient] should be considered
/// carefully to ensure they are not breaking changes to already-shipped
/// editors.
abstract class DtdSimulatedEditorBase extends SimulatedEditorBase {
  // TODO(dantup): Once the postMessage code is gone, merge DtdSimulatedEditor,
  //  DtdSimulatedEditorBase, and SimulatedEditorBase to simplify things.
  DtdSimulatedEditorBase(this._dtdUri) {
    // Connect editor automatically at launch.
    unawaited(connectEditor());
  }

  final Uri _dtdUri;
  DartToolingDaemon? _dtd;

  /// A controller for emitting to [log].
  final _logger = StreamController<String>();

  @override
  Stream<String> get log => _logger.stream;

  Future<void> _registerServices() {
    return Future.wait([
      _registerService(EditorMethod.getDevices, _getDevices),
      _registerService(EditorMethod.selectDevice, _selectDevice),
      _registerService(EditorMethod.getDebugSessions, _getDebugSessions),
      _registerService(EditorMethod.hotReload, _hotReload),
      _registerService(EditorMethod.hotRestart, _hotRestart),
      _registerService(
        EditorMethod.openDevToolsPage,
        _openDevToolsPage,
        capabilities: {
          Field.supportsForceExternal: true,
        },
      ),
      _registerService(EditorMethod.enablePlatformType, _enablePlatformType),
    ]);
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
  @override
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

  static const _successResponse = {
    'type': 'Success',
  };

  Future<Map<String, Object?>> _getDevices(Parameters params) async {
    final result = await getDevices();
    return Future.value({
      'type': 'GetDevicesResult',
      ...result.toJson(),
    });
  }

  Future<Map<String, Object?>> _selectDevice(Parameters params) async {
    await selectDevice(params[Field.deviceId].valueOr(null) as String?);
    return _successResponse;
  }

  Future<Map<String, Object?>> _getDebugSessions(Parameters params) async {
    final result = await getDebugSessions();
    return Future.value({
      'type': 'GetDebugSessionsResult',
      ...result.toJson(),
    });
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

  @override
  void sendDeviceAdded(EditorDevice device) async {
    await _postEvent(DeviceAddedEvent(device: device));
  }

  @override
  void sendDeviceChanged(EditorDevice device) async {
    await _postEvent(DeviceChangedEvent(device: device));
  }

  @override
  void sendDeviceRemoved(EditorDevice device) async {
    await _postEvent(DeviceRemovedEvent(deviceId: device.id));
  }

  @override
  void sendDeviceSelected(EditorDevice? device) async {
    await _postEvent(DeviceSelectedEvent(deviceId: device?.id));
  }

  @override
  void sendDebugSessionStarted(EditorDebugSession debugSession) async {
    await _postEvent(DebugSessionStartedEvent(debugSession: debugSession));
  }

  @override
  void sendDebugSessionChanged(EditorDebugSession debugSession) async {
    await _postEvent(DebugSessionChangedEvent(debugSession: debugSession));
  }

  @override
  void sendDebugSessionStopped(EditorDebugSession debugSession) async {
    await _postEvent(DebugSessionStoppedEvent(debugSessionId: debugSession.id));
  }
}
