// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/service/editor/api_classes.dart';
import 'package:dtd/dtd.dart';
import 'package:json_rpc_2/json_rpc_2.dart';

/// A base for classes that can act as an Editor (agnostic to the communication
/// channel).
///
/// This class is for the part of an editor connected to DTD that is providing
/// the editor services. It is the opposite of [EditorClient] which is for
/// consuming the services provided by the editor(server).
/// A base for classes that can act as an Editor.
abstract class EditorServer {
  /// Close any communication channel.
  Future<void> close();

  /// Overridden by subclasses to provide an implementation of the getDevices
  /// method that can be called by a DTD client.
  FutureOr<List<EditorDevice>> getDevices() => [];

  /// Overridden by subclasses to provide an implementation of the selectDevice
  /// method that can be called by a DTD client.
  FutureOr<void> selectDevice(String deviceId) {}

  /// Overridden by subclasses to provide an implementation of the hotReload
  /// method that can be called by a DTD client.
  FutureOr<void> hotReload(String debugSessionId) {}

  /// Overridden by subclasses to provide an implementation of the hotRestart
  /// method that can be called by a DTD client.
  FutureOr<void> hotRestart(String debugSessionId) {}

  /// Overridden by subclasses to provide an implementation of the openDevTools
  /// method that can be called by a DTD client.
  FutureOr<void> openDevToolsPage(
    String debugSessionId,
    String? page,
    bool forceExternal,
  ) {}

  /// Overridden by subclasses to provide an implementation of the
  /// enablePlatformType method that can be called by a DTD client.
  FutureOr<void> enablePlatformType(String platformType) {}

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
class DtdEditorServer extends EditorServer {
  // TODO(dantup): Once the postMessage code is gone, merge DtdEditorServer and
  //  EditorServer to simplify things.
  DtdEditorServer(this._dtd) {
    unawaited(initialized); // Trigger async initialization.
  }

  final DartToolingDaemon _dtd;
  late final initialized = _initialize();

  Future<void> _initialize() {
    return Future.wait([
      _registerService(EditorMethod.getDevices, _getDevices),
      _registerService(EditorMethod.selectDevice, _selectDevice),
      _registerService(EditorMethod.hotReload, _hotReload),
      _registerService(EditorMethod.hotRestart, _hotRestart),
      _registerService(EditorMethod.openDevToolsPage, _openDevToolsPage),
      _registerService(EditorMethod.enablePlatformType, _enablePlatformType),
    ]);
  }

  /// Close the connection to DTD.
  @override
  Future<void> close() => _dtd.close();

  Future<void> _registerService(
    EditorMethod method,
    DTDServiceCallback callback,
  ) {
    return _dtd.registerService(editorServiceName, method.name, callback);
  }

  final _voidServiceResponse = {
    'type': '', // TODO(dantup): Why do we need this?
  };

  Future<Map<String, Object?>> _getDevices(Parameters params) {
    return Future.value({
      'type': '', // TODO(dantup): Why do we need this?
      'devices': getDevices(),
    });
  }

  Future<Map<String, Object?>> _selectDevice(Parameters params) async {
    await selectDevice(params['deviceId'].asString);
    return _voidServiceResponse;
  }

  Future<Map<String, Object?>> _hotReload(Parameters params) async {
    await hotReload(params['debugSessionId'].asString);
    return _voidServiceResponse;
  }

  Future<Map<String, Object?>> _hotRestart(Parameters params) async {
    await hotRestart(params['debugSessionId'].asString);
    return _voidServiceResponse;
  }

  Future<Map<String, Object?>> _openDevToolsPage(Parameters params) async {
    await openDevToolsPage(
      params['debugSessionId'].asString,
      params['page'].valueOr(null) as String?,
      params['forceExternal'].valueOr(null) as bool? ?? false,
    );
    return _voidServiceResponse;
  }

  Future<Map<String, Object?>> _enablePlatformType(Parameters params) async {
    await enablePlatformType(params['platformType'].asString);
    return _voidServiceResponse;
  }

  Future<void> _postEvent(EditorEvent params) {
    return _dtd.postEvent(editorStreamName, params.kind.name, params.toJson());
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
