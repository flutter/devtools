// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'ui/elements.dart';
import 'ui/primer.dart';

/// Used as a screen id for messages that do not pertain to a specific screen.
const generalId = 'general';

class MessageManager {
  MessageManager();

  final _container = CoreElement.from(queryId('messages-container'));

  /// Maps screen ids to their respective messages.
  ///
  /// Messages that do not pertain to a specific screen will be stored under the
  /// key [_generalId].
  final Map<String, Set<Message>> _messages = {};

  final List<String> _dismissedMessageIds = [];

  void showMessagesForScreen(String screenId) {
    _messages[screenId]?.forEach(_showMessage);
  }

  void _showMessage(Message message) {
    if (_dismissedMessageIds.contains(message.id)) return;
    _container.add(message.flash);
  }

  void removeAll() {
    _container.clear();
    // Remove all error messages.
    _messages[generalId]
        ?.removeWhere((m) => m.messageType == MessageType.error);
  }

  void addMessage(Message message, String screenId) {
    message.onDismiss.listen((_message) {
      if (_message.id != null) {
        _dismissedMessageIds.add(_message.id);
      }
      _messages[screenId]?.remove(_message);
    });

    // ignore: prefer_collection_literals
    _messages.putIfAbsent(screenId, () => Set()).add(message);
    _showMessage(message);
  }
}

class Message {
  Message(
    this.messageType, {
    this.id,
    this.message,
    this.title,
    this.children,
  }) {
    _buildFlash();
  }

  final MessageType messageType;

  final String id;

  final String message;

  final String title;

  final List<CoreElement> children;

  final PFlash flash = PFlash();

  final StreamController<Message> _dismissController =
      StreamController<Message>.broadcast();

  Stream<Message> get onDismiss => _dismissController.stream;

  void _buildFlash() {
    if (messageType == MessageType.warning) {
      flash.warning();
    } else if (messageType == MessageType.error) {
      flash.error();
    }

    flash.addClose().click(() {
      flash.element.remove();
      _dismissController.add(this);
    });

    if (title != null) {
      flash.add(label(text: title));
    }
    if (message != null) {
      for (String text in message.split('\n\n')) {
        flash.add(div(text: text));
      }
    }
    if (children != null) {
      children.forEach(flash.add);
    }
  }
}

enum MessageType {
  info,
  warning,
  error,
}
