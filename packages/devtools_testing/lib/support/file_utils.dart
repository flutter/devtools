import 'dart:async';
import 'dart:io' as io;

import 'package:package_resolver/package_resolver.dart';
import 'package:test/test.dart';

/// Finds the path to a given package.
///
/// This includes a workaround to package:package_resolver not working
/// when run in Flutter. When resolution with package_resolver fails, this
/// function falls back on a heuristic that assumes `flutter test` was run
/// from the root directory of package:devtools_app:
/// devtools/packages/devtools_app/. Other packages can be found in sibling
/// directories to this location.
///
/// Also note https://github.com/flutter/flutter/issues/20907, which leads
/// to `flutter test` runs in devtools_app/test/, while
/// `flutter test test/file.dart` runs in devtools_app/.
///
/// If you are writing a test that depends heavily on the current directory
/// remaining constant, consider using [compensateForFlutterTestDirectoryBug]
/// in the `setUp()` of your test.
///
/// If your only use of the filesystem is to resolve package paths, then you
/// only need to use this method, and you do not need to use
/// [compensateForFlutterTestDirectoryBug].
Future<String> resolvePackagePath(String package) async {
  String path;
  try {
    path = await (PackageResolver.current).packagePath(package);
  } on UnsupportedError catch (_) {
    // PackageResolver makes calls to Isolate, which isn't accessible from a
    // flutter test run. Flutter test runs in the test directory of the app,
    // so the packages directory is the current directory's grandparent.
    // TODO(https://github.com/flutter/flutter/issues/20907): Remove the workaround here.
    String packagesPath;
    if (io.Directory.current.path.endsWith('test')) {
      packagesPath = io.Directory.current.parent.parent.path;
    } else {
      packagesPath = io.Directory.current.parent.path;
    }

    path = '$packagesPath/$package';
    if (!io.Directory(path).existsSync()) {
      fail('Unable to locate package:$package at $path');
    }
  }
  return path;
}

/// Work-around for flutter test using different directories based on how it's
/// run.
///
/// If you are writing a test that depends heavily on the current directory
/// remaining constant, consider calling this function in the `setUp()` of your
/// test.
///
/// If your only use of the filesystem is to resolve package paths, then you
/// should only need to use [resolvePackagePath].
// TODO(https://github.com/flutter/flutter/issues/20907): Remove this.
void compensateForFlutterTestDirectoryBug() {
  if (io.Directory.current.path.endsWith('test')) {
    io.Directory.current = io.Directory.current.parent;
  }
}
