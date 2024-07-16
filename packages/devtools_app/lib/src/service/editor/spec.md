# TODO(dantup): Move this to the SDK with other editor service descriptions.

# Methods

- `GetDevicesResult getDevices()`
- `GetDebugSessionsResult getDebugSessions()`
- `Success selectDevice(SelectDeviceParams)`
- `Success enablePlatformType(EnablePlatformTypeParams)`
- `Success hotReload()`
- `Success hotRestart()`
- `Success openDevToolsPage(OpenDevToolsPageParams)`

# Event Kinds

- `deviceAdded` (`DeviceAddedEvent`)
- `deviceRemoved` (`DeviceRemovedEvent`)
- `deviceChanged` (`DeviceChangedEvent`)
- `deviceSelected` (`DeviceSelectedEvent`)
- `debugSessionStarted` (`DebugSessionStartedEvent`)
- `debugSessionStopped` (`DebugSessionStoppedEvent`)
- `debugSessionChanged` (`DebugSessionChangedEvent`)

# Types

```dart
/// An event sent by an editor when a new device becomes available.
class DeviceAddedEvent {
  EditorDevice device;
}

/// An event sent by an editor when an existing device is updated.
///
/// The ID in this event always matches an existing device (that is, the ID
/// never changes, or it would be considered a removal/add).
interface class DeviceChangedEvent extends EditorEvent {
  EditorDevice device;
}

/// An event sent by an editor when a device is no longer available.
class DeviceRemovedEvent extends EditorEvent {
  String deviceId;
}

/// An event sent by an editor when the current selected device was changed.
///
/// This could be as a result of the client itself calling the `selectDevice`
/// method or because the device changed for another reason (such as the user
/// selecting a device in the editor directly, or the previously selected device
/// is being removed).
class DeviceSelectedEvent extends EditorEvent {
  /// The ID of the device being selected, or `null` if the current device is
  /// being unselected without a new device being selected.
  String? deviceId;
}

/// An event sent by an editor when a new debug session is started.
class DebugSessionStartedEvent extends EditorEvent {
  EditorDebugSession debugSession;
}

/// An event sent by an editor when a debug session is changed.
/// 
/// This could be happen when a VM Service URI becomes available for a session
/// launched in debug mode, for example.
class DebugSessionChangedEvent extends EditorEvent {
  EditorDebugSession debugSession;
}

/// An event sent by an editor when a debug session ends.
class DebugSessionStoppedEvent extends EditorEvent {
  String debugSessionId;
}

/// The result of a `GetDevices` request.
class GetDevicesResult with Serializable {
  /// The current available devices.
  List<EditorDevice> devices;
  /// The ID of the device that is currently selected, if any.
  String? selectedDeviceId;
}

/// The result of a `GetDebugSessions` request.
class GetDebugSessionsResult with Serializable {
  /// The current active debug sessions.
  final List<EditorDebugSession> debugSessions;
}

/// A debug session running in the editor.
class EditorDebugSession with Serializable {
  String id;
  String name;
  String? vmServiceUri;
  String? flutterMode;
  String? flutterDeviceId;
  String? debuggerType;
  String? projectRootPath;
}

/// A device that is available in the editor.
class EditorDevice {
  String id;
  String name;
  String? category;
  bool emulator;
  String? emulatorId;
  bool ephemeral;
  String platform;
  String? platformType;

  /// Whether this device is supported for projects in the current workspace.
  ///
  /// If `false`, the `enablePlatformType` method can be used to ask the editor
  /// to enable it (which will trigger a `deviceChanged` event after the changes
  /// are made).
  bool supported;
}
```
