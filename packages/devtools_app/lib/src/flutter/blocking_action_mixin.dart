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
  bool actionInProgress = false;

  void blockWhileInProgress(Future callback()) async {
    setState(() {
      actionInProgress = true;
    });
    try {
      // TODO(jacobr): handle actions that timeout gracefully.
      await callback();
    } finally {
      setState(() {
        actionInProgress = false;
      });
    }
  }
}
