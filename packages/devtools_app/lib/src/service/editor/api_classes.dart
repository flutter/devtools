// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';

/// Known kinds of events that may come from the editor.
///
/// This list is not guaranteed to match actual events from any given editor as
/// the editor might not implement all functionality or may be a future version
/// running against an older version of this code/DevTools.
enum EditorEventKind {
  // Devices.

  /// The kind for a [DeviceAddedEvent].
  deviceAdded,

  /// The kind for a [DeviceRemovedEvent].
  deviceRemoved,

  /// The kind for a [DeviceChangedEvent].
  deviceChanged,

  /// The kind for a [DeviceSelectedEvent].
  deviceSelected,

  // Debug Sessions.

  /// The kind for a [DebugSessionStartedEvent].
  debugSessionStarted,

  /// The kind for a [DebugSessionChangedEvent].
  debugSessionChanged,

  /// The kind for a [DebugSessionStoppedEvent].
  debugSessionStopped,
}

/// Constants for all fields used in JSON maps to avoid literal strings that
/// may have typos sprinkled throughout the API classes.
abstract class _Field {
  static const category = 'category';
  static const debuggerType = 'debuggerType';
  static const debugSession = 'debugSession';
  static const debugSessionId = 'debugSessionId';
  static const device = 'device';
  static const deviceId = 'deviceId';
  static const emulator = 'emulator';
  static const emulatorId = 'emulatorId';
  static const ephemeral = 'ephemeral';
  static const flutterDeviceId = 'flutterDeviceId';
  static const flutterMode = 'flutterMode';
  static const id = 'id';
  static const name = 'name';
  static const platform = 'platform';
  static const platformType = 'platformType';
  static const projectRootPath = 'projectRootPath';
  static const supported = 'supported';
  static const vmServiceUri = 'vmServiceUri';
}

/// A base class for all known events that an editor can produce.
///
/// The set of subclasses is not guaranteed to match actual events from any
/// given editor as the editor might not implement all functionality or may be a
/// future version running against an older version of this code/DevTools.
sealed class EditorEvent with Serializable {
  EditorEventKind get kind;
}

/// An event sent by an editor when a new device becomes available.
class DeviceAddedEvent extends EditorEvent {
  DeviceAddedEvent({required this.device});

  DeviceAddedEvent.fromJson(Map<String, Object?> map)
      : this(
          device:
              EditorDevice.fromJson(map[_Field.device] as Map<String, Object?>),
        );

  @override
  EditorEventKind get kind => EditorEventKind.deviceAdded;

  final EditorDevice device;

  @override
  Map<String, Object?> toJson() => {
        _Field.device: device,
      };

  @override
  bool operator ==(Object other) =>
      other is DeviceAddedEvent &&
      other.runtimeType == runtimeType &&
      other.device == device;

  @override
  int get hashCode => device.hashCode;
}

/// An event sent by an editor when an existing device is updated.
///
/// The ID in this event always matches an existing device (that is, the ID
/// never changes, or it would be considered a removal/add).
class DeviceChangedEvent extends EditorEvent {
  DeviceChangedEvent({required this.device});

  DeviceChangedEvent.fromJson(Map<String, Object?> map)
      : this(
          device:
              EditorDevice.fromJson(map[_Field.device] as Map<String, Object?>),
        );

  @override
  EditorEventKind get kind => EditorEventKind.deviceChanged;

  final EditorDevice device;

  @override
  Map<String, Object?> toJson() => {
        _Field.device: device,
      };

  @override
  bool operator ==(Object other) =>
      other is DeviceChangedEvent &&
      other.runtimeType == runtimeType &&
      other.device == device;

  @override
  int get hashCode => device.hashCode;
}

/// An event sent by an editor when a device is no longer available.
class DeviceRemovedEvent extends EditorEvent {
  DeviceRemovedEvent({required this.deviceId});

  DeviceRemovedEvent.fromJson(Map<String, Object?> map)
      : this(
          deviceId: map[_Field.deviceId] as String,
        );

