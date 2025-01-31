// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:js_interop';

import 'package:web/web.dart';

/// Catch and print errors from the given future. These errors are part of
/// normal operation for an app, and don't need to be reported to analytics
/// (i.e., they're not DevTools crashes).
Future<T> allowedError<T>(Future<T> future, {bool logError = true}) {
  return future.catchError((Object error) {
    if (logError) {
      final errorLines = error.toString().split('\n');
      console.groupCollapsed('[${error.runtimeType}] ${errorLines.first}'.toJS);
      console.log(errorLines.skip(1).join('\n').toJS);
      console.groupEnd();
    }
    return Future<T>.value();
  });
}
