// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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

  void blockWhileInProgress(Future callback()) async {
    setState(() {
      _actionInProgress = true;
    });
    try {
      // TODO(jacobr): handle actions that timeout gracefully.
      await callback();
    } finally {
      setState(() {
        _actionInProgress = false;
      });
    }
  }
}
