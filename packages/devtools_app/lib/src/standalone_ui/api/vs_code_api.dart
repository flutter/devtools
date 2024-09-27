// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../service/editor/api_classes.dart';

/// This class defines the API exposed by the Dart/Flutter extensions in VS
/// Code (and must match the implementation there).
///
/// All changes to this file should be backwards-compatible and use
/// [VsCodeCapabilities] to advertise which capabilities are available and
/// handle any changes in behaviour.
abstract interface class VsCodeApi {
  /// The capabilities of the instance of VS Code / Dart VS Code extension that
  /// we are connected to.
  ///
  /// All API calls should be guarded by checks of capabilities because the API
  /// may change over time.
  VsCodeCapabilities get capabilities;

  /// Informs the VS Code extension we are initialized, allowing it to send
  /// initial events to all streams with an initial set of data.
  Future<void> initialize();

  /// A stream of events for whenever the set of devices (or selected device)
  /// change in VS Code.
  ///
  /// An event with initial devices is sent after [initialize] is called.
  Stream<VsCodeDevicesEvent> get devicesChanged;

  /// A stream of events for whenever the set of debug sessions change or are
  /// updated in VS Code.
  ///
  /// An event with initial sessions is sent after [initialize] is called.
  Stream<VsCodeDebugSessionsEvent> get debugSessionsChanged;

  /// Changes the current Flutter device.
  ///
  /// The selected device is the same one shown in the status bar in VS Code.
  /// Calling this API will update the device for the whole VS Code extension.
  Future<bool> selectDevice(String id);

  /// Enables the selected platform type.
  ///
  /// Calling this method may cause a UI prompt in the editor to ask the user to
  /// confirm they'd like to run `flutter create` to create the required files
  /// for the project to support this platform type.
  ///
  /// This method has no capability because it is only (and always) valid to
  /// call if some `unsupportedDevices` were provided in a device event.
  Future<bool> enablePlatformType(String platformType);

  /// Opens a specific DevTools [page] for the debug session with ID
  /// [debugSessionId].
  ///
  /// Depending on user settings, this may open embedded (the default) or in an
  /// external browser window.
  ///
  /// If [debugSessionId] is `null` the [requiresDebugSession] flag will
  /// indicate whether the editor must select (or ask the user) for a debug
  /// session. If [requiresDebugSession] is `false` but [prefersDebugSession] is
  /// `true`, then the editor should use or prompt for a debug session if one
  /// is available, but otherwise launch without a debug session.
  ///
  /// If [requiresDebugSession] is `null` (or if the
  /// `openDevToolsWithOptionalDebugSessionFlags` capability is `false`) then
  /// the editor will try to make this decision automatically (which may be
  /// inaccurate for pages it does not know about, like extensions).
  Future<void> openDevToolsPage(
    String? debugSessionId, {
    String? page,
    bool? forceExternal,
    bool? requiresDebugSession,
    bool? prefersDebugSession,
  });

  /// Sends a Hot Reload request to the debug session with ID [debugSessionId].
  Future<void> hotReload(String debugSessionId);

  /// Sends a Hot Restart request to the debug session with ID [debugSessionId].
  Future<void> hotRestart(String debugSessionId);

  static const jsonApiName = 'vsCode';

  static const jsonInitializeMethod = 'initialize';

  static const jsonSelectDeviceMethod = 'selectDevice';
  static const jsonOpenDevToolsPageMethod = 'openDevToolsPage';
  static const jsonHotReloadMethod = 'hotReload';
  static const jsonHotRestartMethod = 'hotRestart';
  static const jsonEnablePlatformTypeMethod = 'enablePlatformType';

  static const jsonDevicesChangedEvent = 'devicesChanged';
  static const jsonDebugSessionsChangedEvent = 'debugSessionsChanged';

  static const jsonCommandParameter = 'command';
  static const jsonArgumentsParameter = 'arguments';
  static const jsonIdParameter = 'id';
  static const jsonPageParameter = 'page';
  static const jsonForceExternalParameter = 'forceExternal';
  static const jsonDebugSessionIdParameter = 'debugSessionId';
  static const jsonPlatformTypeParameter = 'platformType';
  static const jsonRequiresDebugSessionParameter = 'requiresDebugSession';
  static const jsonPrefersDebugSessionParameter = 'prefersDebugSession';
}

/// This class defines a device event sent by the Dart/Flutter extensions in VS
/// Code (and must match the implementation there).
///
/// All changes to this file should be backwards-compatible and use
/// [VsCodeCapabilities] to advertise which capabilities are available and
/// handle any changes in behaviour.
abstract interface class VsCodeDevicesEvent {
  /// The ID of the selected Flutter device in VS Code.
  ///
  /// This device can be changed with the `selectDevice` method but can also
  /// be changed by the VS Code extension (which will emit a new event).
  String? get selectedDeviceId;

  /// A list of the devices that are available to select.
  List<EditorDevice> get devices;

  /// A list of the devices that are unavailable to select because the platform
  /// is not enabled.
  ///
  /// A devices platform type can be enabled by calling the `enablePlatformType`
  /// method.
  ///
  /// This field is nullable because it was not in the initial sidebar API so
  /// older versions of VS Code might not provide it.
  List<EditorDevice>? get unsupportedDevices;

  static const jsonSelectedDeviceIdField = 'selectedDeviceId';
  static const jsonDevicesField = 'devices';
  static const jsonUnsupportedDevicesField = 'unsupportedDevices';
}

/// This class defines a debug session event sent by the Dart/Flutter extensions
/// in VS Code (and must match the implementation there).
///
/// All changes to this file should be backwards-compatible and use
/// [VsCodeCapabilities] to advertise which capabilities are available and
/// handle any changes in behaviour.
abstract interface class VsCodeDebugSessionsEvent {
  /// A list of debug sessions that are currently active in VS Code.
  List<EditorDebugSession> get sessions;

  static const jsonSessionsField = 'sessions';
}

/// This class defines the capabilities provided by the current version of the
/// Dart/Flutter extensions in VS Code.
///
/// All changes to this file should be backwards-compatible and use
/// [VsCodeCapabilities] to advertise which capabilities are available and
/// handle any changes in behaviour.
abstract interface class VsCodeCapabilities {
  /// Whether the `selectDevice` method is available to call to change the
  /// selected Flutter device.
  bool get selectDevice;

  /// Whether the `openDevToolsPage` method is available call to open a specific
  /// DevTools page.
  bool get openDevToolsPage;

  /// Whether the `openDevToolsPage` method can be called without a `page`
  /// argument and with a 'forceExternal` flag to open DevTools in a browser
  /// regardless of user settings.
  bool get openDevToolsExternally;

  /// Whether the `openDevToolsPage` method can be called with the
  /// `requiresDebugSession` and `prefersDebugSession` flags to indicate
  /// whether the editor should select/prompt for a debug session if one was not
  /// provided.
  bool get openDevToolsWithOptionalDebugSessionFlags;

  /// Whether the `hotReload` method is available call to hot reload a specific
  /// debug session.
  bool get hotReload;

  /// Whether the `hotRestart` method is available call to restart a specific
  /// debug session.
  bool get hotRestart;

  static const jsonSelectDeviceField = 'selectDevice';
  static const openDevToolsPageField = 'openDevToolsPage';
  static const openDevToolsExternallyField = 'openDevToolsExternally';
  static const openDevToolsWithOptionalDebugSessionFlagsField =
      'openDevToolsWithOptionalDebugSessionFlags';
  static const hotReloadField = 'hotReload';
  static const hotRestartField = 'hotRestart';
}
