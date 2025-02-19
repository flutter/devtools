// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_shared/devtools_shared.dart';

const editorServiceName = 'Editor';
const editorStreamName = 'Editor';
const lspServiceName = 'Lsp';

enum EditorMethod {
  // Device.
  getDevices,
  getDebugSessions,
  selectDevice,
  enablePlatformType,

  // Debug Session.
  hotReload,
  hotRestart,
  openDevToolsPage,
}

/// Method names of LSP requests registered on the Analysis Server.
///
/// These should be kept in sync with the methods defined at
/// [pkg/analysis_server/lib/src/lsp/constants.dart][code link]
///
/// [code link]: https://github.com/dart-lang/sdk/blob/ebfcd436da65802a2b20d415afe600b51e432305/pkg/analysis_server/lib/src/lsp/constants.dart#L136
///
/// TODO(https://github.com/flutter/devtools/issues/8824): Add tests that these
/// are in-sync with analysis_server.
enum LspMethod {
  editableArguments(methodName: 'dart/textDocument/editableArguments'),
  editArgument(methodName: 'dart/textDocument/editArgument');

  const LspMethod({required this.methodName});

  final String methodName;

  String get experimentalMethodName => 'experimental/$methodName';
}

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

  /// The kind for a [ThemeChangedEvent].
  themeChanged,

  /// The kind for an [ActiveLocationChangedEvent] event.
  activeLocationChanged,
}

/// Constants for all fields used in JSON maps to avoid literal strings that
/// may have typos sprinkled throughout the API classes.
abstract class Field {
  static const active = 'active';
  static const anchor = 'anchor';
  static const arguments = 'arguments';
  static const backgroundColor = 'backgroundColor';
  static const category = 'category';
  static const character = 'character';
  static const debuggerType = 'debuggerType';
  static const debugSession = 'debugSession';
  static const debugSessionId = 'debugSessionId';
  static const debugSessions = 'debugSessions';
  static const defaultValue = 'defaultValue';
  static const device = 'device';
  static const deviceId = 'deviceId';
  static const devices = 'devices';
  static const displayValue = 'displayValue';
  static const documentation = 'documentation';
  static const emulator = 'emulator';
  static const emulatorId = 'emulatorId';
  static const ephemeral = 'ephemeral';
  static const errorText = 'errorText';
  static const flutterDeviceId = 'flutterDeviceId';
  static const flutterMode = 'flutterMode';
  static const fontSize = 'fontSize';
  static const forceExternal = 'forceExternal';
  static const foregroundColor = 'foregroundColor';
  static const hasArgument = 'hasArgument';
  static const id = 'id';
  static const isDarkMode = 'isDarkMode';
  static const isEditable = 'isEditable';
  static const isNullable = 'isNullable';
  static const isRequired = 'isRequired';
  static const line = 'line';
  static const name = 'name';
  static const options = 'options';
  static const page = 'page';
  static const platform = 'platform';
  static const platformType = 'platformType';
  static const prefersDebugSession = 'prefersDebugSession';
  static const projectRootPath = 'projectRootPath';
  static const requiresDebugSession = 'requiresDebugSession';
  static const result = 'result';
  static const selectedDeviceId = 'selectedDeviceId';
  static const selections = 'selections';
  static const supported = 'supported';
  static const supportsForceExternal = 'supportsForceExternal';
  static const textDocument = 'textDocument';
  static const theme = 'theme';
  static const type = 'type';
  static const uri = 'uri';
  static const value = 'value';
  static const version = 'version';
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
        device: EditorDevice.fromJson(
          map[Field.device] as Map<String, Object?>,
        ),
      );

  final EditorDevice device;

  @override
  EditorEventKind get kind => EditorEventKind.deviceAdded;

  @override
  Map<String, Object?> toJson() => {Field.device: device};
}

/// An event sent by an editor when an existing device is updated.
///
/// The ID in this event always matches an existing device (that is, the ID
/// never changes, or it would be considered a removal/add).
class DeviceChangedEvent extends EditorEvent {
  DeviceChangedEvent({required this.device});

