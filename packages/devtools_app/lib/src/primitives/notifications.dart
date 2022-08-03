// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'utils.dart';

class NotificationMessage {
  NotificationMessage(this.text,
      {this.actions = const [],
      this.duration = defaultDuration,
      this.allowDuplicates = true});

  /// The default duration for notifications to show.
  static const Duration defaultDuration = Duration(seconds: 7);

  final String text;
  final List<Widget> actions;
  final Duration duration;
  final bool allowDuplicates;
}

class NotificationService {
  final toPush = ValueNotifier<NotificationMessage>(NotificationMessage(''));
  final toDismiss = ValueNotifier<String>('');
  final _showingNow = <NotificationMessage>[];

  /// Pushes a notification [message].
  bool push(String message) => pushRichMessage(NotificationMessage(message));

  /// Pushes a notification [message].
  bool pushRichMessage(NotificationMessage message) {
    if (!message.allowDuplicates &&
        _showingNow.containsWhere((m) => m.text == message.text)) {
      return false;
    }
    _showingNow.add(message);
    toPush.value = message;
    return true;
  }

  /// Dismisses all notifications with a matching message.
  void dismiss(String message) => toDismiss.value = message;

  /// Marks the message as complete, so that the messages not
  /// allowing duplicates,
  /// with the same text, do not get rejected.
  void markComplete(NotificationMessage message) {
    _showingNow.removeWhere((element) => element == message);
  }

  void dispose() {
    toPush.dispose();
    toDismiss.dispose();
  }
}
