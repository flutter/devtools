// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools/src/core/message_bus.dart';
import 'package:test/test.dart';

void main() {
  defineTests();
}

void defineTests() {
  group('message_bus', () {
    test('fire one event', () async {
      final MessageBus bus = new MessageBus();
      final Future<List<BusEvent>> future =
          bus.onEvent(type: 'app.restart').toList();
      _fireEvents(bus);
      bus.close();
      final List<BusEvent> list = await future;
      expect(list, hasLength(1));
    });

    test('fire two events', () async {
      final MessageBus bus = new MessageBus();
      final Future<List<BusEvent>> future =
          bus.onEvent(type: 'file.saved').toList();
      _fireEvents(bus);
      bus.close();
      final List<BusEvent> list = await future;
      expect(list, hasLength(2));
      expect(list[0].data, 'foo.dart');
      expect(list[1].data, 'bar.dart');
    });

    test('receive all events', () async {
      final MessageBus bus = new MessageBus();
      final Future<List<BusEvent>> future = bus.onEvent().toList();
      _fireEvents(bus);
      bus.close();
      final List<BusEvent> list = await future;
      expect(list, hasLength(3));
    });
  });
}

void _fireEvents(MessageBus bus) {
  bus.addEvent(new BusEvent('app.restart'));
  bus.addEvent(new BusEvent('file.saved', data: 'foo.dart'));
  bus.addEvent(new BusEvent('file.saved', data: 'bar.dart'));
}
