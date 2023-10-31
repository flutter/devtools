// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore: avoid_web_libraries_in_flutter, as designed
import 'dart:html';

/// Catch and print errors from the given future. These errors are part of
/// normal operation for an app, and don't need to be reported to analytics
/// (i.e., they're not DevTools crashes).
Future<T> allowedError<T>(Future<T> future, {bool logError = true}) {
  return future.catchError((Object error) {
    if (logError) {
      final errorLines = error.toString().split('\n');
      window.console
          .groupCollapsed('[${error.runtimeType}] ${errorLines.first}');
      window.console.log(errorLines.skip(1).join('\n'));
      window.console.groupEnd();
    }
    return Future<T>.value();
  });
}
