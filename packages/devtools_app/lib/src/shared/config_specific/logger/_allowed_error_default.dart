// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:logging/logging.dart';

final _log = Logger('allowed_error_default');

/// Catch and print errors from the given future. These errors are part of
/// normal operation for an app, and don't need to be reported to analytics
/// (i.e., they're not DevTools crashes).
Future<T> allowedError<T>(Future<T> future, {bool logError = true}) {
  return future.catchError((Object error) {
    if (logError) {
      final errorLines = error.toString().split('\n');
      _log.shout('[${error.runtimeType}] ${errorLines.first}');
      _log.shout(errorLines.skip(1).join('\n'));
    }
    // TODO(srawlins): This is an illegal return value (`null`) for all `T`.
    // This function must return an actual `T`.
    // ignore: null_argument_to_non_null_type
    return Future<T>.value();
  });
}
