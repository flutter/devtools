// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/shared/future_work_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FutureWorkTracker', () {
    test('tracker returns future', () async {
      final tracker = FutureWorkTracker();
      final completer = Completer<Object?>();
      expect(tracker.track(completer.future), equals(completer.future));
    });

    test('tracks work', () async {
      final tracker = FutureWorkTracker();
      expect(tracker.active.value, isFalse);
      final completer1 = Completer<Object?>();
      unawaited(tracker.track(completer1.future));

      expect(tracker.active.value, isTrue);
      final completer2 = Completer<Object?>();
      unawaited(tracker.track(completer2.future));
      expect(tracker.active.value, isTrue);
      completer1.complete(null);
      await completer1.future;
      expect(tracker.active.value, isTrue);
      completer2.complete(null);
      await completer2.future;
      expect(tracker.active.value, isFalse);
    });

    test('tracks work after clear', () async {
      final tracker = FutureWorkTracker();
      expect(tracker.active.value, isFalse);
      final completer1 = Completer<Object?>();
      unawaited(tracker.track(completer1.future));
      expect(tracker.active.value, isTrue);
      tracker.clear();
      expect(tracker.active.value, isFalse);
      final completer2 = Completer<Object?>();
      unawaited(tracker.track(completer2.future));
      expect(tracker.active.value, isTrue);
      completer2.complete(null);
      await completer2.future;
      expect(tracker.active.value, isFalse);
    });

    test('tracks failed work', () async {
      await runZonedGuarded(() async {
        final tracker = FutureWorkTracker();
        expect(tracker.active.value, isFalse);
        final completer1 = Completer<Object?>();
        unawaited(tracker.track(completer1.future));
        expect(tracker.active.value, isTrue);
        final completer2 = Completer<Object?>();
        unawaited(tracker.track(completer2.future));
        expect(tracker.active.value, isTrue);
        completer1.completeError('bad');
        try {
          await completer1.future;
        } catch (error) {
          expectSync(error, equals('bad'));
        }
        expect(tracker.active.value, isTrue);
        completer2.completeError('bad');
        try {
          await completer2.future;
        } catch (error) {
          expectSync(error, equals('bad'));
        }
        expect(tracker.active.value, isFalse);
      }, (Object error, StackTrace stack) {
        expectSync(error, equals('bad'));
      });
    });
  });
}
