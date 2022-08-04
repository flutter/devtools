// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/material.dart';

import '../primitives/utils.dart';

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

class NotificationService {
  final toPush = Queue<NotificationMessage>();
  final toDismiss = Queue<NotificationMessage>();

  /// Notifies about added messages or dismissals.
  final ValueNotifier<int> messagesAdded = ValueNotifier(0);

  /// Messages that are currently shown in UI.
  @visibleForTesting
  final activeMessages = <NotificationMessage>[];

  /// Pushes a notification [message].
  bool push(String message) => pushNotification(NotificationMessage(message));

  /// Pushes a notification [message].
  ///
  /// Ignores the message if [allowDuplicates] is false and a message with the
  /// same text is currently displayed to the user.
  bool pushNotification(
    NotificationMessage message, {
    bool allowDuplicates = true,
  }) {
    if (!allowDuplicates &&
        activeMessages.containsWhere((m) => m.text == message.text)) {
      return false;
    }
    activeMessages.add(message);
    toPush.add(message);
    messagesAdded.value++;
    return true;
  }

  /// Dismisses all notifications with a matching message.
  void dismiss(String message) {
    toPush.removeWhere((element) => element.text == message);

    if (activeMessages.containsWhere((element) => element.text == message)) {
      toDismiss.addLast(NotificationMessage(message));
      messagesAdded.value++;
    }
  }

  /// Marks the message as complete, so that the messages not
  /// allowing duplicates,
  /// with the same text, do not get rejected.
  void markComplete(NotificationMessage message) {
    activeMessages.removeWhere((element) => element == message);
  }

  void dispose() {
    messagesAdded.dispose();
  }
}

class NotificationAction extends StatelessWidget {
  const NotificationAction(this.label, this.onAction, {this.isPrimary = false});

  final String label;

  final VoidCallback onAction;

  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(label);
    return isPrimary
        ? ElevatedButton(
            onPressed: onAction,
            child: labelText,
          )
        : OutlinedButton(
            onPressed: onAction,
            child: labelText,
          );
  }
}
