// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/src/shared/utils/future_work_tracker.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FutureWorkTracker', () {
    test('tracker returns future', () {
      final tracker = FutureWorkTracker();
      final completer = Completer<Object?>();
      // ignore: discarded_futures, by design
      expect(tracker.track(() => completer.future), equals(isA<Future>()));
    });

    void advanceClock(FakeAsync async) {
      async.elapse(const Duration(milliseconds: 50));
    }

    test('tracks work', () {
      _wrapAndRunAsync((async) async {
        final tracker = FutureWorkTracker();
        expect(tracker.active.value, isFalse);

        final completer1 = Completer<Object?>();
        unawaited(tracker.track(() => completer1.future));
        advanceClock(async);
        expect(tracker.active.value, isTrue);

        final completer2 = Completer<Object?>();
        unawaited(tracker.track(() => completer2.future));
        advanceClock(async);
        expect(tracker.active.value, isTrue);

        completer1.complete(null);
        unawaited(completer1.future);
        advanceClock(async);
        expect(tracker.active.value, isTrue);

        completer2.complete(null);
        unawaited(completer2.future);
        advanceClock(async);
        expect(tracker.active.value, isFalse);
      });
    });

    test('tracks work after clear', () {
      _wrapAndRunAsync((async) async {
        final tracker = FutureWorkTracker();
        expect(tracker.active.value, isFalse);

        final completer1 = Completer<Object?>();
        unawaited(tracker.track(() => completer1.future));
        advanceClock(async);
        expect(tracker.active.value, isTrue);

        tracker.clear();
        expect(tracker.active.value, isFalse);

        final completer2 = Completer<Object?>();
        unawaited(tracker.track(() => completer2.future));
        advanceClock(async);
        expect(tracker.active.value, isTrue);

        completer2.complete(null);
        unawaited(completer2.future);
        advanceClock(async);
        expect(tracker.active.value, isFalse);
      });
    });

    test('tracks failed work', () {
      _wrapAndRunAsync((async) async {
        await runZonedGuarded(
          () async {
            final tracker = FutureWorkTracker();
            expect(tracker.active.value, isFalse);

            final completer1 = Completer<Object?>();
            unawaited(tracker.track(() => completer1.future));
            advanceClock(async);
            expect(tracker.active.value, isTrue);

            final completer2 = Completer<Object?>();
            unawaited(tracker.track(() => completer2.future));
            advanceClock(async);
            expect(tracker.active.value, isTrue);

            completer1.completeError('bad');
            try {
              unawaited(completer1.future);
              advanceClock(async);
            } catch (error) {
              expectSync(error, equals('bad'));
            }
            expect(tracker.active.value, isTrue);

            completer2.completeError('bad');
            try {
              unawaited(completer2.future);
              advanceClock(async);
            } catch (error) {
              expectSync(error, equals('bad'));
            }
            expect(tracker.active.value, isFalse);
          },
          (Object error, StackTrace stack) {
            expectSync(error, equals('bad'));
          },
        );
      });
    });
  });
}

void _wrapAndRunAsync(Future<void> Function(FakeAsync) testCallback) {
  unawaited(
    fakeAsync((async) async {
      // If the test expectations are not wrapped in a future, the test will
      // not fail even if one of the expectations fails.
      Future<void> testFuture() => testCallback(async);

      unawaited(testFuture());
      async.flushMicrotasks();
    }),
  );
}
