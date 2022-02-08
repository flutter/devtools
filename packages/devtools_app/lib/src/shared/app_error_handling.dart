// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;

import '../analytics/analytics.dart' as ga;
import '../config_specific/logger/logger.dart';

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
  return runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final FlutterExceptionHandler? oldHandler = FlutterError.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      _reportError(details.exception, details.stack ?? StackTrace.empty);

      if (oldHandler != null) {
        oldHandler(details);
      }
    };

    return appStartCallback();
  }, (Object error, StackTrace stack) {
    _reportError(error, stack);
  });
}

void _reportError(Object error, StackTrace stack) {
  final terseStackTrace = stack_trace.Trace.from(stack).terse.toString();

  log('$error', LogLevel.error);

  ga.reportError('$error\n$terseStackTrace');
}
