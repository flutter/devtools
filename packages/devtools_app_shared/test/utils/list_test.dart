// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ListValueNotifier', () {
    late ListValueNotifier<int> notifier;

    bool didNotify = false;

    void setUpWithInitialValue(List<int> value) {
      didNotify = false;
      notifier = ListValueNotifier<int>(value);
      notifier.addListener(() {
        didNotify = true;
      });
      expect(didNotify, isFalse);
      expect(notifier.value, equals(value));
    }

    setUp(() {
      setUpWithInitialValue([]);
    });

    test('does not respect changes to the initial list', () {
      final initialList = [1, 2, 3];
      setUpWithInitialValue(initialList);

      initialList.add(4);
      notifier.add(5);
      expect(notifier.value, equals([1, 2, 3, 5]));
    });

    test('value returns ImmutableList', () {
      expect(notifier.value, isA<ImmutableList<Object?>>());
    });

    test('notifies on add', () {
      notifier.add(1);
      expect(didNotify, isTrue);
      expect(notifier.value, equals([1]));
    });

    test('notifies on replace', () {
      final initialList = [1, 2, 3, 4, 5];
      setUpWithInitialValue(initialList);
      final result = notifier.replace(3, -1);
      expect(result, true);
      expect(didNotify, isTrue);
      expect(notifier.value, equals([1, 2, -1, 4, 5]));
    });

    test('does not notify on invalid replace', () {
      final initialList = [1, 2, 3, 4, 5];
      setUpWithInitialValue(initialList);
      final result = notifier.replace(6, -1);
      expect(result, false);
      expect(didNotify, isFalse);
      expect(notifier.value, equals([1, 2, 3, 4, 5]));
    });

    test('notifies on addAll', () {
      notifier.addAll([1, 2]);
      expect(didNotify, isTrue);
      expect(notifier.value, equals([1, 2]));
    });

    test('notifies on clear', () {
      setUpWithInitialValue([1, 2, 3]);
      notifier.clear();
      expect(didNotify, isTrue);
      expect(notifier.value, equals([]));
    });

    test('notifies on trim to sublist with start only', () {
      setUpWithInitialValue([1, 2, 3]);
      notifier.trimToSublist(1);
      expect(didNotify, isTrue);
      expect(notifier.value, equals([2, 3]));
    });

    test('notifies on trim to sublist', () {
      setUpWithInitialValue([1, 2, 3]);
      notifier.trimToSublist(1, 2);
      expect(didNotify, isTrue);
      expect(notifier.value, equals([2]));
    });

    test('notifies on last', () {
      setUpWithInitialValue([1, 2, 3]);
      notifier.last = 4;
      expect(didNotify, isTrue);
      expect(notifier.value, equals([1, 2, 4]));
    });

    test('notifies on remove', () {
      setUpWithInitialValue([1, 2, 3]);
      notifier.remove(2);
      expect(didNotify, isTrue);
      expect(notifier.value, equals([1, 3]));
    });

    test('notifies on removeAll', () {
      setUpWithInitialValue([1, 2, 3, 4]);
      notifier.removeAll([1, 3]);
      expect(didNotify, isTrue);
      expect(notifier.value, equals([2, 4]));
    });

    test('notifies on removeRange', () {
      setUpWithInitialValue([1, 2, 3, 4]);
      notifier.removeRange(1, 3);
      expect(didNotify, isTrue);
      expect(notifier.value, equals([1, 4]));
    });

    test('notifies on removeAt', () {
      setUpWithInitialValue([1, 2, 3, 4]);
      notifier.removeAt(1);
      expect(didNotify, isTrue);
      expect(notifier.value, equals([1, 3, 4]));
    });

    test('does not notify on remove of missing element', () {
      setUpWithInitialValue([1, 2, 3]);
      notifier.remove(0);
      expect(didNotify, isFalse);
      expect(notifier.value, equals([1, 2, 3]));
    });
  });

  group('ImmutableList', () {
    late List<int> rawList;
    late ImmutableList<int> immutableList;

    setUp(() {
      rawList = [1, 2, 3];
      immutableList = ImmutableList(rawList);
    });

    test('initializes length', () {
      expect(rawList.length, equals(3));
      expect(immutableList.length, equals(3));
    });

    test('[]', () {
      expect(rawList[0], equals(1));
      expect(rawList[1], equals(2));
      expect(rawList[2], equals(3));
      expect(immutableList[0], equals(1));
      expect(immutableList[1], equals(2));
      expect(immutableList[2], equals(3));

      rawList.add(4);

      // Accessing an index < the original length should not throw.
      expect(immutableList[0], equals(1));
      expect(immutableList[1], equals(2));
      expect(immutableList[2], equals(3));

      // Throws because the index is out of range of the immutable list.
      expect(() => immutableList[3], throwsException);
      expect(rawList[3], equals(4));
    });

    test('throws on []=', () {
      expect(() => immutableList[0] = 5, throwsException);
    });

    test('throws on add', () {
      expect(() => immutableList.add(4), throwsException);
    });

    test('throws on addAll', () {
      expect(() => immutableList.addAll([4, 5, 6]), throwsException);
    });

    test('throws on remove', () {
      expect(() => immutableList.remove(1), throwsException);
    });

    test('throws on removeAt', () {
      expect(() => immutableList.removeAt(1), throwsException);
    });

    test('throws on removeLast', () {
      expect(() => immutableList.removeLast(), throwsException);
    });

    test('throws on removeRange', () {
      expect(() => immutableList.removeRange(1, 2), throwsException);
    });

    test('throws on removeWhere', () {
      expect(
        () => immutableList.removeWhere((int n) => n == 1),
        throwsException,
      );
    });

    test('throws on retainWhere', () {
      expect(
        () => immutableList.retainWhere((int n) => n == 1),
        throwsException,
      );
    });

    test('throws on insert', () {
      expect(() => immutableList.insert(1, 5), throwsException);
    });

    test('throws on insertAll', () {
      expect(() => immutableList.insertAll(1, [4, 5, 6]), throwsException);
    });

    test('throws on clear', () {
      expect(() => immutableList.clear(), throwsException);
    });

    test('throws on fillRange', () {
      expect(() => immutableList.fillRange(0, 1, 5), throwsException);
    });

    test('throws on setRange', () {
      expect(() => immutableList.setRange(0, 1, [5]), throwsException);
    });

    test('throws on replaceRange', () {
      expect(() => immutableList.setRange(0, 1, [5]), throwsException);
    });

    test('throws on setAll', () {
      expect(() => immutableList.setAll(1, [5]), throwsException);
    });

    test('throws on sort', () {
      expect(() => immutableList.sort(), throwsException);
    });

    test('throws on shuffle', () {
      expect(() => immutableList.shuffle(), throwsException);
    });
  });
}
