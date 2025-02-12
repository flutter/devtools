// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:source_map_stack_trace/source_map_stack_trace.dart';
import 'package:source_maps/source_maps.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;

import '../analytics/analytics.dart' as ga;
import '../globals.dart';

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
      () async {
        WidgetsFlutterBinding.ensureInitialized();

        await _initializeSourceMapping();

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
  unawaited(
    _reportError(
      error,
      errorType: errorType,
      notifyUser: notifyUser,
      stack: stack,
    ).catchError((_) {
      // Ignore errors.
    }),
  );
}

Future<void> _reportError(
  Object error, {
  String errorType = 'DevToolsError',
  bool notifyUser = false,
  StackTrace? stack,
}) async {
  final stackTrace = await _sourceMapStackTrace(stack);
  final terseStackTrace = stackTrace?.terse;
  final errorMessageWithTerseStackTrace = '$error\n${terseStackTrace ?? ''}';
  _log.severe('[$errorType]: $errorMessageWithTerseStackTrace', error, stack);

  ga.reportError('$error', stackTrace: stackTrace);

  // Show error message in a notification pop-up:
  if (notifyUser) {
    notificationService.pushError(
      error.toString(),
      stackTrace: terseStackTrace?.toString(),
    );
  }
}

SingleMapping? _cachedJsSourceMapping;
SingleMapping? _cachedWasmSourceMapping;

Future<SingleMapping?> _fetchSourceMapping() async {
  final cachedSourceMapping =
      kIsWasm ? _cachedWasmSourceMapping : _cachedJsSourceMapping;

  return cachedSourceMapping ?? (await _initializeSourceMapping());
}

Future<SingleMapping?> _initializeSourceMapping() async {
  if (!kIsWeb) return null;
  try {
    final sourceMapUri = Uri.parse('main.dart.${kIsWasm ? 'wasm' : 'js'}.map');
    final sourceMapFile = await get(sourceMapUri);

    return SingleMapping.fromJson(
      jsonDecode(sourceMapFile.body),
      mapUrl: sourceMapUri,
    );
  } catch (_) {
    // Ignore any errors loading the source map.
    return null;
  }
}

Future<stack_trace.Trace?> _sourceMapStackTrace(StackTrace? stack) async {
  final originalStackTrace = stack;
  if (originalStackTrace == null) return null;

  final mappedStackTrace = await _maybeMapStackTrace(originalStackTrace);
  // If mapping fails, revert back to the original stack trace:
  final stackTrace =
      mappedStackTrace.toString().isEmpty
          ? originalStackTrace
          : mappedStackTrace;
  return stack_trace.Trace.from(stackTrace);
}

Future<StackTrace> _maybeMapStackTrace(StackTrace stack) async {
  final sourceMapping = await _fetchSourceMapping();
  return sourceMapping != null
      ? mapStackTrace(sourceMapping, stack, minified: true)
      : stack;
}