  DeviceChangedEvent.fromJson(Map<String, Object?> map)
    : this(
        device: EditorDevice.fromJson(
          map[Field.device] as Map<String, Object?>,
        ),
      );

  final EditorDevice device;

  @override
  EditorEventKind get kind => EditorEventKind.deviceChanged;

  @override
  Map<String, Object?> toJson() => {Field.device: device};
}

/// An event sent by an editor when a device is no longer available.
class DeviceRemovedEvent extends EditorEvent {
  DeviceRemovedEvent({required this.deviceId});

  DeviceRemovedEvent.fromJson(Map<String, Object?> map)
    : this(deviceId: map[Field.deviceId] as String);

  final String deviceId;

  @override
  EditorEventKind get kind => EditorEventKind.deviceRemoved;

  @override
  Map<String, Object?> toJson() => {Field.deviceId: deviceId};
}

/// An event sent by an editor when the current selected device was changed.
///
/// This could be as a result of the client itself calling the `selectDevice`
/// method or because the device changed for another reason (such as the user
/// selecting a device in the editor directly, or the previously selected device
/// is being removed).
class DeviceSelectedEvent extends EditorEvent {
  DeviceSelectedEvent({required this.deviceId});

  DeviceSelectedEvent.fromJson(Map<String, Object?> map)
    : this(deviceId: map[Field.deviceId] as String?);

  /// The ID of the device being selected, or `null` if the current device is
  /// being unselected without a new device being selected.
  final String? deviceId;

  @override
  EditorEventKind get kind => EditorEventKind.deviceSelected;

  @override
  Map<String, Object?> toJson() => {Field.deviceId: deviceId};
}

/// An event sent by an editor when a new debug session is started.
class DebugSessionStartedEvent extends EditorEvent {
  DebugSessionStartedEvent({required this.debugSession});

  DebugSessionStartedEvent.fromJson(Map<String, Object?> map)
    : this(
        debugSession: EditorDebugSession.fromJson(
          map[Field.debugSession] as Map<String, Object?>,
        ),
      );

  final EditorDebugSession debugSession;

  @override
  EditorEventKind get kind => EditorEventKind.debugSessionStarted;

  @override
  Map<String, Object?> toJson() => {Field.debugSession: debugSession};
}

/// An event sent by an editor when a debug session is changed (for example the
/// VM Service URI becoming available).
class DebugSessionChangedEvent extends EditorEvent {
  DebugSessionChangedEvent({required this.debugSession});

  DebugSessionChangedEvent.fromJson(Map<String, Object?> map)
    : this(
        debugSession: EditorDebugSession.fromJson(
          map[Field.debugSession] as Map<String, Object?>,
        ),
      );

  final EditorDebugSession debugSession;

  @override
  EditorEventKind get kind => EditorEventKind.debugSessionChanged;

  @override
  Map<String, Object?> toJson() => {Field.debugSession: debugSession};
}

/// An event sent by an editor when a debug session ends.
class DebugSessionStoppedEvent extends EditorEvent {
  DebugSessionStoppedEvent({required this.debugSessionId});

  DebugSessionStoppedEvent.fromJson(Map<String, Object?> map)
    : this(debugSessionId: map[Field.debugSessionId] as String);

  final String debugSessionId;

  @override
  EditorEventKind get kind => EditorEventKind.debugSessionStopped;

  @override
  Map<String, Object?> toJson() => {Field.debugSessionId: debugSessionId};
}

class ThemeChangedEvent extends EditorEvent {
  ThemeChangedEvent({required this.theme});

  ThemeChangedEvent.fromJson(Map<String, Object?> map)
    : this(
        theme: EditorTheme.fromJson(map[Field.theme] as Map<String, Object?>),
      );

  final EditorTheme theme;

  @override
  EditorEventKind get kind => EditorEventKind.themeChanged;

  @override
  Map<String, Object?> toJson() => {Field.theme: theme};
}

/// An event sent by an editor when the current cursor position/s change.
class ActiveLocationChangedEvent extends EditorEvent {
  ActiveLocationChangedEvent({
    required this.selections,
    required this.textDocument,
  });

