// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'api_classes.dart';

/// An interface to services provided by an editor.
///
/// Changes made to the editor services/events should be considered carefully to
/// ensure they are not breaking changes to already-shipped editors.
abstract class EditorClient {
  Future<void> close();
  bool get supportsGetDevices;
  bool get supportsSelectDevice;
  bool get supportsHotReload;
  bool get supportsHotRestart;
  bool get supportsOpenDevToolsPage;
  bool get supportsOpenDevToolsExternally;

  /// A stream of [EditorEvent]s from the editor.
  Stream<EditorEvent> get event;

  /// Gets the set of currently available devices from the editor.
  Future<List<EditorDevice>> getDevices();

  /// Gets the set of currently active debug sessions from the editor.
  Future<List<EditorDebugSession>> getDebugSessions();

  /// Requests the editor selects a specific device. It should not be assumed
  /// that calling this method succeeds (if it does, a `deviceSelected` event
  /// will provide the appropriate update).
  Future<void> selectDevice(EditorDevice? device);

  /// Requests the editor Hot Reloads the given debug session.
  Future<void> hotReload(String debugSessionId);

  /// Requests the editor Hot Restarts the given debug session.
  Future<void> hotRestart(String debugSessionId);

  /// Requests the editor opens a DevTools page for the given debug session.
  Future<void> openDevToolsPage(
    String? debugSessionId, {
    String? page,
    bool? forceExternal,
  });

  /// Requests the editor enables a new platform (for example by running
  /// `flutter create` to add the native project files).
  ///
  /// This action may prompt the user so it should not be assumed that calling
  /// this method succeeds (if it does, a `deviceChanged` event will provide
  /// the appropriate updates).
  Future<void> enablePlatformType(String platformType);
}