  @override
  EditorEventKind get kind => EditorEventKind.deviceRemoved;

  final String deviceId;

  @override
  Map<String, Object?> toJson() => {
        _Field.deviceId: deviceId,
      };

  @override
  bool operator ==(Object other) =>
      other is DeviceRemovedEvent &&
      other.runtimeType == runtimeType &&
      other.deviceId == deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}

/// An event sent by an editor when the current selected device was changed.
/// This could be as a result of the client itself calling the `selectDevice`
/// method or because the device changed for another reason (such as the user
/// selecting a device in the editor directly, or the previously selected device
/// is being removed).
class DeviceSelectedEvent extends EditorEvent {
  DeviceSelectedEvent({required this.deviceId});

  DeviceSelectedEvent.fromJson(Map<String, Object?> map)
      : this(
          deviceId: map[_Field.deviceId] as String?,
        );

  @override
  EditorEventKind get kind => EditorEventKind.deviceSelected;

  /// The ID of the device being selected, or `null` if the current device is
  /// being unselected without a new device being selected.
  final String? deviceId;

  @override
  Map<String, Object?> toJson() => {
        _Field.deviceId: deviceId,
      };

  @override
  bool operator ==(Object other) =>
      other is DeviceSelectedEvent &&
      other.runtimeType == runtimeType &&
      other.deviceId == deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}

/// An event sent by an editor when a new debug session is started.
class DebugSessionStartedEvent extends EditorEvent {
  DebugSessionStartedEvent({required this.debugSession});

  DebugSessionStartedEvent.fromJson(Map<String, Object?> map)
      : this(
          debugSession: EditorDebugSession.fromJson(
            map[_Field.debugSession] as Map<String, Object?>,
          ),
        );

  @override
  EditorEventKind get kind => EditorEventKind.debugSessionStarted;

  final EditorDebugSession debugSession;

  @override
  Map<String, Object?> toJson() => {
        _Field.debugSession: debugSession,
      };

  @override
  bool operator ==(Object other) =>
      other is DebugSessionStartedEvent &&
      other.runtimeType == runtimeType &&
      other.debugSession == debugSession;

  @override
  int get hashCode => debugSession.hashCode;
}

/// An event sent by an editor when a debug session is started (for example the
/// VM Service URI becoming available).
class DebugSessionChangedEvent extends EditorEvent {
  DebugSessionChangedEvent({required this.debugSession});

  DebugSessionChangedEvent.fromJson(Map<String, Object?> map)
      : this(
          debugSession: EditorDebugSession.fromJson(
            map[_Field.debugSession] as Map<String, Object?>,
          ),
        );

  @override
  EditorEventKind get kind => EditorEventKind.debugSessionChanged;

  final EditorDebugSession debugSession;

  @override
  Map<String, Object?> toJson() => {
        _Field.debugSession: debugSession,
      };

  @override
  bool operator ==(Object other) =>
      other is DebugSessionChangedEvent &&
      other.runtimeType == runtimeType &&
      other.debugSession == debugSession;

  @override
  int get hashCode => debugSession.hashCode;
}

/// An event sent by an editor when a debug session ends.
class DebugSessionStoppedEvent extends EditorEvent {
  DebugSessionStoppedEvent({required this.debugSessionId});

  DebugSessionStoppedEvent.fromJson(Map<String, Object?> map)
      : this(
          debugSessionId: map[_Field.debugSessionId] as String,
        );

  @override
  EditorEventKind get kind => EditorEventKind.debugSessionStopped;

  final String debugSessionId;

  @override
  Map<String, Object?> toJson() => {
        _Field.debugSessionId: debugSessionId,
      };

  @override
  bool operator ==(Object other) =>
      other is DebugSessionStoppedEvent &&
      other.runtimeType == runtimeType &&
      other.debugSessionId == debugSessionId;

  @override
  int get hashCode => debugSessionId.hashCode;
}