  ActiveLocationChangedEvent.fromJson(Map<String, Object?> map)
    : this(
        textDocument: TextDocument.fromJson(
          map[Field.textDocument] as Map<String, Object?>,
        ),
        selections:
            (map[Field.selections] as List<Object?>)
                .cast<Map<String, Object?>>()
                .map(EditorSelection.fromJson)
                .toList(),
      );

  final List<EditorSelection> selections;
  final TextDocument? textDocument;

  @override
  EditorEventKind get kind => EditorEventKind.activeLocationChanged;

  @override
  Map<String, Object?> toJson() => {
    Field.selections: selections,
    Field.textDocument: textDocument,
  };
}

/// A reference to a text document in the editor.
///
/// The [uriAsString] is a file URI to the text document.
///
/// The [version] is an integer corresponding to LSP's
/// [VersionedTextDocumentIdentifier](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#versionedTextDocumentIdentifier)
class TextDocument with Serializable {
  TextDocument({required this.uriAsString, required this.version});

  TextDocument.fromJson(Map<String, Object?> map)
    : this(
        uriAsString: map[Field.uri] as String,
        version: map[Field.version] as int?,
      );

  final String uriAsString;
  final int? version;

  @override
  Map<String, Object?> toJson() => {
    Field.uri: uriAsString,
    Field.version: version,
  };

  @override
  bool operator ==(Object other) {
    return other is TextDocument &&
        other.uriAsString == uriAsString &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(uriAsString, version);
}

/// The starting and ending cursor positions in the editor.
class EditorSelection with Serializable {
  EditorSelection({required this.active, required this.anchor});

  EditorSelection.fromJson(Map<String, Object?> map)
    : this(
        active: CursorPosition.fromJson(
          map[Field.active] as Map<String, Object?>,
        ),
        anchor: CursorPosition.fromJson(
          map[Field.anchor] as Map<String, Object?>,
        ),
      );

  final CursorPosition active;
  final CursorPosition anchor;

  @override
  Map<String, Object?> toJson() => {
    Field.active: active.toJson(),
    Field.anchor: anchor.toJson(),
  };
}

/// Representation of a single cursor position in the editor.
///
/// The cursor position is after the given [character] of the [line].
class CursorPosition with Serializable {
  CursorPosition({required this.character, required this.line});

  CursorPosition.fromJson(Map<String, Object?> map)
    : this(
        character: map[Field.character] as int,
        line: map[Field.line] as int,
      );

  /// The zero-based character number of this position.
  final int character;

  /// The zero-based line number of this position.
  final int line;

  @override
  Map<String, Object?> toJson() => {
    Field.character: character,
    Field.line: line,
  };

  @override
  bool operator ==(Object other) {
    return other is CursorPosition &&
        other.character == character &&
        other.line == line;
  }

  @override
  int get hashCode => Object.hash(character, line);
}

/// The result of an `editableArguments` request.
class EditableArgumentsResult with Serializable {
  EditableArgumentsResult({required this.args, this.name, this.documentation});

  EditableArgumentsResult.fromJson(Map<String, Object?> map)
    : this(
        name: map[Field.name] as String?,
        documentation: map[Field.documentation] as String?,
        args:
            (map[Field.arguments] as List<Object?>? ?? <Object?>[])
                .cast<Map<String, Object?>>()
                .map(EditableArgument.fromJson)
                .toList(),
      );

  final List<EditableArgument> args;
  final String? name;
  final String? documentation;

  @override
  Map<String, Object?> toJson() => {Field.arguments: args};
}

/// Errors that the Analysis Server returns for failed argument edits.
///
/// These should be kept in sync with the error coes defined at
/// [pkg/analysis_server/lib/src/lsp/constants.dart][code link]
///
/// [code link]: https://github.com/dart-lang/sdk/blob/35a10987e1652b7d49991ab2dc2ee7f521fe8d8f/pkg/analysis_server/lib/src/lsp/constants.dart#L300
///
/// TODO(https://github.com/flutter/devtools/issues/8824): Add tests that these
/// are in-sync with analysis_server.
enum EditArgumentError {
  /// A request was made that requires use of workspace/applyEdit but the
  /// current editor does not support it.
  editsUnsupportedByEditor(
    code: -32016,
    message: 'IDE does not support property edits.',
  ),

