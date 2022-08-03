// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

class NotificationMessage {
  NotificationMessage(
    this.text, {
    this.actions = const [],
    this.duration = defaultDuration,
  });

  /// The default duration for notifications to show.
  static const Duration defaultDuration = Duration(seconds: 7);

  final String text;
  final List<Widget> actions;
  final Duration duration;
}

abstract class NotificationService {
  /// Pushes a notification [message].
  bool push(String message);
  bool smartPush(
    NotificationMessage message, {
    bool allowDuplicates = true,
  });

  /// Dismisses all notifications with a matching message.
  void dismiss(String message);
}
