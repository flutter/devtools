// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io' as io show Platform, File;

import 'package:file/file.dart' as file;
import 'package:file/local.dart' as file;
import 'package:path/path.dart' as path;

import 'devtools_store.dart';

/// The real, local file system, which can be avoided in tests.
const file.FileSystem fileSystem = file.LocalFileSystem();

/// A namespace local file system utlities.
extension LocalFileSystem on Never {
  static String _userHomeDir() {
    final envKey = io.Platform.operatingSystem == 'windows'
        ? 'APPDATA'
        : 'HOME';
    return io.Platform.environment[envKey] ?? '.';
  }

  /// Returns the path to the DevTools storage directory.
  @Deprecated("Replaced by 'FileSystemExtension.devToolsDir'")
  static String devToolsDir() {
    return path.join(_userHomeDir(), '.flutter-devtools');
  }

  /// Moves the .devtools file to ~/.flutter-devtools/.devtools if the .devtools
  /// file exists in the user's home directory.
  @Deprecated("Replaced by 'FileSystemExtension.maybeMoveLegacyDevToolsStore'")
  static void maybeMoveLegacyDevToolsStore() {
    final file = File(path.join(_userHomeDir(), DevToolsUsage.storeName));
    if (file.existsSync()) {
      ensureDevToolsDirectory();
      file.copySync(devToolsStoreLocation());
      file.deleteSync();
    }
  }

  @Deprecated("Replaced by 'FileSystemExtension.devToolsStoreLocation'")
  static String devToolsStoreLocation() {
    return path.join(devToolsDir(), DevToolsUsage.storeName);
  }

  /// Creates the ~/.flutter-devtools directory if it does not already exist.
  @Deprecated('To be removed')
  static void ensureDevToolsDirectory() {
    Directory(devToolsDir()).createSync();
  }

  /// Returns a DevTools file from the given path.
  ///
  /// Only files within ~/.flutter-devtools/ can be accessed.
  @Deprecated("Replaced by 'FileSystemExtension.devToolsFileFromPath'")
  static io.File? devToolsFileFromPath(String pathFromDevToolsDir) {
    if (pathFromDevToolsDir.contains('..') ||
        path.isAbsolute(pathFromDevToolsDir)) {
      // The passed in path should not be able to walk up the directory tree
      // outside of the ~/.flutter-devtools/ directory. It must also not be an
      // absolute path: path.join() discards the base directory when its second
      // argument is absolute, which would otherwise allow reading an arbitrary
      // file on disk (e.g. an absolute path to a credentials .json file).
      return null;
    }

    ensureDevToolsDirectory();
    final devToolsDirPath = devToolsDir();
    final file = File(path.join(devToolsDirPath, pathFromDevToolsDir));
    // Defense in depth: ensure the resolved path is actually contained within
    // the DevTools directory.
    if (!path.isWithin(devToolsDirPath, file.path)) {
      return null;
    }
    if (!file.existsSync()) {
      return null;
    }
    return file;
  }

  /// Returns a DevTools file from the given path as encoded json.
  ///
  /// Only files within ~/.flutter-devtools/ can be accessed.
  @Deprecated("Replaced by 'FileSystemExtension.devToolsFileAsJson'")
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
  @Deprecated("Replaced by 'FileSystemExtension.flutterStoreExists'")
  static bool flutterStoreExists() {
    final flutterStore = File(path.join(_userHomeDir(), '.flutter'));
    return flutterStore.existsSync();
  }
}

extension FileSystemExtension on file.FileSystem {
  static String get _userHomeDir {
    final envKey = io.Platform.operatingSystem == 'windows'
        ? 'APPDATA'
        : 'HOME';
    return io.Platform.environment[envKey] ?? '.';
  }

  /// The path to the DevTools storage directory.
  static String get devToolsDir {
    return path.join(_userHomeDir, '.flutter-devtools');
  }

  /// Moves the `.devtools` file to `~/.flutter-devtools/.devtools` if the
  /// `.devtools` file exists in the user's home directory.
  void maybeMoveLegacyDevToolsStore() {
    final storeFile = this.file(
      path.join(_userHomeDir, DevToolsUsage.storeName),
    );
    if (storeFile.existsSync()) {
      _ensureDevToolsDirectory();
      storeFile.copySync(devToolsStoreLocation);
      storeFile.deleteSync();
    }
  }

  static String get devToolsStoreLocation {
    return path.join(devToolsDir, DevToolsUsage.storeName);
  }

  /// Creates the `~/.flutter-devtools` directory if it does not already exist.
  void _ensureDevToolsDirectory() {
    directory(devToolsDir).createSync();
  }

  /// Returns a DevTools file from the given path.
  ///
  /// Only files within ~/.flutter-devtools/ can be accessed.
  file.File? devToolsFileFromPath(String relativePath) {
    if (relativePath.contains('..') || path.isAbsolute(relativePath)) {
      // The passed in path should not be able to walk up the directory tree
      // outside of the `~/.flutter-devtools/` directory. It must also not be an
      // absolute path: `path.join()` discards the base directory when its
      // second argument is absolute, which would otherwise allow reading an
      // arbitrary file on disk (e.g. an absolute path to a credentials `.json`
      // file).
      return null;
    }

    _ensureDevToolsDirectory();
    final targetFile = this.file(path.join(devToolsDir, relativePath));
    // Defense in depth: ensure the resolved path is actually contained within
    // the DevTools directory.
    if (!path.isWithin(devToolsDir, targetFile.path)) return null;
    if (!targetFile.existsSync()) return null;
    return targetFile;
  }

  /// Returns a DevTools file from the given path as encoded JSON.
  ///
  /// Only files within `~/.flutter-devtools/` can be accessed.
  String? devToolsFileAsJson(String relativePath) {
    final targetFile = devToolsFileFromPath(relativePath);
    if (targetFile == null) return null;

    final fileName = path.basename(targetFile.path);
    if (!fileName.endsWith('.json')) return null;

    final content = targetFile.readAsStringSync();
    final json = jsonDecode(content) as Map;
    json['lastModifiedTime'] = targetFile.lastModifiedSync().toString();
    return jsonEncode(json);
  }

  /// Whether the flutter store file exists.
  bool get flutterStoreExists {
    final flutterStore = this.file(path.join(_userHomeDir, '.flutter'));
    return flutterStore.existsSync();
  }
}

class IOPersistentProperties {
  IOPersistentProperties(this.name, {String? documentDirPath}) {
    final fileName = name.replaceAll(' ', '_');
    documentDirPath ??= LocalFileSystem._userHomeDir();
    _file = io.File(path.join(documentDirPath, fileName));
    if (!_file.existsSync()) {
      _file.createSync(recursive: true);
    }
    syncSettings();
  }

  IOPersistentProperties.fromFile(io.File file)
    : name = path.basename(file.path) {
    _file = file;
    if (!_file.existsSync()) {
      _file.createSync(recursive: true);
    }
    syncSettings();
  }

  final String name;

  late io.File _file;

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
    this[propertyName] = null;
  }
}

const _jsonEncoder = JsonEncoder.withIndent('  ');