  /// An editArgument request tried to modify an invocation at a position where
  /// there was no invocation.
  editArgumentInvalidPosition(
    code: -32017,
    message: 'Invalid position for argument.',
  ),

  /// An editArgument request tried to modify a parameter that does not exist or
  /// is not editable.
  editArgumentInvalidParameter(code: -32018, message: 'Invalid parameter.'),

  /// An editArgument request tried to set an argument value that is not valid.
  editArgumentInvalidValue(
    code: -32019,
    message: 'Invalid value for parameter.',
  );

  const EditArgumentError({required this.code, required this.message});

  final int code;
  final String message;

  static final _codeToErrorMap = EditArgumentError.values.fold(
    <int, EditArgumentError>{},
    (map, error) {
      map[error.code] = error;
      return map;
    },
  );

  static EditArgumentError? fromCode(int? code) {
    if (code == null) return null;
    return _codeToErrorMap[code];
  }
}

/// Response to an edit argument request.
class EditArgumentResponse {
  EditArgumentResponse({required this.success, this.errorMessage, errorCode})
    : _errorCode = errorCode;

  final bool success;
  final String? errorMessage;
  final int? _errorCode;

  EditArgumentError? get errorType => EditArgumentError.fromCode(_errorCode);
}

/// Information about a single editable argument of a widget.
class EditableArgument with Serializable {
  EditableArgument({
    required this.name,
    required this.type,
    required this.hasArgument,
    required this.isNullable,
    required this.isRequired,
    required this.isEditable,
    required this.hasDefault,
    this.options,
    this.value,
    this.defaultValue,
    this.displayValue,
    this.errorText,
  });

  EditableArgument.fromJson(Map<String, Object?> map)
    : this(
        name: map[Field.name] as String,
        type: map[Field.type] as String,
        hasArgument: (map[Field.hasArgument] as bool?) ?? false,
        isNullable: (map[Field.isNullable] as bool?) ?? false,
        isRequired: (map[Field.isRequired] as bool?) ?? false,
        isEditable: (map[Field.isEditable] as bool?) ?? true,
        hasDefault: map.containsKey(Field.defaultValue),
        options: (map[Field.options] as List<Object?>?)?.cast<String>(),
        value: map[Field.value],
        defaultValue: map[Field.defaultValue],
        displayValue: map[Field.displayValue] as String?,
        errorText: map[Field.errorText] as String?,
      );

  /// The name of the corresponding parameter.
  final String name;

  /// The type of the corresponding parameter.
  ///
  /// This is not necessarily the Dart type, it is from a defined set of values
  /// that clients may understand how to edit.
  final String type;

  /// The current value for this argument.
  final Object? value;

  /// Whether an explicit argument exists for this parameter in the code.
  final bool hasArgument;

  /// Whether this argument can be `null`.
  final bool isNullable;

  /// Whether this argument is required.
  final bool isRequired;

  /// Whether this argument can be edited by the Analysis Server.
  ///
  /// An argument might not be editable, e.g. if it is a positional parameter
  /// where previous positional parameters have no argument.
  final bool isEditable;

  /// A list of values that could be provided for this argument.
  ///
  /// This will only be included if the parameter's [type] is "enum".
  final List<String>? options;

  /// Whether the argument has an explicit default value.
  ///
  /// This is used to distinguish whether the [defaultValue] is actually `null`
  /// or is not provided.
  final bool hasDefault;

  /// The default value for this parameter.
  final Object? defaultValue;

  /// A string that can be displayed to indicate the value for this argument.
  ///
  /// This is populated in cases where the source code is not literally the same
  /// as the value field, for example an expression or named constant.
  final String? displayValue;

  final String? errorText;

  String get valueDisplay => displayValue ?? currentValue.toString();

  bool get isDefault => hasDefault && currentValue == defaultValue;

  Object? get currentValue => hasArgument ? value : defaultValue;

