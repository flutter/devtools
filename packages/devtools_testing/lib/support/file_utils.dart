import 'dart:async';
import 'dart:io' as io;

import 'package:package_resolver/package_resolver.dart';
import 'package:test/test.dart';

/// Loads the widgets.json file that describes the widgets [Catalog].
Future<String> widgetsJson() async {
  final devtoolsPath = await resolvePackagePath('devtools_app');
  return await io.File('$devtoolsPath/web/widgets.json').readAsString();
}

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

/// Work-around for flutter test using different directories based on how it's run.
// TODO(https://github.com/flutter/flutter/issues/20907): Remove this.
void compensateForFlutterTestDirectoryBug() {
  if (io.Directory.current.path.endsWith('test')) {
    io.Directory.current = io.Directory.current.parent;
  }
}
