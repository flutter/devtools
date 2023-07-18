// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$DevToolsExtensionEvent', () {
    test('parse', () {
      var event = DevToolsExtensionEvent.parse({
        'type': 'ping',
        'data': {'foo': 'bar'},
      });
      expect(event.type, DevToolsExtensionEventType.ping);
      expect(event.data, {'foo': 'bar'});

      event = DevToolsExtensionEvent.parse({
        'type': 'pong',
        'data': {'baz': 'bob'},
      });
      expect(event.type, DevToolsExtensionEventType.pong);
      expect(event.data, {'baz': 'bob'});

      event = DevToolsExtensionEvent.parse({
        'type': 'idk',
      });
      expect(event.type, DevToolsExtensionEventType.unknown);
      expect(event.data, isNull);
    });

    test('tryParse', () {
      var event = DevToolsExtensionEvent.tryParse({
        'type': 'ping',
        'data': {'foo': 'bar'},
      });
      expect(event, isNotNull);

      event = DevToolsExtensionEvent.tryParse('bad input');
      expect(event, isNull);

      event = DevToolsExtensionEvent.tryParse({'more', 'bad', 'input'});
      expect(event, isNull);

      event = DevToolsExtensionEvent.tryParse({1: 'bad', 2: 'input'});
      expect(event, isNull);
    });

    test('toJson', () {
      var event = DevToolsExtensionEvent(DevToolsExtensionEventType.ping);
      expect(event.toJson(), {'type': 'ping'});

      event = DevToolsExtensionEvent(
        DevToolsExtensionEventType.pong,
        data: {'foo': 'bar'},
      );
      expect(event.toJson(), {
        'type': 'ping',
        'data': {'foo': 'bar'},
      });

      event = DevToolsExtensionEvent(
        DevToolsExtensionEventType.unknown,
        data: {'foo': 'bar'},
      );
      expect(event.toJson(), {
        'type': 'unknown',
        'data': {'foo': 'bar'},
      });
    });
  });

  group('$DevToolsExtensionEventType', () {
    test('parses for expected values', () {
      expect(
        DevToolsExtensionEventType.from('ping'),
        DevToolsExtensionEventType.ping,
      );
      expect(
        DevToolsExtensionEventType.from('pong'),
        DevToolsExtensionEventType.pong,
      );
    });

    test('parses for unexpected values', () {
      expect(
        DevToolsExtensionEventType.from('PING'),
        DevToolsExtensionEventType.unknown,
      );
      expect(
        DevToolsExtensionEventType.from('pongg'),
        DevToolsExtensionEventType.unknown,
      );
    });
  });
}
