// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as path;

class DevToolsRepo {
  DevToolsRepo._create(this.repoPath);

  final String repoPath;

  @override
  String toString() => '[DevTools $repoPath]';

  /// This returns the DevToolsRepo instance based on the current working
  /// directory.
  ///
  /// Throws if the current working directory is not contained within a git
  /// checkout of DevTools.
  static DevToolsRepo getInstance() {
    final repoPath = _findRepoRoot(Directory.current);
    if (repoPath == null) {
      throw Exception(
        'devtools_tool must be run from inside of the DevTools repository directory',
      );
    }
    return DevToolsRepo._create(repoPath);
  }

  List<Package> getPackages() {
    final result = <Package>[];
    final repoDir = Directory(repoPath);

    // For the first level of packages, ignore any directory named 'flutter'.
    for (FileSystemEntity entity in repoDir.listSync()) {
      final name = path.basename(entity.path);
      if (entity is Directory && !name.startsWith('.')) {
        _collectPackages(entity, result);
      }
    }

    result.sort((a, b) => a.packagePath.compareTo(b.packagePath));

    return result;
  }

  static String? _findRepoRoot(Directory dir) {
    // Look for README.md, packages, tool.
    if (_fileExists(dir, 'README.md') &&
        _dirExists(dir, 'packages') &&
        _dirExists(dir, 'tool')) {
      return dir.path;
    }

    if (dir.path == dir.parent.path) {
      return null;
    } else {
      return _findRepoRoot(dir.parent);
    }
  }

  void _collectPackages(Directory dir, List<Package> result) {
    // Do not collect packages from the Flutter SDK that is stored in the tool/
    // directory.
    if (dir.path.contains('flutter-sdk/')) return;

    if (_fileExists(dir, 'pubspec.yaml')) {
      result.add(Package._(this, dir.path));
    }

    for (FileSystemEntity entity in dir.listSync(followLinks: false)) {
      final name = path.basename(entity.path);
      if (entity is Directory && !name.startsWith('.') && name != 'build') {
        _collectPackages(entity, result);
      }
    }
  }

  String readFile(String filePath) {
    return File(path.join(repoPath, filePath)).readAsStringSync();
  }
}

class FlutterSdk {
  FlutterSdk._(this.sdkPath);

  /// Return the Flutter SDK.
  ///
  /// This can return null if the Flutter SDK can't be found.
  static FlutterSdk? getSdk() {
    // Look for it relative to the current Dart process.
    final dartVmPath = Platform.resolvedExecutable;
    final pathSegments = path.split(dartVmPath);
    final expectedSegments = path.posix.split('bin/cache/dart-sdk/bin/dart');

    if (pathSegments.length >= expectedSegments.length) {
      // Remove the trailing 'dart'.
      pathSegments.removeLast();
      expectedSegments.removeLast();

      while (expectedSegments.isNotEmpty) {
        if (expectedSegments.last == pathSegments.last) {
          pathSegments.removeLast();
          expectedSegments.removeLast();
        } else {
          break;
        }
      }

      if (expectedSegments.isEmpty) {
        return FlutterSdk._(path.joinAll(pathSegments));
      }
    }

    // Look to see if we can find the 'flutter' command in the PATH.
    final result = Process.runSync('which', ['flutter']);
    if (result.exitCode == 0) {
      final sdkPath = result.stdout.toString().split('\n').first.trim();
      // 'flutter/bin'
      if (path.basename(path.dirname(sdkPath)) == 'bin') {
        return FlutterSdk._(path.dirname(path.dirname(sdkPath)));
      }
    }

    return null;
  }

  final String sdkPath;

  String get flutterToolPath => path.join(sdkPath, 'bin', 'flutter');

  String get dartToolPath => path.join(sdkPath, 'bin', 'dart');

  String get dartSdkPath => path.join(sdkPath, 'bin', 'cache', 'dart-sdk');

  String get pubToolPath => path.join(dartSdkPath, 'bin', 'pub');

  @override
  String toString() => '[Flutter sdk: $sdkPath]';
}

class Package {
  Package._(this.repo, this.packagePath);

  final DevToolsRepo repo;
  final String packagePath;

  String get relativePath => path.relative(packagePath, from: repo.repoPath);

  bool get hasAnyDartCode {
    final dartFiles = <String>[];

    _collectDartFiles(Directory(packagePath), dartFiles);

    return dartFiles.isNotEmpty;
  }

  void _collectDartFiles(Directory dir, List<String> result) {
    for (FileSystemEntity entity in dir.listSync(followLinks: false)) {
      final name = path.basename(entity.path);
      if (entity is Directory && !name.startsWith('.') && name != 'build') {
        _collectDartFiles(entity, result);
      } else if (entity is File && name.endsWith('.dart')) {
        result.add(entity.path);
      }
    }
  }

  @override
  String toString() => '[Package $relativePath]';
}

bool _fileExists(Directory parent, String name) {
  return FileSystemEntity.isFileSync(path.join(parent.path, name));
}

bool _dirExists(Directory parent, String name) {
  return FileSystemEntity.isDirectorySync(path.join(parent.path, name));
}
