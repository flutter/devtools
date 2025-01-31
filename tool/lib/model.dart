// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

class DevToolsRepo {
  DevToolsRepo._create(this.repoPath);

  /// The path to the DevTools repository root.
  final String repoPath;

  /// The path to the DevTools 'tool' directory.
  String get toolDirectoryPath => path.join(repoPath, 'tool');

  /// The path to the 'tool/flutter-sdk' directory.
  String get toolFlutterSdkPath =>
      path.join(toolDirectoryPath, sdkDirectoryName);

  /// The name of the Flutter SDK directory.
  String get sdkDirectoryName => 'flutter-sdk';

  /// The path to the DevTools 'devtools_app' directory.
  String get devtoolsAppDirectoryPath =>
      path.join(repoPath, 'packages', 'devtools_app');

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
        'dt must be run from inside of the DevTools repository directory',
      );
    }
    return DevToolsRepo._create(repoPath);
  }

  /// Returns the list of Dart or Flutter packages contained within the DevTools
  /// repository.
  ///
  /// A Dart or Flutter package is defined as any directory with a pubspec.yaml
  /// file.
  ///
  /// If a package path contains any part on its path that is in [skip], the
  /// package will not be included in the returned results.
  ///
  /// If [includeSubdirectories] is false, packages that are a subdirectory of
  /// another package will not be included in the returned results.
  List<Package> getPackages({
    List<String> skip = const [],
    bool includeSubdirectories = true,
  }) {
    final result = <Package>[];
    final repoDir = Directory(repoPath);

    for (final entity in repoDir.listSync()) {
      final name = path.basename(entity.path);
      if (entity is Directory && !name.startsWith('.')) {
        _collectPackages(
          entity,
          result,
          skip: skip,
          includeSubdirectories: includeSubdirectories,
        );
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

  void _collectPackages(
    Directory dir,
    List<Package> result, {
    bool includeSubdirectories = true,
    List<String> skip = const [],
  }) {
    // Do not collect packages from the Flutter SDK that is stored in the tool/
    // directory.
    if (dir.path.contains(path.join('tool', 'flutter-sdk'))) return;

    if (_fileExists(dir, 'pubspec.yaml')) {
      final isTopLevelPackagesDir = dir.path.endsWith('packages');
      final shouldSkip =
          skip.firstWhereOrNull((skipDir) => dir.path.contains(skipDir)) !=
          null;
      if (isTopLevelPackagesDir || shouldSkip) {
        // Do not include the top level devtools/packages directory in the results
        // even though it has a pubspec.yaml file. Also skip any directories
        // specified by [skip].
        final reason =
            isTopLevelPackagesDir
                ? 'each DevTools package is analyzed individually'
                : '${skip.toString()} directories are intentionally skipped';
        print('Skipping ${dir.path} in _collectPackages because $reason.');
      } else {
        final ancestor = result.firstWhereOrNull(
          (p) =>
          // Remove the last segment of [dir]'s pathSegments to ensure we
          // are only checking ancestors and not sibling directories with
          // similar names.
          (List.from(dir.uri.pathSegments)..safeRemoveLast())
              // TODO(kenz): this may cause issues for Windows paths.
              .join('/')
              .startsWith(p.packagePath),
        );
        final ancestorDirectoryAdded = ancestor != null;
        if (!includeSubdirectories && ancestorDirectoryAdded) {
          print(
            'Skipping ${dir.path} in _collectPackages because it is a '
            'subdirectory of another package (${ancestor.packagePath}).',
          );
        } else {
          result.add(Package._(this, dir.path));
        }
      }
    }

    for (final entity in dir.listSync(followLinks: false)) {
      final name = path.basename(entity.path);
      if (entity is Directory && !name.startsWith('.') && name != 'build') {
        _collectPackages(
          entity,
          result,
          skip: skip,
          includeSubdirectories: includeSubdirectories,
        );
      }
    }
  }

  /// Reads the file at [uri], which should be a relative path from [repoPath].
  String readFile(Uri uri) {
    return File(path.join(repoPath, uri.path)).readAsStringSync();
  }
}

class FlutterSdk {
  FlutterSdk._(this.sdkPath);

  static FlutterSdk? _current;

  /// The current located Flutter SDK.
  ///
  /// Tries to locate from the running Dart VM. If not found, will print a
  /// warning and use Flutter from PATH.
  static FlutterSdk get current {
    if (_current == null) {
      throw Exception(
        'Cannot use FlutterSdk.current before SDK has been selected.'
        'SDK selection is done by DevToolsCommandRunner.runCommand().',
      );
    }
    return _current!;
  }

  /// Sets the active Flutter SDK to the one that contains the Dart VM being
  /// used to run this script.
  ///
  /// Throws if the current VM is not inside a Flutter SDK.
  static void useFromCurrentVm() {
    _current = findFromCurrentVm();
  }

  /// Sets the active Flutter SDK to the one found in the `PATH` environment
  /// variable (by running which/where).
  ///
  /// Throws if an SDK is not found on PATH.
  static void useFromPathEnvironmentVariable() {
    _current = findFromPathEnvironmentVariable();
  }

  /// Finds the Flutter SDK that contains the Dart VM being used to run this
  /// script.
  ///
  /// Throws if the current VM is not inside a Flutter SDK.
  static FlutterSdk findFromCurrentVm() {
    // Look for it relative to the current Dart process.
    final dartVmPath = Platform.resolvedExecutable;
    final pathSegments = path.split(dartVmPath);
    // TODO(dantup): Should we add tool/flutter-sdk to the front here, to
    // ensure we _only_ ever use this one, to avoid potentially updating a
    // different Flutter if the user runs explicitly with another Flutter?
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
        final flutterSdkRoot = path.joinAll(pathSegments);
        return FlutterSdk._(flutterSdkRoot);
      }
    }

    throw Exception(
      'Unable to locate the Flutter SDK from the current running Dart VM:\n'
      '${Platform.resolvedExecutable}',
    );
  }

  /// Finds a Flutter SDK in the `PATH` environment variable
  /// (by running which/where).
  ///
  /// Throws if an SDK is not found on PATH.
  static FlutterSdk findFromPathEnvironmentVariable() {
    final whichCommand = Platform.isWindows ? 'where.exe' : 'which';
    final result = Process.runSync(whichCommand, ['flutter']);
    if (result.exitCode == 0) {
      final sdkPath = result.stdout.toString().split('\n').first.trim();
      // 'flutter/bin'
      if (path.basename(path.dirname(sdkPath)) == 'bin') {
        return FlutterSdk._(path.dirname(path.dirname(sdkPath)));
      }
    }

    throw Exception('Unable to locate the Flutter SDK on PATH');
  }

  final String sdkPath;

  static String get flutterExecutableName =>
      Platform.isWindows ? 'flutter.bat' : 'flutter';

  /// On windows, 'dart' is fine for running the .exe from the Dart SDK directly
  /// but the wrapper in the Flutter bin folder is a .bat and needs an explicit
  /// extension.
  static String get dartWrapperExecutableName =>
      Platform.isWindows ? 'dart.bat' : 'dart';

  String get flutterExePath => path.join(sdkPath, 'bin', flutterExecutableName);

  String get dartExePath =>
      path.join(sdkPath, 'bin', dartWrapperExecutableName);

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
    for (final entity in dir.listSync(followLinks: false)) {
      final name = path.basename(entity.path);
      if (entity is Directory && !name.startsWith('.') && name != 'build') {
        _collectDartFiles(entity, result);
      } else if (entity is File && path.extension(name) == '.dart') {
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

extension _SafeAccessList<T> on List<T> {
  T? safeRemoveLast() => isNotEmpty ? removeLast() : null;
}
