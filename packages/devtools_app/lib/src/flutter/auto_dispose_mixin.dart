// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Provides functionality to automatically unsubscribe from streams on dispose.
///
/// Use this class to ensure you don't leak stream subscriptions
mixin AutoDisposeMixin<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription> _subscriptions = [];

  /// Track a stream subscription to be automatically cancelled on dispose.
  void autoDispose(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  @override
  void dispose() {
    super.dispose();
    for (StreamSubscription subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
