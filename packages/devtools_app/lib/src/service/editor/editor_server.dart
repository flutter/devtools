// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'api_classes.dart';
import 'editor_client.dart';

/// A base for classes that can act as an Editor (agnostic to the communication
/// channel).
///
/// This class is for the part of an editor connected to DTD that is providing
/// the editor services. It is the opposite of [EditorClient] which is for
/// consuming the services provided by the editor(server).
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
