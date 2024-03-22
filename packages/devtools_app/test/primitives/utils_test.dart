// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:devtools_app/src/shared/primitives/utils.dart';
import 'package:devtools_app/src/shared/screen.dart';
import 'package:devtools_app/src/shared/utils.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('utils', () {
    group('durationText', () {
      test('infers unit based on duration', () {
        expect(
          durationText(Duration.zero),
          equals('0 μs'),
        );
        expect(
          durationText(const Duration(microseconds: 100)),
          equals('0.1 ms'),
        );
        expect(
          durationText(const Duration(microseconds: 99)),
          equals('99 μs'),
        );
        expect(
          durationText(const Duration(microseconds: 1000)),
          equals('1.0 ms'),
        );
        expect(
          durationText(const Duration(microseconds: 999900)),
          equals('999.9 ms'),
        );
        expect(
          durationText(const Duration(microseconds: 1000000)),
          equals('1.0 s'),
        );
        expect(
          durationText(const Duration(microseconds: 9000000)),
          equals('9.0 s'),
        );
      });

      test('displays proper number of fraction digits', () {
        expect(
          durationText(const Duration(microseconds: 99)),
          equals('99 μs'),
        );
        expect(
          durationText(
            const Duration(microseconds: 99),
            // Should ignore this since this will be displayed in microseconds.
            fractionDigits: 3,
          ),
          equals('99 μs'),
        );
        expect(
          durationText(const Duration(microseconds: 3111)),
          equals('3.1 ms'),
        );
        expect(
          durationText(const Duration(microseconds: 3159), fractionDigits: 2),
          equals('3.16 ms'),
        );
        expect(
          durationText(const Duration(microseconds: 3111), fractionDigits: 3),
          equals('3.111 ms'),
        );
      });

      test('does not include unit when specified', () {
        expect(
          durationText(
            const Duration(microseconds: 1000),
            includeUnit: false,
          ),
          equals('1.0'),
        );
        expect(
          durationText(
            const Duration(milliseconds: 10000),
            includeUnit: false,
            unit: DurationDisplayUnit.seconds,
          ),
          equals('10.0'),
        );
      });

      test('does not allow rounding to zero when specified', () {
        // Setting [allowRoundingToZero] to false without specifying a unit
        // throws an assertion error.
        expect(
          () {
            durationText(Duration.zero, allowRoundingToZero: false);
          },
          throwsAssertionError,
        );

        // Displays zero for true zero values.
        expect(
          durationText(
            Duration.zero,
            allowRoundingToZero: false,
            unit: DurationDisplayUnit.micros,
          ),
          equals('0 μs'),
        );
        expect(
          durationText(
            Duration.zero,
            allowRoundingToZero: false,
            unit: DurationDisplayUnit.milliseconds,
          ),
          equals('0.0 ms'),
        );
        expect(
          durationText(
            Duration.zero,
            allowRoundingToZero: false,
            unit: DurationDisplayUnit.seconds,
          ),
          equals('0.0 s'),
        );

        // Displays less than text for close-to-zero values.
        expect(
          durationText(
            const Duration(microseconds: 1),
            allowRoundingToZero: false,
            unit: DurationDisplayUnit.milliseconds,
          ),
          equals('< 0.1 ms'),
        );
        expect(
          durationText(
            const Duration(microseconds: 1),
            allowRoundingToZero: false,
            unit: DurationDisplayUnit.seconds,
          ),
          equals('< 0.1 s'),
        );

        // Only displays less than text values that would round to zero.
        expect(
          durationText(
            const Duration(microseconds: 49),
            allowRoundingToZero: false,
            unit: DurationDisplayUnit.milliseconds,
          ),
          equals('< 0.1 ms'),
        );
        expect(
          durationText(
            const Duration(microseconds: 50),
            allowRoundingToZero: false,
            unit: DurationDisplayUnit.milliseconds,
          ),
          equals('0.1 ms'),
        );

        // Displays properly with fraction digits.
        expect(
          durationText(
            const Duration(microseconds: 1),
            fractionDigits: 3,
            allowRoundingToZero: false,
            unit: DurationDisplayUnit.milliseconds,
          ),
          equals('< 0.001 ms'),
        );
      });
    });

    test('nullSafeMin', () {
      expect(nullSafeMin<int>(1, 2), equals(1));
      expect(nullSafeMin<int>(1, null), equals(1));
      expect(nullSafeMin<int>(null, 2), equals(2));
      expect(nullSafeMin<int>(null, null), equals(null));
    });

    test('nullSafeMin', () {
      expect(nullSafeMax<int>(1, 2), equals(2));
      expect(nullSafeMax<int>(1, null), equals(1));
      expect(nullSafeMax<int>(null, 2), equals(2));
      expect(nullSafeMax<int>(null, null), equals(null));
    });

    test('log2', () {
      expect(log2(1), equals(0));
      expect(log2(1.5), equals(0));
      expect(log2(2), equals(1));
      expect(log2(3), equals(1));
      expect(log2(4), equals(2));
    });

    test('roundToNearestPow10', () {
      expect(roundToNearestPow10(1), equals(1));
      expect(roundToNearestPow10(2), equals(10));
      expect(roundToNearestPow10(10), equals(10));
      expect(roundToNearestPow10(11), equals(100));
      expect(roundToNearestPow10(189), equals(1000));
      expect(roundToNearestPow10(6581), equals(10000));
    });

    test('executeWithDelay', () async {
      const delayMs = 500;
      int n = 1;
      int start = DateTime.now().millisecondsSinceEpoch;
      int? end;

      // Condition n >= 2 is false, so we should execute with a delay.
      executeWithDelay(
        const Duration(milliseconds: 500),
        () {
          n++;
          end = DateTime.now().millisecondsSinceEpoch;
        },
        executeNow: n >= 2,
      );

      expect(n, equals(1));
      expect(end, isNull);
      await Future.delayed(const Duration(milliseconds: 250));
      expect(n, equals(1));
      expect(end, isNull);
      await Future.delayed(const Duration(milliseconds: 250));
      expect(n, equals(2));
      expect(end, isNotNull);

      // 1000ms is arbitrary. We want to ensure it doesn't run in less time than
      // we requested (checked above), but we don't want to be too strict because
      // shared CI CPUs can be slow.
      const epsilonMs = 1000;
      expect((end! - start - delayMs).abs(), lessThan(epsilonMs));

      // Condition n >= 2 is true, so we should not execute with a delay.
      end = null;
      start = DateTime.now().millisecondsSinceEpoch;
      executeWithDelay(
        const Duration(milliseconds: 500),
        () {
          n++;
          end = DateTime.now().millisecondsSinceEpoch;
        },
        executeNow: true,
      );
      expect(n, equals(3));
      expect(end, isNotNull);
      // 400ms is arbitrary. It is less than 500, which is what matters. This
      // can be increased if this test starts to flake.
      expect(end! - start, lessThan(400));
    });

    test('timeout', () async {
      int value = 0;
      Future<int> operation() async {
        await Future.delayed(const Duration(milliseconds: 200));
        return ++value;
      }

      expect(value, equals(0));

      var result = await timeout<int>(operation(), 100);
      await delay();
      expect(value, equals(1));
      expect(result, isNull);

      result = await timeout<int>(operation(), 500);
      await delay();
      expect(value, equals(2));
      expect(result, equals(2));
    });

    group('TimeRange', () {
      test('toString', () {
        final timeRange = TimeRange();

        expect(timeRange.toString(), equals('[null μs - null μs]'));

        timeRange
          ..start = const Duration(microseconds: 1000)
          ..end = const Duration(microseconds: 8000);

        expect(timeRange.duration.inMicroseconds, equals(7000));
        expect(timeRange.toString(), equals('[1000 μs - 8000 μs]'));
        expect(
          timeRange.toString(unit: TimeUnit.milliseconds),
          equals('[1 ms - 8 ms]'),
        );
      });

      test('overlaps', () {
        final t = TimeRange()
          ..start = const Duration(milliseconds: 100)
          ..end = const Duration(milliseconds: 200);
        final overlapBeginning = TimeRange()
          ..start = const Duration(milliseconds: 50)
          ..end = const Duration(milliseconds: 150);
        final overlapMiddle = TimeRange()
          ..start = const Duration(milliseconds: 125)
          ..end = const Duration(milliseconds: 175);
        final overlapEnd = TimeRange()
          ..start = const Duration(milliseconds: 150)
          ..end = const Duration(milliseconds: 250);
        final overlapAll = TimeRange()
          ..start = const Duration(milliseconds: 50)
          ..end = const Duration(milliseconds: 250);
        final noOverlap = TimeRange()
          ..start = const Duration(milliseconds: 300)
          ..end = const Duration(milliseconds: 400);

        expect(t.overlaps(t), isTrue);
        expect(t.overlaps(overlapBeginning), isTrue);
        expect(t.overlaps(overlapMiddle), isTrue);
        expect(t.overlaps(overlapEnd), isTrue);
        expect(t.overlaps(overlapAll), isTrue);
        expect(t.overlaps(noOverlap), isFalse);
      });

      test('containsRange', () {
        final t = TimeRange()
          ..start = const Duration(milliseconds: 100)
          ..end = const Duration(milliseconds: 200);
        final containsStart = TimeRange()
          ..start = const Duration(milliseconds: 50)
          ..end = const Duration(milliseconds: 150);
        final containsStartAndEnd = TimeRange()
          ..start = const Duration(milliseconds: 125)
          ..end = const Duration(milliseconds: 175);
        final containsEnd = TimeRange()
          ..start = const Duration(milliseconds: 150)
          ..end = const Duration(milliseconds: 250);
        final invertedContains = TimeRange()
          ..start = const Duration(milliseconds: 50)
          ..end = const Duration(milliseconds: 250);
        final containsNeither = TimeRange()
          ..start = const Duration(milliseconds: 300)
          ..end = const Duration(milliseconds: 400);

        expect(t.containsRange(containsStart), isFalse);
        expect(t.containsRange(containsStartAndEnd), isTrue);
        expect(t.containsRange(containsEnd), isFalse);
        expect(t.containsRange(invertedContains), isFalse);
        expect(t.containsRange(containsNeither), isFalse);
      });

      test('start setter throws exception when single assignment is true', () {
        expect(
          () {
            final t = TimeRange()..start = Duration.zero;
            t.start = Duration.zero;
          },
          throwsAssertionError,
        );
      });

      test('start setter throws exception when value is after end', () {
        expect(
          () {
            final t = TimeRange()..end = const Duration(seconds: 1);
            t.start = const Duration(seconds: 2);
          },
          throwsAssertionError,
        );
      });

      test('end setter throws exception when single assignment is true', () {
        expect(
          () {
            final t = TimeRange()..end = Duration.zero;
            t.end = Duration.zero;
          },
          throwsAssertionError,
        );
      });

      test('end setter throws exception when value is before start', () {
        expect(
          () {
            final t = TimeRange()..start = const Duration(seconds: 1);
            t.end = Duration.zero;
          },
          throwsAssertionError,
        );
      });

      test('isWellFormed', () {
        expect(
          (TimeRange()
                ..start = Duration.zero
                ..end = Duration.zero)
              .isWellFormed,
          isTrue,
        );
        expect((TimeRange()..end = Duration.zero).isWellFormed, isFalse);
        expect((TimeRange()..start = Duration.zero).isWellFormed, isFalse);
      });

      group('offset', () {
        test('from well formed time range', () {
          final t = TimeRange()
            ..start = const Duration(milliseconds: 100)
            ..end = const Duration(milliseconds: 200);
          final offset = TimeRange.offset(
            original: t,
            offset: const Duration(milliseconds: 300),
          );

          expect(offset.start, equals(const Duration(milliseconds: 400)));
          expect(offset.end, equals(const Duration(milliseconds: 500)));
        });

        test('from half formed time range', () {
          var t = TimeRange()..start = const Duration(milliseconds: 100);
          var offset = TimeRange.offset(
            original: t,
            offset: const Duration(milliseconds: 300),
          );

          expect(offset.start, equals(const Duration(milliseconds: 400)));
          expect(offset.end, isNull);

          t = TimeRange()..end = const Duration(milliseconds: 200);
          offset = TimeRange.offset(
            original: t,
            offset: const Duration(milliseconds: 300),
          );

          expect(offset.start, isNull);
          expect(offset.end, equals(const Duration(milliseconds: 500)));
        });

        test('from empty time range', () {
          final t = TimeRange();
          final offset = TimeRange.offset(
            original: t,
            offset: const Duration(milliseconds: 300),
          );

          expect(offset.start, isNull);
          expect(offset.end, isNull);
        });
      });
    });

    test('formatDateTime', () {
      expect(formatDateTime(DateTime(2020, 1, 16, 13)), '13:00:00.000');
    });

    test('longestFittingSubstring', () {
      const asciiStr = 'ComponentElement.performRebuild';
      const nonAsciiStr = 'ԪElement.updateChildԪ';
      num slowMeasureCallback(_) => 100;

      expect(
        longestFittingSubstring(
          asciiStr,
          0,
          asciiMeasurements,
          slowMeasureCallback,
        ),
        equals(''),
      );
      expect(
        longestFittingSubstring(
          asciiStr,
          50,
          asciiMeasurements,
          slowMeasureCallback,
        ),
        equals('Compo'),
      );
      expect(
        longestFittingSubstring(
          asciiStr,
          224,
          asciiMeasurements,
          slowMeasureCallback,
        ),
        equals('ComponentElement.performRebuild'),
      );
      expect(
        longestFittingSubstring(
          asciiStr,
          300,
          asciiMeasurements,
          slowMeasureCallback,
        ),
        equals('ComponentElement.performRebuild'),
      );

      expect(nonAsciiStr.codeUnitAt(0), greaterThanOrEqualTo(128));
      expect(
        longestFittingSubstring(
          nonAsciiStr,
          99,
          asciiMeasurements,
          slowMeasureCallback,
        ),
        equals(''),
      );
      expect(
        longestFittingSubstring(
          nonAsciiStr,
          100,
          asciiMeasurements,
          slowMeasureCallback,
        ),
        equals('Ԫ'),
      );
      expect(
        longestFittingSubstring(
          nonAsciiStr,
          230,
          asciiMeasurements,
          slowMeasureCallback,
        ),
        equals('ԪElement.updateChild'),
      );
      expect(
        longestFittingSubstring(
          nonAsciiStr,
          329,
          asciiMeasurements,
          slowMeasureCallback,
        ),
        equals('ԪElement.updateChild'),
      );
      expect(
        longestFittingSubstring(
          nonAsciiStr,
          330,
          asciiMeasurements,
          slowMeasureCallback,
        ),
        equals('ԪElement.updateChildԪ'),
      );
    });

    test('isLetter', () {
      expect(isLetter('@'.codeUnitAt(0)), isFalse);
      expect(isLetter('['.codeUnitAt(0)), isFalse);
      expect(isLetter('`'.codeUnitAt(0)), isFalse);
      expect(isLetter('{'.codeUnitAt(0)), isFalse);
      expect(isLetter('A'.codeUnitAt(0)), isTrue);
      expect(isLetter('Z'.codeUnitAt(0)), isTrue);
      expect(isLetter('a'.codeUnitAt(0)), isTrue);
      expect(isLetter('z'.codeUnitAt(0)), isTrue);
    });

    test('getSimpleStackFrameName', () {
      String name =
          '_WidgetsFlutterBinding&BindingBase&GestureBinding&ServicesBinding&'
          'SchedulerBinding.handleBeginFrame';
      expect(
        getSimpleStackFrameName(name),
        equals('SchedulerBinding.handleBeginFrame'),
      );

      name =
          '_WidgetsFlutterBinding&BindingBase&GestureBinding&ServicesBinding&'
          'SchedulerBinding.handleBeginFrame.<anonymous closure>';
      expect(
        getSimpleStackFrameName(name),
        equals('SchedulerBinding.handleBeginFrame.<closure>'),
      );

      name = '__CompactLinkedHashSet&_HashFieldBase&_HashBase&_OperatorEquals'
          'AndHashCode&_SetMixin.toList';
      expect(getSimpleStackFrameName(name), equals('_SetMixin.toList'));

      name = 'ClassName&SuperClassName&\$BadClassName.method';
      expect(getSimpleStackFrameName(name), equals('\$BadClassName.method'));

      // Ampersand as C++ reference.
      name =
          'dart::DartEntry::InvokeFunction(dart::Function const&, dart::Array '
          'const&, dart::Array const&, unsigned long)';
      expect(getSimpleStackFrameName(name), equals(name));

      name =
          'SkCanvas::drawTextBlob(SkTextBlob const*, float, float, SkPaint const&)';
      expect(getSimpleStackFrameName(name), equals(name));

      // No leading class names.
      name = '_CustomZone.run';
      expect(getSimpleStackFrameName(name), equals(name));
    });

    test('devToolsQueryParams', () {
      expect(
        devToolsQueryParams('http://localhost:123/?key=value.json&key2=123'),
        equals({
          'key': 'value.json',
          'key2': '123',
        }),
      );
      expect(
        devToolsQueryParams('http://localhost:123/?key=value.json&key2=123'),
        equals({
          'key': 'value.json',
          'key2': '123',
        }),
      );
      for (final meta in ScreenMetaData.values) {
        expect(
          devToolsQueryParams(
            'http://localhost:9101/${meta.id}?key=value.json&key2=123',
          ),
          equals({
            'key': 'value.json',
            'key2': '123',
          }),
        );
      }
    });

    group('safeDivide', () {
      test('divides a finite result correctly', () {
        expect(safeDivide(2.0, 1.0), 2.0);
        expect(safeDivide(2, -4), -0.5);
      });

      test('produces the safe value on nan division', () {
        expect(safeDivide(double.nan, 1.0), 0.0);
        expect(safeDivide(double.nan, 1.0, ifNotFinite: 50.0), 50.0);
        expect(safeDivide(0.0, double.nan, ifNotFinite: -5.0), -5.0);
      });

      test('produces the safe value on infinite division', () {
        expect(safeDivide(double.infinity, 1.0), 0.0);
        expect(
          safeDivide(
            double.nan,
            double.negativeInfinity,
            ifNotFinite: 50.0,
          ),
          50.0,
        );
      });

      test('produces the safe value on null division', () {
        expect(safeDivide(null, 1.0), 0.0);
        expect(safeDivide(1.0, null, ifNotFinite: 50.0), 50.0);
      });

      test('produces the safe value on division by zero', () {
        expect(safeDivide(1.0, 0.0), 0.0);
        expect(safeDivide(-50.0, 0.0, ifNotFinite: 10.0), 10.0);
      });
    });

    group('Reporter', () {
      int called = 0;
      late Reporter reporter;
      void call() {
        called++;
      }

      setUp(() {
        called = 0;
        reporter = Reporter();
      });
      test('notifies listeners', () {
        expect(reporter.hasListeners, false);
        reporter.addListener(call);
        expect(called, 0);
        expect(reporter.hasListeners, true);
        reporter.notify();
        expect(called, 1);
        reporter.notify();
        reporter.notify();
        expect(called, 3);
        reporter.removeListener(call);
        expect(called, 3);
      });

      test('notifies multiple listeners', () {
        reporter.addListener(() => called++);
        reporter.addListener(() => called++);
        reporter.addListener(() => called++);
        reporter.notify();
        expect(called, 3);
        // Note that because we passed in anonymous callbacks, there's no way
        // to remove them.
      });

      test('deduplicates listeners', () {
        reporter.addListener(call);
        reporter.addListener(call);
        reporter.notify();
        expect(called, 1);
        reporter.removeListener(call);
        reporter.notify();
        expect(called, 1);
      });

      test('safely removes multiple times', () {
        reporter.removeListener(call);
        reporter.addListener(call);
        reporter.notify();
        expect(called, 1);
        reporter.removeListener(call);
        reporter.removeListener(call);
        reporter.notify();
        expect(called, 1);
      });
    });

    group('ValueReporter', () {
      int called = 0;
      void call() {
        called++;
      }

      late ValueReporter<String?> reporter;
      setUp(() {
        reporter = ValueReporter(null);
      });
      test('notifies listeners', () {
        expect(reporter.hasListeners, false);
        reporter.addListener(call);
        expect(called, 0);
        expect(reporter.hasListeners, true);
        reporter.value = 'first call';
        expect(called, 1);
        reporter.value = 'second call';
        reporter.value = 'third call';
        expect(called, 3);
        reporter.removeListener(call);
        reporter.value = 'fourth call';
        expect(called, 3);
      });
    });

    group('SafeAccess', () {
      test('safeFirst', () {
        final list = <int?>[];
        final Iterable<int?> iterable = list;
        expect(list.safeFirst, isNull);
        expect(iterable.safeFirst, isNull);
        list.addAll([1, 2, 3]);
        expect(list.safeFirst, equals(1));
        expect(iterable.safeFirst, equals(1));
        list.insert(0, null);
        expect(list.safeFirst, isNull);
        expect(iterable.safeFirst, isNull);
      });

      test('safeLast', () {
        final list = <int?>[];
        expect(list.safeLast, isNull);
        list.addAll([1, 2, 3]);
        expect(list.safeLast, equals(3));
        list.add(null);
        expect(list.safeLast, isNull);
      });

      test('safeGet', () {
        final list = <int>[];
        expect(list.safeGet(0), isNull);
        list.addAll([1, 2]);
        expect(list.safeGet(0), equals(1));
        expect(list.safeGet(1), equals(2));
        expect(list.safeGet(-1), isNull);
      });

      test('safeRemoveLast', () {
        final list = <int>[];
        expect(list.safeRemoveLast(), isNull);
        list.addAll([1, 2]);
        expect(list.safeRemoveLast(), 2);
        expect(list.safeRemoveLast(), 1);
        expect(list.safeRemoveLast(), isNull);
      });
    });
  });

  group('LogicalKeySetExtension', () {
    testWidgets('meta non-mac', (WidgetTester tester) async {
      final keySet =
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyP);
      expect(keySet.describeKeys(), 'Meta-P');
    });

    testWidgets('meta mac', (WidgetTester tester) async {
      final keySet =
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyP);
      expect(keySet.describeKeys(isMacOS: true), '⌘P');
    });

    testWidgets('ctrl', (WidgetTester tester) async {
      final keySet =
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP);
      expect(keySet.describeKeys(), 'Control-P');
    });
  });

  group('MovingAverage', () {
    const simpleDataSet = [
      100,
      200,
      300,
      500,
      1000,
      2000,
      3000,
      4000,
      10000,
      100000,
    ];

    /// Data only has spikes.
    const memorySizeDataSet = [
      190432640,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      201045160,
      198200392,
      200144872,
      210110632,
      234077984,
      229029504,
      229029544,
      231396416,
      240465152,
      303434344, // Spike @ [25] (clear)
      302925712,
      356093472,
      354292096,
      400654120,
      400538848,
      402336872,
      444325760,
      444933104,
      341888120,
      406070376,
      343798216,
      392421072,
      392441080,
      481891656,
      481447920,
      433271776,
      464727280,
      494727280,
      564727280,
      524727280,
      534727280,
      564727280,
      764727280, // Spike @ [48]
      964727280, // Spike @ [49]
      1064727280, // Spike @ [50]
      1464727280, // Spike @ [51]
      2264727280, // Spike @ [52]
      2500000000, // Spike @ [53]
    ];

    /// Data has 5 spikes and 3 dips.
    const dipsSpikesDataSet = [
      190432640,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      190443808,
      5500000, // Dips @ [12]
      5600000,
      7443808,
      9043808,
      11045160,
      49800392, // Spikes @ [17]
      60144872,
      210110632, // Spikes @ [19]
      234077984,
      229029504,
      229029544,
      194000000,
      80000000, // Dips @ [24]
      100000000,
      150000000,
      240465152, // Spike @ [27]
      303434344,
      302925712,
      356093472,
      354292096,
      400654120,
      400538848,
      402336872,
      444325760,
      444933104,
      341888120,
      406070376,
      343798216,
      392421072,
      392441080,
      481891656,
      3000000, // Dips @ [43]
      3100000,
      3200000,
      330000000, // Spike @ [46]
      330000000,
      330000000,
      340000000,
      340000000,
      340000000,
      964727280,
      1064727280,
      1464727280,
      2264727280, // Spike @ [52]
      2500000000,
    ];

    void checkNewItemsAddedToDataSet(MovingAverage mA) {
      mA.add(1000000);
      mA.add(2000000);
      mA.add(3000000);
      expect(mA.dataSet.length, lessThan(mA.averagePeriod));
      expect(mA.mean.toInt(), equals(470853));
      expect(mA.hasSpike(), isTrue);
      expect(mA.isDipping(), isFalse);
    }

    test('basic MA', () {
      // Creation of MovingAverage statically.
      final simpleMA = MovingAverage(newDataSet: simpleDataSet);
      expect(simpleMA.dataSet.length, lessThan(simpleMA.averagePeriod));
      expect(simpleMA.mean.toInt(), equals(12110));
      checkNewItemsAddedToDataSet(simpleMA);

      simpleMA.clear();
      expect(simpleMA.mean, equals(0));

      // Dynamically add data to MovingAverage data set.
      for (int i = 0; i < simpleDataSet.length; i++) {
        simpleMA.add(simpleDataSet[i]);
      }
      // Should be identical to static one from above.
      expect(simpleMA.mean.toInt(), equals(12110));
      checkNewItemsAddedToDataSet(simpleMA);
    });

    test('normal static MA', () {
      // Creation of MovingAverage statically.
      final mA = MovingAverage(newDataSet: memorySizeDataSet);
      // Mean only calculated on last averagePeriod entries (50 default).
      expect(mA.mean.toInt(), equals(462271799));
      expect(mA.dataSet.length, equals(mA.averagePeriod));
      expect(mA.hasSpike(), isTrue);
      expect(mA.isDipping(), isFalse);

      mA.clear();
      expect(mA.mean, equals(0));
      expect(mA.dataSet.length, equals(0));
    });

    test('dynamic spikes MA', () {
      final mA = MovingAverage();

      // Dynamically add data to MovingAverage data set.
      for (int i = 0; i < 20; i++) {
        mA.add(memorySizeDataSet[i]);
        expect(mA.hasSpike(), isFalse);
        expect(mA.isDipping(), isFalse);
      }
      expect(mA.mean.toInt(), equals(192829540));

      for (int i = 20; i < 50; i++) {
        mA.add(memorySizeDataSet[i]);
        switch (i) {
          case 25:
            expect(mA.hasSpike(), isTrue);
            expect(mA.isDipping(), isFalse);
            mA.clear();
            expect(mA.dataSet.length, 0);
            break;
          case 48:
          case 49:
            expect(mA.hasSpike(), isTrue);
            expect(mA.isDipping(), isFalse);
            break;
          default:
            expect(mA.dataSet.length, i < 25 ? i + 1 : i - 25);
            expect(mA.hasSpike(), isFalse);
            expect(mA.isDipping(), isFalse);
        }
      }
      expect(mA.mean.toInt(), equals(469047851));

      expect(mA.dataSet.length, 24);

      for (int i = 50; i < memorySizeDataSet.length; i++) {
        mA.add(memorySizeDataSet[i]);
        switch (i) {
          case 50:
            expect(mA.mean.toInt(), equals(492875028));
            expect(mA.hasSpike(), isTrue);
            expect(mA.isDipping(), isFalse);
            expect(mA.dataSet.length, equals(25));
            break;
          case 51:
            expect(mA.mean.toInt(), equals(530253961));
            expect(mA.hasSpike(), isTrue);
            expect(mA.isDipping(), isFalse);
            expect(mA.dataSet.length, equals(26));
            break;
          case 52:
            expect(mA.mean.toInt(), equals(594493714));
            expect(mA.hasSpike(), isTrue);
            expect(mA.isDipping(), isFalse);
            expect(mA.dataSet.length, equals(27));
            break;
          case 53:
            expect(mA.mean.toInt(), equals(662547510));
            expect(mA.hasSpike(), isTrue);
            expect(mA.isDipping(), isFalse);
            expect(mA.dataSet.length, equals(28));
            break;
          default:
            expect(false, isTrue);
        }
      }

      // dataSet was cleared on first spike @ item 25 so
      // dataSet only has the remaining 28 entries.
      expect(mA.dataSet.length, 28);
      expect(mA.mean.toInt(), equals(662547510));

      mA.clear();
      expect(mA.mean, equals(0));
      expect(mA.dataSet.length, equals(0));
    });

    test('dips and spikes MA', () {
      final mA = MovingAverage();

      // Dynamically add data to MovingAverage data set.
      for (int i = 0; i < memorySizeDataSet.length; i++) {
        mA.add(dipsSpikesDataSet[i]);
        switch (i) {
          case 12:
          case 24:
          case 43:
            expect(mA.hasSpike(), isFalse);
            expect(mA.isDipping(), isTrue);
            break;
          case 17:
          case 19:
          case 27:
          case 46:
          case 52:
            expect(mA.hasSpike(), isTrue);
            expect(mA.isDipping(), isFalse);
            break;
          default:
            expect(mA.hasSpike(), isFalse);
            expect(mA.isDipping(), isFalse);
        }
        if (mA.hasSpike() || mA.isDipping()) {
          mA.clear();
          expect(mA.dataSet.length, 0);
        }
      }
    });

    group('ListExtension', () {
      test('joinWith generates correct list', () {
        expect([1, 2, 3, 4].joinWith(0), equals([1, 0, 2, 0, 3, 0, 4]));
        expect([1].joinWith(0), equals([1]));
        expect(['a', 'b'].joinWith('z'), equals(['a', 'z', 'b']));
      });

      test('containsWhere', () {
        final list = [1, 2, 1, 2, 3, 4];
        expect(list.containsWhere((element) => element == 1), isTrue);
        expect(list.containsWhere((element) => element == 5), isFalse);
        expect(list.containsWhere((element) => element + 2 == 3), isTrue);

        final otherList = ['hi', 'hey', 'foo', 'bar'];
        expect(
          otherList.containsWhere((element) => element.contains('h')),
          isTrue,
        );
        expect(
          otherList.containsWhere((element) => element.startsWith('ba')),
          isTrue,
        );
        expect(
          otherList.containsWhere((element) => element.endsWith('ba')),
          isFalse,
        );
      });

      test('allIndicesWhere', () {
        final list = [1, 2, 1, 2, 3, 4];
        expect(list.allIndicesWhere((element) => element.isEven), [1, 3, 5]);
        expect(list.allIndicesWhere((element) => element.isOdd), [0, 2, 4]);
        expect(list.allIndicesWhere((element) => element + 2 == 3), [0, 2]);
      });
    });

    group('SetExtension', () {
      test('containsWhere', () {
        final set = {1, 2, 3, 4};
        expect(set.containsWhere((element) => element == 1), isTrue);
        expect(set.containsWhere((element) => element == 5), isFalse);
        expect(set.containsWhere((element) => element + 2 == 3), isTrue);

        final otherSet = {'hi', 'hey', 'foo', 'bar'};
        expect(
          otherSet.containsWhere((element) => element.contains('h')),
          isTrue,
        );
        expect(
          otherSet.containsWhere((element) => element.startsWith('ba')),
          isTrue,
        );
        expect(
          otherSet.containsWhere((element) => element.endsWith('ba')),
          isFalse,
        );
      });
    });

    group('NullableStringExtension', () {
      test('isNullOrEmpty', () {
        String? str;
        expect(str.isNullOrEmpty, isTrue);
        str = '';
        expect(str.isNullOrEmpty, isTrue);
        str = 'hello';
        expect(str.isNullOrEmpty, isFalse);
        str = null;
        expect(str.isNullOrEmpty, isTrue);
      });
    });

    group('StringExtension', () {
      test('fuzzyMatch', () {
        const str = 'hello_world_file';
        expect(str.caseInsensitiveFuzzyMatch('h'), isTrue);
        expect(str.caseInsensitiveFuzzyMatch('o_'), isTrue);
        expect(str.caseInsensitiveFuzzyMatch('hw'), isTrue);
        expect(str.caseInsensitiveFuzzyMatch('hwf'), isTrue);
        expect(str.caseInsensitiveFuzzyMatch('_e'), isTrue);
        expect(str.caseInsensitiveFuzzyMatch('HWF'), isTrue);
        expect(str.caseInsensitiveFuzzyMatch('_E'), isTrue);

        expect(str.caseInsensitiveFuzzyMatch('hwfh'), isFalse);
        expect(str.caseInsensitiveFuzzyMatch('hfw'), isFalse);
        expect(str.caseInsensitiveFuzzyMatch('gello'), isFalse);
        expect(str.caseInsensitiveFuzzyMatch('files'), isFalse);
      });

      test('caseInsensitiveContains', () {
        const str = 'This is a test string with a path/to/uri';
        expect(str.caseInsensitiveContains('test'), isTrue);
        expect(str.caseInsensitiveContains('with a PATH/'), isTrue);
        expect(str.caseInsensitiveContains('THIS IS A'), isTrue);
        expect(str.caseInsensitiveContains('not a match'), isFalse);
        expect(str.caseInsensitiveContains('test bool'), isFalse);
        expect(
          str.caseInsensitiveContains(RegExp('is.*path', caseSensitive: false)),
          isTrue,
        );
        expect(
          () => str.caseInsensitiveContains(RegExp('is.*path')),
          throwsAssertionError,
        );
        expect(
          str.caseInsensitiveContains(
            RegExp('THIS IS.*TO/uri', caseSensitive: false),
          ),
          isTrue,
        );
        expect(
          str.caseInsensitiveContains(
            RegExp('this.*does not match', caseSensitive: false),
          ),
          isFalse,
        );
      });

      test('caseInsensitiveEquals', () {
        const str = 'hello, world!';
        expect(str.caseInsensitiveEquals(str), isTrue);
        expect(str.caseInsensitiveEquals('HELLO, WORLD!'), isTrue);
        expect(str.caseInsensitiveEquals('hElLo, WoRlD!'), isTrue);
        expect(str.caseInsensitiveEquals('hello'), isFalse);
        expect(str.caseInsensitiveEquals(''), isFalse);
        expect(str.caseInsensitiveEquals(null), isFalse);
        expect(''.caseInsensitiveEquals(''), isTrue);
        expect(''.caseInsensitiveEquals(null), isFalse);

        // Complete match.
        expect(
          str.caseInsensitiveEquals(RegExp('h.*o.*', caseSensitive: false)),
          isTrue,
        );
        // Incomplete match.
        expect(
          str.caseInsensitiveEquals(RegExp('h.*o', caseSensitive: false)),
          isFalse,
        );
        // No match.
        expect(
          str.caseInsensitiveEquals(
            RegExp('hello.* this does not match', caseSensitive: false),
          ),
          isFalse,
        );
      });

      test('caseInsensitiveAllMatches', () {
        const str = 'This is a TEST. Test string is "test"';
        final matches = 'test'.caseInsensitiveAllMatches(str).toList();
        expect(matches.length, equals(3));

        // First match: 'TEST'
        expect(matches[0].start, equals(10));
        expect(matches[0].end, equals(14));

        // Second match: 'Test'
        expect(matches[1].start, equals(16));
        expect(matches[1].end, equals(20));

        // Third match: 'test'
        expect(matches[2].start, equals(32));
        expect(matches[2].end, equals(36));

        // Dart's allMatches returns 1 char matches when pattern is an empty string
        expect(
          ''.caseInsensitiveAllMatches('hello world').length,
          equals('hello world'.length + 1),
        );
        expect('*'.caseInsensitiveAllMatches('hello world'), isEmpty);
        expect('test'.caseInsensitiveAllMatches(''), isEmpty);
        expect('test'.caseInsensitiveAllMatches(null), isEmpty);
      });
    });

    group('BoolExtension', () {
      test('boolCompare', () {
        expect(true.boolCompare(true), equals(0));
        expect(false.boolCompare(false), equals(0));
        expect(true.boolCompare(false), equals(-1));
        expect(false.boolCompare(true), equals(1));
      });
    });

    group('ProvidedControllerMixin', () {
      setUp(() {
        setGlobal(IdeTheme, IdeTheme());
      });

      testWidgets(
        'updates controller when provided controller changes',
        (WidgetTester tester) async {
          final controller1 = TestProvidedController('id_1');
          final controller2 = TestProvidedController('id_2');
          final controllerNotifier =
              ValueNotifier<TestProvidedController>(controller1);

          final provider = ValueListenableBuilder<TestProvidedController>(
            valueListenable: controllerNotifier,
            builder: (context, controller, _) {
              return Provider<TestProvidedController>.value(
                value: controller,
                child: Builder(
                  builder: (context) {
                    return wrapSimple(
                      const TestStatefulWidget(),
                    );
                  },
                ),
              );
            },
          );

          await tester.pumpWidget(provider);
          expect(find.text('Value 1'), findsOneWidget);
          expect(find.text('Controller id_1'), findsOneWidget);

          controllerNotifier.value = controller2;
          await tester.pumpAndSettle();

          expect(find.text('Value 2'), findsOneWidget);
          expect(find.text('Controller id_2'), findsOneWidget);
        },
      );
    });

    group('subtractMaps', () {
      test('subtracts non-null maps', () {
        final subtract = {1: 'subtract'};
        final from = {1: 1.0, 2: 2.0};
        _SubtractionResult? elementSubtractor({
          required String? subtract,
          required double? from,
        }) =>
            _SubtractionResult(subtract: subtract, from: from);

        final result = subtractMaps<int, double, String, _SubtractionResult>(
          subtract: subtract,
          from: from,
          subtractor: elementSubtractor,
        );

        expect(
          const SetEquality<int>().equals(result.keys.toSet(), {1, 2}),
          true,
        );
        expect(
          result[1],
          equals(_SubtractionResult(subtract: 'subtract', from: 1.0)),
        );
        expect(
          result[2],
          equals(_SubtractionResult(subtract: null, from: 2.0)),
        );
      });

      test('subtracts null', () {
        final from = {1: 1.0};
        _SubtractionResult? elementSubtractor({
          required String? subtract,
          required double? from,
        }) =>
            _SubtractionResult(subtract: subtract, from: from);

        final result = subtractMaps<int, double, String, _SubtractionResult>(
          subtract: null,
          from: from,
          subtractor: elementSubtractor,
        );

        expect(const SetEquality<int>().equals(result.keys.toSet(), {1}), true);
        expect(
          result[1],
          equals(_SubtractionResult(subtract: null, from: 1.0)),
        );
      });

      test('subtracts from null', () {
        final subtract = {1: 'subtract'};
        _SubtractionResult? elementSubtractor({
          required String? subtract,
          required double? from,
        }) =>
            _SubtractionResult(subtract: subtract, from: from);

        final result = subtractMaps<int, double, String, _SubtractionResult>(
          subtract: subtract,
          from: null,
          subtractor: elementSubtractor,
        );

        expect(const SetEquality<int>().equals(result.keys.toSet(), {1}), true);
        expect(
          result[1],
          equals(_SubtractionResult(subtract: 'subtract', from: null)),
        );
      });
    });
  });

  group('joinWithTrailing', () {
    test('joins no items', () {
      expect(<String>[].joinWithTrailing(':'), equals(''));
    });
    test(' joins 1 item', () {
      expect(['A'].joinWithTrailing(':'), equals('A:'));
    });
    test(' joins multiple items', () {
      expect(['A', 'B', 'C'].joinWithTrailing(':'), equals('A:B:C:'));
    });
  });

  test('devtoolsAssetsBasePath', () {
    // This is how a DevTools url will be structured when DevTools is served
    // directly from DDS using the `--observe` flag.
    expect(
      devtoolsAssetsBasePath(
        origin: 'http://127.0.0.1:61962',
        path: '/mb9Sw4gCYvU=/devtools/performance',
      ),
      equals('http://127.0.0.1:61962/mb9Sw4gCYvU=/devtools'),
    );
    // This is how a DevTools url will be structured when served from DevTools
    // server (e.g. from Flutter tools and from the `dart devtools` command).
    expect(
      devtoolsAssetsBasePath(
        origin: 'http://127.0.0.1:61962',
        path: '/performance',
      ),
      equals('http://127.0.0.1:61962'),
    );
  });
}

