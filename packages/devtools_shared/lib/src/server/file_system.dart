// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'devtools_store.dart';

// ignore: avoid_classes_with_only_static_members, requires refactor.
class LocalFileSystem {
  static String _userHomeDir() {
    final envKey = Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
    return Platform.environment[envKey] ?? '.';
  }

  /// Returns the path to the DevTools storage directory.
  static String devToolsDir() {
    return path.join(_userHomeDir(), '.flutter-devtools');
  }

  /// Moves the .devtools file to ~/.flutter-devtools/.devtools if the .devtools
  /// file exists in the user's home directory.
  static void maybeMoveLegacyDevToolsStore() {
    final file = File(path.join(_userHomeDir(), DevToolsUsage.storeName));
    if (file.existsSync()) {
      ensureDevToolsDirectory();
      file.copySync(devToolsStoreLocation());
      file.deleteSync();
    }
  }

  static String devToolsStoreLocation() {
    return path.join(devToolsDir(), DevToolsUsage.storeName);
  }

  /// Creates the ~/.flutter-devtools directory if it does not already exist.
  static void ensureDevToolsDirectory() {
    Directory(devToolsDir()).createSync();
  }

  /// Returns a DevTools file from the given path.
  ///
  /// Only files within ~/.flutter-devtools/ can be accessed.
  static File? devToolsFileFromPath(String pathFromDevToolsDir) {
    if (pathFromDevToolsDir.contains('..')) {
      // The passed in path should not be able to walk up the directory tree
      // outside of the ~/.flutter-devtools/ directory.
      return null;
    }

    ensureDevToolsDirectory();
    final file = File(path.join(devToolsDir(), pathFromDevToolsDir));
    if (!file.existsSync()) {
      return null;
    }
    return file;
  }

  /// Returns a DevTools file from the given path as encoded json.
  ///
  /// Only files within ~/.flutter-devtools/ can be accessed.
  static String? devToolsFileAsJson(String pathFromDevToolsDir) {
    final file = devToolsFileFromPath(pathFromDevToolsDir);
    if (file == null) return null;

    final fileName = path.basename(file.path);
    if (!fileName.endsWith('.json')) return null;

    final content = file.readAsStringSync();
    final json = jsonDecode(content) as Map;
    json['lastModifiedTime'] = file.lastModifiedSync().toString();
    return jsonEncode(json);
  }

  /// Whether the flutter store file exists.
  static bool flutterStoreExists() {
    final flutterStore = File(path.join(_userHomeDir(), '.flutter'));
    return flutterStore.existsSync();
  }
}

class IOPersistentProperties {
  IOPersistentProperties(
    this.name, {
    String? documentDirPath,
  }) {
    final fileName = name.replaceAll(' ', '_');
    documentDirPath ??= LocalFileSystem._userHomeDir();
    _file = File(path.join(documentDirPath, fileName));
    if (!_file.existsSync()) {
      _file.createSync(recursive: true);
    }
    syncSettings();
  }

  IOPersistentProperties.fromFile(File file) : name = path.basename(file.path) {
    _file = file;
    if (!_file.existsSync()) {
      _file.createSync(recursive: true);
    }
    syncSettings();
  }

  final String name;

  late File _file;

  late Map<String, Object?> _map;

  Object? operator [](String key) => _map[key];

  void operator []=(String key, Object? value) {
    if (value == null && !_map.containsKey(key)) return;
    if (_map[key] == value) return;

    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }

    try {
      _file.writeAsStringSync('${_jsonEncoder.convert(_map)}\n');
    } catch (_) {}
  }

  /// Re-read settings from the backing store.
  ///
  /// May be a no-op on some platforms.
  void syncSettings() {
    try {
      String contents = _file.readAsStringSync();
      if (contents.isEmpty) contents = '{}';
      _map = (jsonDecode(contents) as Map).cast<String, Object>();
    } catch (_) {
      _map = {};
    }
  }

  void remove(String propertyName) {
    _map.remove(propertyName);
  }
}

const _jsonEncoder = JsonEncoder.withIndent('  ');