  @override
  Map<String, Object?> toJson() => {
    Field.name: name,
    Field.type: type,
    Field.value: value,
    Field.hasArgument: hasArgument,
    Field.defaultValue: defaultValue,
    Field.isNullable: isNullable,
    Field.isRequired: isRequired,
    Field.isEditable: isEditable,
    Field.options: options,
    Field.displayValue: displayValue,
    Field.errorText: errorText,
  };
}

/// The result of a `GetDevices` request.
class GetDevicesResult with Serializable {
  GetDevicesResult({required this.devices, required this.selectedDeviceId});

  GetDevicesResult.fromJson(Map<String, Object?> map)
    : this(
        devices:
            (map[Field.devices] as List<Object?>)
                .cast<Map<String, Object?>>()
                .map(EditorDevice.fromJson)
                .toList(),
        selectedDeviceId: map[Field.selectedDeviceId] as String?,
      );

  final List<EditorDevice> devices;
  final String? selectedDeviceId;

  @override
  Map<String, Object?> toJson() => {
    Field.devices: devices,
    Field.selectedDeviceId: selectedDeviceId,
  };
}

/// The result of a `GetDebugSessions` request.
class GetDebugSessionsResult with Serializable {
  GetDebugSessionsResult({required this.debugSessions});

  GetDebugSessionsResult.fromJson(Map<String, Object?> map)
    : this(
        debugSessions:
            (map[Field.debugSessions] as List<Object?>)
                .cast<Map<String, Object?>>()
                .map(EditorDebugSession.fromJson)
                .toList(),
      );

  final List<EditorDebugSession> debugSessions;

  @override
  Map<String, Object?> toJson() => {Field.debugSessions: debugSessions};
}

/// A debug session running in the editor.
class EditorDebugSession with Serializable {
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
        id: map[Field.id] as String,
        name: map[Field.name] as String,
        vmServiceUri: map[Field.vmServiceUri] as String?,
        flutterMode: map[Field.flutterMode] as String?,
        flutterDeviceId: map[Field.flutterDeviceId] as String?,
        debuggerType: map[Field.debuggerType] as String?,
        projectRootPath: map[Field.projectRootPath] as String?,
      );

  final String id;
  final String name;
  final String? vmServiceUri;
  final String? flutterMode;
  final String? flutterDeviceId;
  final String? debuggerType;
  final String? projectRootPath;

  @override
  Map<String, Object?> toJson() => {
    Field.id: id,
    Field.name: name,
    Field.vmServiceUri: vmServiceUri,
    Field.flutterMode: flutterMode,
    Field.flutterDeviceId: flutterDeviceId,
    Field.debuggerType: debuggerType,
    Field.projectRootPath: projectRootPath,
  };
}

/// A device that is available in the editor.
class EditorDevice with Serializable {
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
        id: map[Field.id] as String,
        name: map[Field.name] as String,
        category: map[Field.category] as String?,
        emulator: map[Field.emulator] as bool,
        emulatorId: map[Field.emulatorId] as String?,
        ephemeral: map[Field.ephemeral] as bool,
        platform: map[Field.platform] as String,
        platformType: map[Field.platformType] as String?,
        supported: map[Field.supported] as bool,
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

  @override
  Map<String, Object?> toJson() => {
    Field.id: id,
    Field.name: name,
    Field.category: category,
    Field.emulator: emulator,
    Field.emulatorId: emulatorId,
    Field.ephemeral: ephemeral,
    Field.platform: platform,
    Field.platformType: platformType,
    Field.supported: supported,
  };
}

/// UI settings for an editor's theme.
class EditorTheme with Serializable {
  EditorTheme({
    required this.isDarkMode,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.fontSize,
  });

  EditorTheme.fromJson(Map<String, Object?> map)
    : this(
        isDarkMode: map[Field.isDarkMode] as bool,
        backgroundColor: map[Field.backgroundColor] as String?,
        foregroundColor: map[Field.foregroundColor] as String?,
        fontSize: map[Field.fontSize] as int?,
      );

  final bool isDarkMode;
  final String? backgroundColor;
  final String? foregroundColor;
  final int? fontSize;

  @override
  Map<String, Object?> toJson() => {
    Field.isDarkMode: isDarkMode,
    Field.backgroundColor: backgroundColor,
    Field.foregroundColor: foregroundColor,
    Field.fontSize: fontSize,
  };
}
