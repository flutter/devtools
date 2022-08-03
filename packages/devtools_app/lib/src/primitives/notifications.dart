// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'utils.dart';

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

class NotificationController implements NotificationService {
  final toPush = ValueNotifier<NotificationMessage>(NotificationMessage(''));
  final toDismiss = ValueNotifier<NotificationMessage>(NotificationMessage(''));

  @visibleForTesting
  final inProcess = <NotificationMessage>[];

  /// Pushes a notification [message].
  @override
  bool push(String message) => smartPush(NotificationMessage(message));

  /// Pushes a notification [message].
  @override
  bool smartPush(
    NotificationMessage message, {
    bool allowDuplicates = true,
  }) {
    if (!allowDuplicates &&
        inProcess.containsWhere((m) => m.text == message.text)) {
      return false;
    }
    inProcess.add(message);
    toPush.value = message;
    return true;
  }

  /// Dismisses all notifications with a matching message.
  @override
  void dismiss(String message) =>
      toDismiss.value = NotificationMessage(message);

  /// Marks the message as complete, so that the messages not
  /// allowing duplicates,
  /// with the same text, do not get rejected.
  void markComplete(NotificationMessage message) {
    inProcess.removeWhere((element) => element == message);
  }

  void dispose() {
    toPush.dispose();
    toDismiss.dispose();
  }
}
