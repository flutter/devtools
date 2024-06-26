// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;

import '../shared/analytics/analytics.dart' as ga;
import '../shared/globals.dart';

final _log = Logger('app_error_handling');

/// Set up error handling for the app.
///
/// This method will hook into both the zone error handling and the Flutter
/// frameworks error handling. Any errors caught will be reported to the
/// analytics system.
///
/// [appStartCallback] should be a callback that creates the main Flutter
/// application.
void setupErrorHandling(Future Function() appStartCallback) {
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
  stack = stack ?? StackTrace.empty;

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