/// A debug session running in the editor.
class EditorDebugSession {
  EditorDebugSession({
    required this.id,
    required this.name,
    required this.vmServiceUri,
    required this.flutterMode,
    required this.flutterDeviceId,
    required this.debuggerType,
    required this.projectRootPath,
  });

  EditorDebugSession.fromJson(Map<String, Object?> map)
      : this(
          id: map[_Field.id] as String,
          name: map[_Field.name] as String,
          vmServiceUri: map[_Field.vmServiceUri] as String?,
          flutterMode: map[_Field.flutterMode] as String?,
          flutterDeviceId: map[_Field.flutterDeviceId] as String?,
          debuggerType: map[_Field.debuggerType] as String?,
          projectRootPath: map[_Field.projectRootPath] as String?,
        );

  final String id;
  final String name;
  final String? vmServiceUri;
  final String? flutterMode;
  final String? flutterDeviceId;
  final String? debuggerType;
  final String? projectRootPath;

  Map<String, Object?> toJson() => {
        _Field.id: id,
        _Field.name: name,
        _Field.vmServiceUri: vmServiceUri,
        _Field.flutterMode: flutterMode,
        _Field.flutterDeviceId: flutterDeviceId,
        _Field.debuggerType: debuggerType,
        _Field.projectRootPath: projectRootPath,
      };

  @override
  bool operator ==(Object other) =>
      other is EditorDebugSession &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      other.name == name &&
      other.vmServiceUri == vmServiceUri &&
      other.flutterMode == flutterMode &&
      other.flutterDeviceId == flutterDeviceId &&
      other.debuggerType == debuggerType &&
      other.projectRootPath == projectRootPath;

  @override
  int get hashCode => Object.hashAll([
        id,
        name,
        vmServiceUri,
        flutterMode,
        flutterDeviceId,
        debuggerType,
        projectRootPath,
      ]);
}

/// A device that is available in the editor.
class EditorDevice {
  EditorDevice({
    required this.id,
    required this.name,
    required this.category,
    required this.emulator,
    required this.emulatorId,
    required this.ephemeral,
    required this.platform,
    required this.platformType,
    required this.supported,
  });

  EditorDevice.fromJson(Map<String, Object?> map)
      : this(
          id: map[_Field.id] as String,
          name: map[_Field.name] as String,
          category: map[_Field.category] as String?,
          emulator: map[_Field.emulator] as bool,
          emulatorId: map[_Field.emulatorId] as String?,
          ephemeral: map[_Field.ephemeral] as bool,
          platform: map[_Field.platform] as String,
          platformType: map[_Field.platformType] as String?,
          supported: map[_Field.supported] as bool,
        );

  final String id;
  final String name;
  final String? category;
  final bool emulator;
  final String? emulatorId;
  final bool ephemeral;
  final String platform;
  final String? platformType;

  /// Whether this device is supported for projects in the current workspace.
  ///
  /// If `false`, the `enablePlatformType` method can be used to ask the editor
  /// to enable it (which will trigger a deviceChanged event after the changes
  /// are made).
  final bool supported;

  Map<String, Object?> toJson() => {
        _Field.id: id,
        _Field.name: name,
        _Field.category: category,
        _Field.emulator: emulator,
        _Field.emulatorId: emulatorId,
        _Field.ephemeral: ephemeral,
        _Field.platform: platform,
        _Field.platformType: platformType,
        _Field.supported: supported,
      };

  @override
  bool operator ==(Object other) =>
      other is EditorDevice &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      other.name == name &&
      other.category == category &&
      other.emulator == emulator &&
      other.emulatorId == emulatorId &&
      other.ephemeral == ephemeral &&
      other.platform == platform &&
      other.platformType == platformType;

  @override
  int get hashCode => Object.hashAll([
        id,
        name,
        category,
        emulator,
        emulatorId,
        ephemeral,
        platform,
        platformType,
      ]);
}
