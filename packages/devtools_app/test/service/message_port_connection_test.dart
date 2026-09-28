// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/src/service/message_port_connection.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isMessagePortUri', () {
    test('accepts messageport URIs', () {
      expect(isMessagePortUri(Uri.parse('messageport:*')), isTrue);
      expect(
        isMessagePortUri(Uri.parse('messageport:https://example.com')),
        isTrue,
      );
      expect(isMessagePortUri(Uri.parse('MessagePort:*')), isTrue);
    });

    test('rejects other URIs', () {
      expect(isMessagePortUri(Uri.parse('ws://127.0.0.1:8181/ws')), isFalse);
      expect(isMessagePortUri(Uri.parse('http://127.0.0.1:8181/')), isFalse);
      expect(isMessagePortUri(Uri.parse('sse://127.0.0.1:8181/')), isFalse);
      expect(isMessagePortUri(Uri.parse('messageport')), isFalse);
    });

    test('survives normalizeVmServiceUri', () {
      // `FrameworkCore.initVmService` normalizes the `uri` query parameter
      // before checking the scheme, so the target origin must survive it.
      for (final targetOrigin in ['https://example.com', '*']) {
        final uri = normalizeVmServiceUri('messageport:$targetOrigin')!;
        expect(isMessagePortUri(uri), isTrue);
        expect(uri.path, targetOrigin);
        expect(uri.toString(), 'messageport:$targetOrigin');
      }
    });
  });

  test('connectWithMessagePort is not supported outside the web', () {
    expect(
      () => connectWithMessagePort(
        uri: Uri.parse('messageport:*'),
        finishedCompleter: Completer<void>(),
      ),
      throwsUnsupportedError,
    );
  }, testOn: 'vm');
}
