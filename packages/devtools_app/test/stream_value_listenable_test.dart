// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/stream_value_listenable.dart';
import 'package:test/test.dart';

void main() {
  StreamController<int> controller;
  int currentValue;
  List<int> values;
  StreamValueListenable listenable;

  void updateValue(int v) {
    currentValue = v;
    controller.add(v);
  }

  final listener = () {
    values.add(listenable.value);
  };

  setUp(() {
    values = [];
    currentValue = null;
    controller = StreamController<int>.broadcast(sync: true);
    listenable = StreamValueListenable<int>(
      (notifier) {
        return controller.stream.listen((value) {
          notifier.value = value;
        });
      },
      () => currentValue,
    );
  });

  group('StreamValueListenable', () {
    test('no listener', () {
      expect(listenable.value, isNull);
      updateValue(42);
      expect(listenable.value, equals(42));
      expect(values, isEmpty);
      updateValue(7);
      expect(values, isEmpty);
      expect(listenable.value, equals(7));
      updateValue(19);
      expect(values, isEmpty);
      expect(listenable.value, equals(19));
    });

    test('listener', () {
      expect(listenable.value, isNull);
      listenable.addListener(listener);
      expect(values, isEmpty);
      updateValue(42);
      expect(listenable.value, equals(42));
      expect(values.length, equals(1));
      expect(values.last, equals(42));
      // Verify that updating again does not trigger the listener to send a
      // spurious event.
      updateValue(42);
      expect(values.length, equals(1));
      expect(values.last, equals(42));
      updateValue(7);
      expect(values.length, equals(2));
      expect(values.last, equals(7));
      expect(listenable.value, equals(7));

      listenable.removeListener(listener);
      updateValue(19);

      // Verify no event was dispatched but the value is still up to date.
      expect(values.length, equals(2));
      expect(listenable.value, equals(19));
    });
  });
}
