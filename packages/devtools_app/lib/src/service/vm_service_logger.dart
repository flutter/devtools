// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:vm_service/vm_service.dart';

import '../shared/globals.dart';
import '../shared/primitives/message_bus.dart';

/// A class which listens for all traffic over the VM service protocol and logs
/// the traffic to the message bus.
///
/// The messages are then available in the Logging page. This class is typically
/// only used during development by engineers working on DevTools.
class VmServiceTrafficLogger {
  VmServiceTrafficLogger(VmService service) {
    _sendSub = service.onSend.listen(_logServiceProtocolCalls);
    _receiveSub = service.onReceive.listen(_logServiceProtocolResponses);
  }

  static const eventName = 'devtools.service';

  late final StreamSubscription _sendSub;
  late final StreamSubscription _receiveSub;

  void _logServiceProtocolCalls(String message) {
    final Map m = jsonDecode(message);

    final String? method = m['method'];
    final String? id = m['id'];

    messageBus.addEvent(
      BusEvent(
        eventName,
        data: '⇨ #$id $method()\n$message',
      ),
    );
  }

  void _logServiceProtocolResponses(String message) {
    final Map m = jsonDecode(message);

    String? details = m['method'];
    if (details == null) {
      final Map? result = m['result'];
      if (result != null) {
        details = result['type'];
      } else {
        final Map? error = m['error'];
        details = error == null ? '' : '$error';
      }
    } else if (details == 'streamNotify') {
      details = '';
    }

    final String? id = m['id'];
    String? streamId = '';
    String? kind = '';

    if (m['params'] != null) {
      final Map p = m['params'];
      streamId = p['streamId'];

      final Map? event = m['event'];
      if (event != null) {
        kind = event['extensionKind'] ?? event['kind'];
      }
    }

    messageBus.addEvent(
      BusEvent(
        eventName,
        data:
            '  ⇦ ${id == null ? '' : '#$id '}$details$streamId $kind\n$message',
      ),
    );
  }

  void dispose() {
    unawaited(_sendSub.cancel());
    unawaited(_receiveSub.cancel());
  }
}
