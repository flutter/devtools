// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:test/test.dart';

void main() {
  late int counter;

  setUp(() {
    counter = 0;
  });

  void callback({required int succeedOnAttempt}) {
    counter++;
    if (counter < succeedOnAttempt) {
      throw Exception();
    }
  }

  group('runWithRetry', () {
    test('succeeds after a single attempt', () async {
      expect(counter, 0);
      await runWithRetry(
        callback: () => callback(succeedOnAttempt: 1),
        maxRetries: 10,
      );
      expect(counter, 1);
    });

    test('succeeds after multiple attempts', () async {
      expect(counter, 0);
      await runWithRetry(
        callback: () => callback(succeedOnAttempt: 5),
        maxRetries: 10,
      );
      expect(counter, 5);
    });

    test('calls onRetry callback for each retry attempt', () async {
      var str = '';
      expect(counter, 0);
      await runWithRetry(
        callback: () => callback(succeedOnAttempt: 5),
        maxRetries: 10,
        onRetry: (attempt) => str = '$str$attempt',
      );
      expect(counter, 5);
      expect(str, '1234');
    });

    test('throws after max retries reached', () async {
      expect(counter, 0);
      await expectLater(
        () async {
          await runWithRetry(
            callback: () => callback(succeedOnAttempt: 11),
            maxRetries: 10,
          );
        },
        throwsException,
      );
      expect(counter, 10);
    });

    test('stops early if continueCondition is not met', () async {
      expect(counter, 0);
      await expectLater(
        () async {
          await runWithRetry(
            callback: () => callback(succeedOnAttempt: 5),
            maxRetries: 10,
            continueCondition: () => counter < 3,
          );
        },
        throwsA(isA<StateError>()),
      );
      expect(counter, 3);
    });
  });
}
