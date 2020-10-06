// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf.dart';
import 'package:shelf_proxy/shelf_proxy.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:sse/server/sse_handler.dart';

import 'client_manager.dart';
import 'server_api.dart';

// DO NOT IMPORT THIS FILE into any files other than `devtools_server.dart`.
// This file is overwritten for internal DevTools builds, so any file depending
// on `external_handlers.dart` would break internally.

/// Default [shelf.Handler] for serving DevTools files.
///
/// This serves files out from the build results of running a pub build of the
/// DevTools project.
Future<shelf.Handler> defaultHandler(
  ClientManager clients, {
  bool debugMode = false,
}) async {
  final resourceUri = await Isolate.resolvePackageUri(
      Uri(scheme: 'package', path: 'devtools/devtools.dart'));

  final packageDir = path.dirname(path.dirname(resourceUri.toFilePath()));

  // Default static handler for all non-package requests.
  Handler buildDirHandler;
  if (!debugMode) {
    buildDirHandler = createStaticHandler(
      path.join(packageDir, 'build'),
      defaultDocument: 'index.html',
    );
  }

  Handler debugProxyHandler;
  if (debugMode) {
    // Start up a flutter run -d web-server instance.
    const webPort = 9101;

    // ignore: unawaited_futures
    Process.start(
      'flutter',
      [
        'run',
        '--dart-define=FLUTTER_WEB_USE_SKIA=true',
        '-d',
        'web-server',
        '--web-port=$webPort',
      ],
      workingDirectory: path.join('..', 'devtools_app'),
    ).then((Process process) {
      // Write all flutter run process output to the server's output.
      process
        ..stdout.transform(utf8.decoder).listen(stdout.write)
        ..stderr.transform(utf8.decoder).listen(stderr.write);

      // Proxy all stdin to the flutter run process's input.
      //stdin.pipe(process.stdin);
      stdin
        ..lineMode = false
        ..listen((event) => process.stdin.add(event));

      // Exit when the flutter run process exits.
      process.exitCode.then(exit);
    });

    debugProxyHandler = proxyHandler(Uri.parse('http://localhost:$webPort/'));
  }

  final sseHandler = SseHandler(Uri.parse('/api/sse'))
    ..connections.rest.listen(clients.acceptClient);

  // Make a handler that delegates based on path.
  final handler = (shelf.Request request) {
    if (request.url.path.startsWith('api/sse')) {
      return sseHandler.handler(request);
    }

    if (request.url.path == 'api/ping') {
      return shelf.Response(HttpStatus.ok, body: 'OK');
    }

    // The API handler takes all other calls to api/.
    if (ServerApi.canHandle(request)) {
      return ServerApi.handle(request);
    }

    if (debugMode) {
      return debugProxyHandler(request);
    } else {
      return buildDirHandler(request);
    }
  };

  return handler;
}
