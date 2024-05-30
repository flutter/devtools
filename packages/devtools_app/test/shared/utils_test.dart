// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/shared/utils.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebounceTimer', () {
    test('the callback happens immediately', () {
      fakeAsync((async) {
        int callbackCounter = 0;
        DebounceTimer.periodic(
          const Duration(seconds: 1),
          () async {
            callbackCounter++;
            await Future<void>.delayed(const Duration(seconds: 60));
          },
        );
        async.elapse(const Duration(milliseconds: 40));
        expect(callbackCounter, 1);
      });
    });

    test('only triggers another callback after the first is done', () {
      fakeAsync((async) {
        int callbackCounter = 0;
        DebounceTimer.periodic(
          const Duration(milliseconds: 500),
          () async {
            callbackCounter++;
            await Future<void>.delayed(const Duration(seconds: 30));
          },
        );
        async.elapse(const Duration(seconds: 31));
        expect(callbackCounter, 2);
      });
    });

    test('calls the callback at the beginning and then once per period', () {
      fakeAsync((async) {
        int callbackCounter = 0;
        DebounceTimer.periodic(
          const Duration(seconds: 1),
          () async {
            callbackCounter++;
            await Future<void>.delayed(
              const Duration(milliseconds: 1),
            );
          },
        );
        async.elapse(const Duration(milliseconds: 40500));
        expect(callbackCounter, 41);
      });
    });

    test(
      'cancels the periodic timer when cancel is called between the first and second callback calls',
      () {
        fakeAsync((async) {
          int callbackCounter = 0;
          final timer = DebounceTimer.periodic(
            const Duration(seconds: 1),
            () async {
              callbackCounter++;
              await Future<void>.delayed(
                const Duration(milliseconds: 1),
              );
            },
          );
          async.elapse(const Duration(milliseconds: 500));
          expect(callbackCounter, 1);

          timer.cancel();

          async.elapse(const Duration(seconds: 20));
          expect(callbackCounter, 1);
        });
      },
    );

    test(
      'cancels the periodic timer when cancelled after multiple periodic calls',
      () {
        fakeAsync((async) {
          int callbackCounter = 0;
          final timer = DebounceTimer.periodic(
            const Duration(seconds: 1),
            () async {
              callbackCounter++;
              await Future<void>.delayed(
                const Duration(milliseconds: 1),
              );
            },
          );
          async.elapse(const Duration(milliseconds: 20500));
          expect(callbackCounter, 21);

          timer.cancel();

          async.elapse(const Duration(seconds: 20));
          expect(callbackCounter, 21);
        });
      },
    );
  });

  group('InterruptableChunkWorker', () {
    late InterruptableChunkWorker worker;
    late List<int> indexes;
    late List<double> progresses;
    const int chunkSize = 3;
    setUp(() {
      indexes = [];
      progresses = [];
      worker = InterruptableChunkWorker(
        chunkSize: chunkSize,
        callback: (int i) {
          indexes.add(i);
        },
        progressCallback: (double progress) {
          progresses.add(progress);
        },
      );
    });

    test('0 length', () async {
      final result = await worker.doWork(0);
      expect(result, true);
      expect(indexes, isEmpty);
      expect(progresses, isEmpty);
    });

    test('3 chunks', () async {
      const length = chunkSize * 3;
      final result = await worker.doWork(length);
      expect(result, true);
      expect(indexes, [
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
      ]);
      expect(progresses, [0.0, 3 / length, 6 / length, 9 / length]);
    });

    test('partial chunks', () async {
      const length = 5;
      final result = await worker.doWork(length);
      expect(result, true);
      expect(indexes, [
        0,
        1,
        2,
        3,
        4,
      ]);
      expect(progresses, [
        0.0,
        3 / length,
        5 / length,
      ]);
    });

    test('interrupted chunks', () async {
      bool? result1;
      bool? result2;
      const length1 = 7;
      const length2 = 5;
      final result2Completer = Completer();
      worker = InterruptableChunkWorker(
        chunkSize: chunkSize,
        callback: (int i) async {
          indexes.add(i);
          if (indexes.length == 4) {
            result2 = await worker.doWork(length2);
            result2Completer.complete();
          }
        },
        progressCallback: (double progress) {
          progresses.add(progress);
        },
      );
      result1 = await worker.doWork(length1);
      await result2Completer.future;
      expect(result1, false);
      expect(result2, true);
      expect(indexes, [
        0,
        1,
        2,
        3,
        0,
        1,
        2,
        3,
        4,
      ]);
      expect(progresses, [
        0.0,
        3 / length1,
        0.0,
        3 / length2,
        1.0,
      ]);
    });
  });
}
