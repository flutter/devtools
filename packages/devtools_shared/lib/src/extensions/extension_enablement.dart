// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'extension_model.dart';

/// Manages the `devtools_options.yaml` file and allows read / write access.
class DevToolsOptions {
  static const optionsFileName = 'devtools_options.yaml';

  static const _extensionsKey = 'extensions';

  static const _defaultOptions = '''
$_extensionsKey:
''';

  /// Returns the current enabled state for [extensionName] in the
  /// 'devtools_options.yaml' file at [rootUri].
  ///
  /// If the 'devtools_options.yaml' file does not exist, it will be created
  /// with an empty set of extensions.
  ExtensionEnabledState lookupExtensionEnabledState({
    required Uri rootUri,
    required String extensionName,
  }) {
    final options = _optionsAsMap(rootUri: rootUri);
    if (options == null) return ExtensionEnabledState.error;

    final extensions =
        (options[_extensionsKey] as List?)?.cast<Map<String, Object?>>();
    if (extensions == null) return ExtensionEnabledState.none;

    for (final e in extensions) {
      // Each entry should only have one key / value pair (e.g. '- foo: true').
      assert(e.keys.length == 1);

      if (e.keys.first == extensionName) {
        return _extensionStateForValue(e[extensionName]);
      }
    }
    return ExtensionEnabledState.none;
  }

  /// Sets the enabled state for [extensionName] in the
  /// 'devtools_options.yaml' file at [rootUri].
  ///
  /// If the 'devtools_options.yaml' file does not exist, it will be created.
  ExtensionEnabledState setExtensionEnabledState({
    required Uri rootUri,
    required String extensionName,
    required bool enable,
  }) {
    final options = _optionsAsMap(rootUri: rootUri);
    if (options == null) return ExtensionEnabledState.error;

    var extensions =
        (options[_extensionsKey] as List?)?.cast<Map<String, Object?>>();
    if (extensions == null) {
      options[_extensionsKey] = <Map<String, Object?>>[];
      extensions = options[_extensionsKey] as List<Map<String, Object?>>;
    }

    // Write the new enabled state to the map.
    final extension = extensions.firstWhereOrNull(
      (e) => e.keys.first == extensionName,
    );
    if (extension == null) {
      extensions.add({extensionName: enable});
    } else {
      extension[extensionName] = enable;
    }

    _writeToOptionsFile(rootUri: rootUri, options: options);

    // Lookup the enabled state from the file we just wrote to to ensure that
    // are not returning an out of sync result.
    return lookupExtensionEnabledState(
      rootUri: rootUri,
      extensionName: extensionName,
    );
  }

  /// Returns the content of the `devtools_options.yaml` file at [rootUri] as a
  /// Map.
  Map<String, Object?>? _optionsAsMap({required Uri rootUri}) {
    final optionsFile = _lookupOptionsFile(rootUri);
    if (optionsFile == null) return null;
    final yamlMap = loadYaml(optionsFile.readAsStringSync()) as YamlMap;
    return yamlMap.toDartMap();
  }

  /// Writes the `devtools_options.yaml` file at [rootUri] with the value of
  /// [options] as YAML.
  ///
  /// Any existing content in `devtools_options.yaml` will be overwritten.
  void _writeToOptionsFile({
    required Uri rootUri,
    required Map<String, Object?> options,
  }) {
    final yamlEditor = YamlEditor('');
    yamlEditor.update([], options);
    _lookupOptionsFile(rootUri)?.writeAsStringSync(yamlEditor.toString());
  }

  /// Returns the `devtools_options.yaml` file in the [rootUri] directory.
  ///
  /// Returns null if the directory at [rootUri] does not exist. Otherwise, if
  /// the `devtools_options.yaml` does not already exist, it will be created
  /// and written with [_defaultOptions], and then returned.
  File? _lookupOptionsFile(Uri rootUri) {
    final rootDir = Directory.fromUri(rootUri);
    if (!rootDir.existsSync()) {
      print('Directory does not exist at path: ${rootUri.toString()}');
      return null;
    }

    final optionsFile = File(path.join(rootDir.path, optionsFileName));
    if (!optionsFile.existsSync()) {
      optionsFile
        ..createSync()
        ..writeAsStringSync(_defaultOptions);
    }
    return optionsFile;
  }

  ExtensionEnabledState _extensionStateForValue(Object? value) {
    switch (value) {
      case true:
        return ExtensionEnabledState.enabled;
      case false:
        return ExtensionEnabledState.disabled;
      default:
        return ExtensionEnabledState.none;
    }
  }
}

extension YamlExtension on YamlMap {
  Map<String, Object?> toDartMap() {
    final map = <String, Object?>{};
    for (final entry in nodes.entries) {
      map[entry.key.toString()] = entry.value.convertToDartType();
    }
    return map;
  }
}

extension YamlListExtension on YamlList {
  List<Object?> toDartList() {
    final list = <Object>[];
    for (final e in nodes) {
      final element = e.convertToDartType();
      if (element != null) list.add(element);
    }
    return list;
  }
}

extension YamlNodeExtension on YamlNode {
  Object? convertToDartType() {
    return switch (this) {
      YamlMap() => (this as YamlMap).toDartMap(),
      YamlList() => (this as YamlList).toDartList(),
      _ => value,
    };
  }
}
