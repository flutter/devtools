// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:source_map_stack_trace/source_map_stack_trace.dart';
import 'package:source_maps/source_maps.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;

import '../shared/analytics/analytics.dart' as ga;
import '../shared/globals.dart';

final _log = Logger('app_error_handling');

SingleMapping? _sourceMap;

/// Set up error handling for the app.
///
/// This method will hook into both the zone error handling and the Flutter
/// frameworks error handling. Any errors caught will be reported to the
/// analytics system.
///
/// [appStartCallback] should be a callback that creates the main Flutter
/// application.
Future<void> setupErrorHandling(Future Function() appStartCallback) async {
  try {
    final sourceMapUri = Uri.parse('main.dart.js.map');
    final sourceMapFile = await get(sourceMapUri);
    _sourceMap = SingleMapping.fromJson(
      jsonDecode(sourceMapFile.body),
      mapUrl: sourceMapUri,
    );
  } catch (_) {
    // Ignore any errors getting the source map.
  }

  // First, run all our code in a new zone.
  unawaited(
    runZonedGuarded<Future<void>>(
      // ignore: avoid-passing-async-when-sync-expected this ignore should be fixed.
      () {
        WidgetsFlutterBinding.ensureInitialized();

        final FlutterExceptionHandler? oldHandler = FlutterError.onError;

        FlutterError.onError = (FlutterErrorDetails details) {
          // Flutter Framework errors are caught here.
          reportError(
            details.exception,
            stack: details.stack,
            errorType: 'FlutterError',
          );

          if (oldHandler != null) {
            oldHandler(details);
          }
        };

        PlatformDispatcher.instance.onError = (error, stack) {
          // Unhandled errors on the root isolate are caught here.
          reportError(error, stack: stack, errorType: 'PlatformDispatcher');
          return false;
        };
        return appStartCallback();
      },
      (Object error, StackTrace stack) {
        // TODO(https://github.com/flutter/devtools/issues/7856): can we detect
        // severe errors here that are related to dart2wasm? Otherwise we may
        // crash DevTools for the user without any way for them to force reload
        // with JS.
        reportError(error, stack: stack, errorType: 'zoneGuarded');
        throw error;
      },
    ),
  );
}

void reportError(
  Object error, {
  String errorType = 'DevToolsError',
  bool notifyUser = false,
  StackTrace? stack,
}) {
  stack = _maybeMapStackTrace(stack ?? StackTrace.empty);

  final terseStackTrace = stack_trace.Trace.from(stack).terse.toString();

  _log.severe('[$errorType]: ${error.toString()}', error, stack);

  ga.reportError('$error\n$terseStackTrace');

  // Show error message in a notification pop-up:
  if (notifyUser) {
    notificationService.pushError(
      error.toString(),
      stackTrace: terseStackTrace,
    );
  }
}

StackTrace _maybeMapStackTrace(StackTrace stack) {
  final sourceMap = _sourceMap;
  return sourceMap != null
      ? mapStackTrace(
          sourceMap,
          stack,
          minified: true,
        )
      : stack;
}
