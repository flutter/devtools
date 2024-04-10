// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

/// Runs [callback] and retries if an exception is thrown.
///
/// * [maxRetries] the maximum number of times [callback] will be ran before
///   rethrowing an exception if it does not complete successfully.
/// * [retryDelay] the time to wait between retry attempts.
/// * [continueCondition] an optional callback that determines whether we should
///   continue retrying, in addition to the condition that we must not retry
///   more than [maxRetries] times.
/// * [onRetry] an optional callback that will be called if [callback] fails
///   and we need to attempt a retry.
Future<void> runWithRetry({
  required FutureOr<void> Function() callback,
  required int maxRetries,
  Duration retryDelay = const Duration(milliseconds: 250),
  bool Function()? continueCondition,
  void Function(int attempt)? onRetry,
}) async {
  for (var attempt = 1;
      attempt <= maxRetries && (continueCondition?.call() ?? true);
      attempt++) {
    try {
      await callback();
      break;
    } catch (e) {
      if (attempt == maxRetries) {
        rethrow;
      }
      onRetry?.call(attempt);
      await Future.delayed(retryDelay);
    }
  }
}
