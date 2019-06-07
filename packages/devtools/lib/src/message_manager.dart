// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'globals.dart';
import 'ui/elements.dart';
import 'ui/primer.dart';

class MessageManager {
  MessageManager();

  static const _generalId = 'general';

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
    _messages[_generalId]
        ?.removeWhere((m) => m.messageType == MessageType.error);
  }

  void addMessage(Message message, {String screenId = _generalId}) {
    message.onDismiss.listen((_message) {
      if (_message.id != null) {
        _dismissedMessageIds.add(_message.id);
      }
      _messages[screenId]?.remove(_message);
    });

    // ignore: prefer_collection_literals
    _messages[screenId] ??= Set()..add(message);
    _showMessage(message);
  }

  void showError(String title, [dynamic error]) {
    String message;
    if (error != null) {
      message = '$error';
      // Only display the error object if it has a custom Dart toString.
      if (message.startsWith('[object ') ||
          message.startsWith('Instance of ')) {
        message = null;
      }
    }
    addMessage(Message(
      MessageType.error,
      message: message,
      title: title,
    ));
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

Future<bool> shouldShowDebugWarning() async {
  return !offlineMode &&
      serviceManager.connectedApp != null &&
      !await serviceManager.connectedApp.isProfileBuild;
}
