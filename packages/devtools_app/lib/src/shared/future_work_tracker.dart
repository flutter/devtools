// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'primitives/utils.dart';

/// Class that tracks whether work defined by when futures complete is still in
/// progress.
///
/// Work is added by calling [track] and completed when the [Future]s tracked
/// complete or when [clear] is called.
class FutureWorkTracker {
  final _inProgress = <Future<void>>{};

  /// ValueNotifier that returns whether any of the futures added since last
  /// [clear] are still in progress.
  ValueListenable<bool> get active => _active;
  final _active = ValueNotifier<bool>(false);

  /// Clears all currently in progress work.
  ///
  /// The work tracker now operates as if that in progress work was never added.
  void clear() {
    _inProgress.clear();
    _active.value = false;
  }

  /// Adds [future] to the work being tracked.
  ///
  /// Unless [clear] is called, [active] will now return true until [future]
  /// completes either with a value or an error.
  Future<void> track(Future<void> Function() futureCallback) async {
    _active.value = true;

    // Release the UI thread so that listeners of the [_active] notifier can
    // reacy before [futureCallback] is called.
    await delayToReleaseUiThread();

    final future = futureCallback();
    _inProgress.add(future);
    unawaited(
      future.whenComplete(() {
        _inProgress.remove(future);
        if (_inProgress.isEmpty) {
          _active.value = false;
        }
      }),
    );
    return future;
  }
}
