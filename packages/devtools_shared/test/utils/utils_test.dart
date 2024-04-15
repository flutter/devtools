// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:test/test.dart';

void main() {
  group('CompleterExtension', () {
    late Completer<int> completer;

    setUp(() {
      completer = Completer<int>();
    });

    group('safeComplete', () {
      int? value;
      setUp(() {
        value = null;
        unawaited(completer.future.then((v) => value = v));
      });

      test('completes successfully', () async {
        expect(completer.isCompleted, false);
        expect(value, isNull);

        completer.safeComplete(5);
        await completer.future;
        expect(completer.isCompleted, true);
        expect(value, 5);
      });

      test('does not complete if already completed', () async {
        expect(completer.isCompleted, false);
        expect(value, isNull);
        completer.complete(1);
        await completer.future;

        expect(completer.isCompleted, true);
        expect(value, 1);

        completer.safeComplete(5);
        expect(completer.isCompleted, true);
        expect(value, 1);

        String? elseValue;
        completer.safeComplete(3, () => elseValue = 'hit orElse');
        expect(completer.isCompleted, true);
        expect(value, 1);
        expect(elseValue, 'hit orElse');
      });
    });

    group('safeCompleteError', () {
      late Future<int> errorFuture;
      ({Object error, StackTrace? st})? error;

      setUp(() {
        unawaited(
          errorFuture = completer.future.onError((e, st) {
            error = (error: e!, st: st);
            return -1;
          }),
        );
      });

      test('completes successfully', () async {
        completer.safeCompleteError('This is an error');
        await errorFuture;
        expect(completer.isCompleted, true);
        expect(error?.error, 'This is an error');
      });

      test('does not complete if already completed', () async {
        completer.safeCompleteError('This is an error');
        await errorFuture;
        expect(completer.isCompleted, true);
        expect(error?.error, 'This is an error');

        completer.safeCompleteError('This is a different error');
        await errorFuture;
        expect(completer.isCompleted, true);
        expect(error?.error, 'This is an error');
      });
    });
  });
}
