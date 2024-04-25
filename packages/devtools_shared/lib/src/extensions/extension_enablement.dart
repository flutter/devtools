// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'extension_model.dart';
import 'yaml_utils.dart';

/// Manages the `devtools_options.yaml` file and allows read / write access.
class DevToolsOptions {
  static const _extensionsKey = 'extensions';
  static const _descriptionKey = 'description';
  static const _documentationKey = 'documentation';
  static const _defaultOptions = '''
$_descriptionKey: This file stores settings for Dart & Flutter DevTools.
$_documentationKey: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
$_extensionsKey:
''';

  /// Returns the current enabled state for [extensionName] in the
  /// 'devtools_options.yaml' file at [devtoolsOptionsUri].
  ///
  /// If the 'devtools_options.yaml' file does not exist, it will be created
  /// with an empty set of extensions.
  ///
  /// [devtoolsOptionsUri] is expected to be a file:// URI.
  ExtensionEnabledState lookupExtensionEnabledState({
    required Uri devtoolsOptionsUri,
    required String extensionName,
  }) {
    final options = _optionsAsMap(optionsUri: devtoolsOptionsUri);
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
  /// 'devtools_options.yaml' file at [devtoolsOptionsUri].
  ///
  /// If the 'devtools_options.yaml' file does not exist, it will be created.
  ///
  /// [devtoolsOptionsUri] is expected to be a file:// URI.
  ExtensionEnabledState setExtensionEnabledState({
    required Uri devtoolsOptionsUri,
    required String extensionName,
    required bool enable,
  }) {
    final options = _optionsAsMap(optionsUri: devtoolsOptionsUri);
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

    _writeToOptionsFile(optionsUri: devtoolsOptionsUri, options: options);

    // Lookup the enabled state from the file we just wrote to to ensure that
    // are not returning an out of sync result.
    return lookupExtensionEnabledState(
      devtoolsOptionsUri: devtoolsOptionsUri,
      extensionName: extensionName,
    );
  }

  /// Returns the content of the `devtools_options.yaml` file at [optionsUri]
  /// as a Map.
  Map<String, Object?>? _optionsAsMap({required Uri optionsUri}) {
    final optionsFile = _lookupOptionsFile(optionsUri);
    if (optionsFile == null) return null;
    final yamlMap = loadYaml(optionsFile.readAsStringSync()) as YamlMap;
    return yamlMap.toDartMap();
  }

  /// Writes the `devtools_options.yaml` file at [optionsUri] with the value of
  /// [options] as YAML.
  ///
  /// Any existing content in `devtools_options.yaml` will be overwritten.
  void _writeToOptionsFile({
    required Uri optionsUri,
    required Map<String, Object?> options,
  }) {
    final yamlEditor = YamlEditor('');
    yamlEditor.update([], options);
    _lookupOptionsFile(optionsUri)?.writeAsStringSync(
      yamlEditor.toString(),
      flush: true,
    );
  }

  /// Returns the `devtools_options.yaml` file at [optionsUri].
  ///
  /// If the `devtools_options.yaml` does not already exist, it will be created
  /// and written with [_defaultOptions], and then returned.
  File? _lookupOptionsFile(Uri optionsUri) {
    final optionsFile = File.fromUri(optionsUri);
    if (!optionsFile.existsSync()) {
      optionsFile
        ..createSync(recursive: true)
        ..writeAsStringSync(_defaultOptions, flush: true);
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
