// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

extension CompleterExtension<T> on Completer<T> {
  /// Completes this completer with optional [value] only if it has not already
  /// been completed.
  ///
  /// If the completer has already been completed, [orElse] will be called if it
  /// is not null,
  void safeComplete([T? value, void Function()? orElse]) {
    if (!isCompleted) {
      complete(value);
    } else {
      orElse?.call();
    }
  }

  /// Completes this completer with [error] and an optional [stackTrace] only if
  /// it has not already been completed.
  void safeCompleteError(Object error, [StackTrace? stackTrace]) {
    if (!isCompleted) {
      completeError(error, stackTrace);
    }
  }
}
