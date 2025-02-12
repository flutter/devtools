// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Provides functionality to track actionInProgress state while executing long
/// running actions.
///
/// Use this mixin to simplifying showing buttons as disabled while blocking
/// actions are being performed and otherwise avoid executing multiple actions
/// at once.
mixin BlockingActionMixin<T extends StatefulWidget> on State<T> {
  /// Returns whether an action is in progress.
  ///
  /// Typically users should disable buttons and or other UI that should not
  /// be interactive while the action is in progress.
  @protected
  bool get actionInProgress => _actionInProgress;
  bool _actionInProgress = false;

  final _disposed = Completer<bool>();

  /// Sets actionInProgress to true until the [callback] completes or this
  /// State object is disposed.
  ///
  /// The future returned by this method completes when either the future
  /// returned by the callback completes or the State object is disposed.
  Future<void> blockWhileInProgress(Future Function() callback) async {
    setState(() {
      _actionInProgress = true;
    });
    try {
      // If we await a callback that does not complete until after this object
      // is disposed, we will leak State objects.
      await Future.any([callback(), _disposed.future]);
    } finally {
      if (_disposed.isCompleted) {
        // Calling setState after dispose will trigger a spurious exception.
        assert(!_actionInProgress);
      } else {
        setState(() {
          _actionInProgress = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _actionInProgress = false;
    _disposed.complete(true);
    super.dispose();
  }
}
