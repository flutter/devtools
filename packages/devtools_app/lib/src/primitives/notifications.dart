// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

class NotificationsMessage {
  NotificationsMessage(this.message,
      {this.actions = const [],
      this.duration = defaultDuration,
      this.allowDuplicates = true});

  static const Duration defaultDuration = Duration(seconds: 7);

  final String message;
  final List<Widget> actions;
  final Duration duration;
  final bool allowDuplicates;
}

class NotificationService {
  /// The default duration for notifications to show.

  final toPush = ValueNotifier<NotificationsMessage>(NotificationsMessage(''));
  final toDismiss = ValueNotifier<String>('');

  /// Pushes a notification [message].
  bool push(NotificationsMessage message) => toPush.value = message;

  /// Dismisses all notifications with a matching message.
  void dismiss(String message) => toDismiss.value = message;

  void dispose() {
    toPush.dispose();
    toDismiss.dispose();
  }
}
