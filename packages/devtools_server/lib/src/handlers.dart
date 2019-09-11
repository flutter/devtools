import 'dart:async';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:shelf_static/shelf_static.dart';

/// Default [shelf.Handler] for serving DevTools files.
///
/// This serves files out from the build results of running a pub build of the
/// DevTools project.
Future<shelf.Handler> defaultHandler() async {
  final Uri resourceUri = await Isolate.resolvePackageUri(
      Uri(scheme: 'package', path: 'devtools/devtools.dart'));
  final packageDir = path.dirname(path.dirname(resourceUri.toFilePath()));

  // Default static handler for all non-package requests.
  final String buildDir = path.join(packageDir, 'build');
  final buildHandler = createStaticHandler(
    buildDir,
    defaultDocument: 'index.html',
  );

  // The packages folder is renamed in the pub package so this handler serves
  // out of the `pack` folder.
  final String packagesDir = path.join(packageDir, 'build', 'pack');
  final packHandler = createStaticHandler(
    packagesDir,
    defaultDocument: 'index.html',
  );

  // Make a handler that delegates based on path.
  FutureOr<shelf.Response> handler(shelf.Request request) {
    return request.url.path.startsWith('packages/')
        // request.change here will strip the `packages` prefix from the path
        // so it's relative to packHandler's root.
        ? packHandler(request.change(path: 'packages'))
        : buildHandler(request);
  }

  return handler;
}