class _SubtractionResult {
  _SubtractionResult({
    required this.subtract,
    required this.from,
  });
  final String? subtract;
  final double? from;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }

    return other is _SubtractionResult &&
        other.subtract == subtract &&
        other.from == from;
  }

  @override
  int get hashCode => Object.hash(subtract, from);

  @override
  String toString() => '$from - $subtract';
}

class TestProvidedController {
  TestProvidedController(this.id);

  final String id;
}

class TestStatefulWidget extends StatefulWidget {
  const TestStatefulWidget({Key? key}) : super(key: key);

  @override
  State<TestStatefulWidget> createState() => _TestStatefulWidgetState();
}

class _TestStatefulWidgetState extends State<TestStatefulWidget>
    with ProvidedControllerMixin<TestProvidedController, TestStatefulWidget> {
  int _value = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
    _value++;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Value $_value'),
        Text('Controller ${controller.id}'),
      ],
    );
  }
}

// This was generated from a canvas with font size 14.0.
const asciiMeasurements = [
  0,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  0,
  3.8896484375,
  3.8896484375,
  3.8896484375,
  3.8896484375,
  3.8896484375,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  4.6619873046875,
  0,
  4.6619873046875,
  4.6619873046875,
  3.8896484375,
  3.8896484375,
  4.9697265625,
  7.7861328125,
  7.7861328125,
  12.4482421875,
  9.337890625,
  2.6728515625,
  4.662109375,
  4.662109375,
  5.4482421875,
  8.17578125,
  3.8896484375,
  4.662109375,
  3.8896484375,
  3.8896484375,
  7.7861328125,
  7.7861328125,
  7.7861328125,
  7.7861328125,
  7.7861328125,
  7.7861328125,
  7.7861328125,
  7.7861328125,
  7.7861328125,
  7.7861328125,
  3.8896484375,
  3.8896484375,
  8.17578125,
  8.17578125,
  8.17578125,
  7.7861328125,
  14.2119140625,
  9.337890625,
  9.337890625,
  10.1103515625,
  10.1103515625,
  9.337890625,
  8.5517578125,
  10.8896484375,
  10.1103515625,
  3.8896484375,
  7,
  9.337890625,
  7.7861328125,
  11.662109375,
  10.1103515625,
  10.8896484375,
  9.337890625,
  10.8896484375,
  10.1103515625,
  9.337890625,
  8.5517578125,
  10.1103515625,
  9.337890625,
  13.2138671875,
  9.337890625,
  9.337890625,
  8.5517578125,
  3.8896484375,
  3.8896484375,
  3.8896484375,
  6.5693359375,
  7.7861328125,
  4.662109375,
  7.7861328125,
  7.7861328125,
  7,
  7.7861328125,
  7.7861328125,
  3.8896484375,
  7.7861328125,
  7.7861328125,
  3.1103515625,
  3.1103515625,
  7,
  3.1103515625,
  11.662109375,
  7.7861328125,
  7.7861328125,
  7.7861328125,
  7.7861328125,
  4.662109375,
  7,
  3.8896484375,
  7.7861328125,
  7,
  10.1103515625,
  7,
  7,
  7,
  4.67578125,
  3.63671875,
  4.67578125,
  8.17578125,
  0,
];
