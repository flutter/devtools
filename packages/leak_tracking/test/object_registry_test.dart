// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:leak_tracking/src/_gc_time.dart';
import 'package:leak_tracking/src/_tracker.dart' show LeakTracker;
import 'package:leak_tracking/src/instrumentation.dart';
import 'package:leak_tracking/src/model.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'object_registry_test.mocks.dart';

/// See https://github.com/dart-lang/mockito/blob/master/NULL_SAFETY_README.md
/// Run `dart run build_runner build` to regenerate mocks.
/// We check-in mocks, because the code is here temporary.
@GenerateMocks([
  Finalizer,
])
void main() {
  final mockFinalizer = MockFinalizer<Object>();
  final gcTimeLine = GCTimeLine();
  // Object, that was just attached to mockFinalizer.
  Object? lastAttachedObject;
  late Function(Object token) registerGC;
  late LeakTracker testObjectRegistry;

  setUp(() {
    startAppLeakTracking(detailsProvider: (object) => 'location of $object');
    when(mockFinalizer.attach(any, any)).thenAnswer((invocation) {
      lastAttachedObject = invocation.positionalArguments[0];
    });
    testObjectRegistry = LeakTracker(
      finalizerBuilder: (handler) {
        registerGC = handler;
        return mockFinalizer;
      },
      gcTimeLine: gcTimeLine,
    );
  });

  group(LeakTracker, () {
    test('creates Finalizer and passes handler to it', () {
      expect(registerGC, isNotNull);
    });

    test('attaches object to finalizer', () {
      testObjectRegistry.startTracking('my object', 'my token');
      expect(lastAttachedObject, 'my object');
    });

    test('reports zero leaks', () {
      final summary = testObjectRegistry.collectLeaksSummary();
      expect(summary.totals.values.sum, 0);
    });

    test('declares not-GC-ed leak', () async {
      const myObject = 'my object';
      const myToken = 'my token';
      testObjectRegistry.startTracking(myObject, myToken);
      testObjectRegistry.registerDisposal(myObject, myToken);
      _registerGCEvents(16, gcTimeLine);
      expect(gcTimeLine.now, 3);
      await Future.delayed(delayToDeclareLeakIfNotGCed);
      final leaks = testObjectRegistry.collectLeaksSummary();
      expect(leaks.totals.values.sum, 1);
      expect(leaks.totals[LeakType.notGCed], 1);
    });
  });
}

void _registerGCEvents(int count, GCTimeLine gcTimeLine) {
  for (var _ in Iterable.generate(count)) {
    gcTimeLine.registerOldGCEvent();
  }
}
