// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('utils', () {
    test('prettyPrintBytes', () {
      const int kb = 1024;
      const int mb = 1024 * kb;

      expect(
        prettyPrintBytes(
          51,
          kbFractionDigits: 1,
          includeUnit: true,
        ),
        '51 B',
      );
      expect(
        prettyPrintBytes(
          52,
          kbFractionDigits: 1,
          includeUnit: true,
        ),
        '0.1 KB',
      );

      expect(prettyPrintBytes(kb), '1');
      expect(prettyPrintBytes(kb + 100, kbFractionDigits: 1), '1.1');
      expect(prettyPrintBytes(kb + 150, kbFractionDigits: 2), '1.15');
      expect(prettyPrintBytes(kb, includeUnit: true), '1 KB');
      expect(prettyPrintBytes(kb * 1000, includeUnit: true), '1,000 KB');

      expect(prettyPrintBytes(mb), '1.0');
      expect(prettyPrintBytes(mb + kb * 100), '1.1');
      expect(prettyPrintBytes(mb + kb * 150, mbFractionDigits: 2), '1.15');
      expect(prettyPrintBytes(mb, includeUnit: true), '1.0 MB');
      expect(prettyPrintBytes(mb - kb, includeUnit: true), '1,023 KB');
    });

    test('printKb', () {
      const int kb = 1024;

      expect(printKB(0), '0');
      expect(printKB(1), '1');
      expect(printKB(kb - 1), '1');
      expect(printKB(kb), '1');
      expect(printKB(kb + 1), '2');
      expect(printKB(2000), '2');
    });

    test('printMb', () {
      const int mb = 1024 * 1024;

      expect(printMB(10 * mb, fractionDigits: 0), '10');
      expect(printMB(10 * mb), '10.0');
      expect(printMB(10 * mb, fractionDigits: 2), '10.00');

      expect(printMB(1000 * mb, fractionDigits: 0), '1000');
      expect(printMB(1000 * mb), '1000.0');
      expect(printMB(1000 * mb, fractionDigits: 2), '1000.00');
    });

    test('msAsText', () {
      expect(msText(const Duration(microseconds: 3111)), equals('3.1 ms'));
      expect(
        msText(const Duration(microseconds: 3199), includeUnit: false),
        equals('3.2'),
      );
      expect(
        msText(const Duration(microseconds: 3159), fractionDigits: 2),
        equals('3.16 ms'),
      );
      expect(
        msText(const Duration(microseconds: 3111), fractionDigits: 3),
        equals('3.111 ms'),
      );
      expect(
        msText(const Duration(milliseconds: 3)),
        equals('3.0 ms'),
      );
    });

    test('nullSafeMin', () {
      expect(nullSafeMin(1, 2), equals(1));
      expect(nullSafeMin(1, null), equals(1));
      expect(nullSafeMin(null, 2), equals(2));
      expect(nullSafeMin(null, null), equals(null));
    });

    test('nullSafeMin', () {
      expect(nullSafeMax(1, 2), equals(2));
      expect(nullSafeMax(1, null), equals(1));
      expect(nullSafeMax(null, 2), equals(2));
      expect(nullSafeMax(null, null), equals(null));
    });

    test('log2', () {
      expect(log2(1), equals(0));
      expect(log2(1.5), equals(0));
      expect(log2(2), equals(1));
      expect(log2(3), equals(1));
      expect(log2(4), equals(2));
    });

    test('executeWithDelay', () async {
      const delayMs = 500;
      int n = 1;
      int start;
      int end;

      // Condition n >= 2 is false, so we should execute with a delay.
      start = DateTime.now().millisecondsSinceEpoch;
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
      expect((end - start - delayMs).abs(), lessThan(epsilonMs));

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
      expect(end - start, lessThan(400));
    });

    test('timeRange', () {
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

    test('formatDateTime', () {
      expect(formatDateTime(DateTime(2020, 1, 16, 13)), '1:00:00.000 PM');
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
        devToolsQueryParams('http://localhost:123/#/?key=value.json&key2=123'),
        equals({
          'key': 'value.json',
          'key2': '123',
        }),
      );
      expect(
        devToolsQueryParams(
            'http://localhost:9101/#/appsize?key=value.json&key2=123'),
        equals({
          'key': 'value.json',
          'key2': '123',
        }),
      );
    });

    group('pluralize', () {
      test('zero', () {
        expect(pluralize('cat', 0), 'cats');
      });

      test('one', () {
        expect(pluralize('cat', 1), 'cat');
      });

      test('many', () {
        expect(pluralize('cat', 2), 'cats');
      });

      test('irregular plurals', () {
        expect(pluralize('index', 1, plural: 'indices'), 'index');
        expect(pluralize('index', 2, plural: 'indices'), 'indices');
      });
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
            50.0);
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
      Reporter reporter;
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

      ValueReporter<String> reporter;
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
        final list = <int>[];
        final Iterable<int> iterable = list;
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
        final list = <int>[];
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

    group('parseCssHexColor', () {
      test('parses 6 digit hex colors', () {
        expect(parseCssHexColor('#000000'), equals(Colors.black));
        expect(parseCssHexColor('000000'), equals(Colors.black));
        expect(parseCssHexColor('#ffffff'), equals(Colors.white));
        expect(parseCssHexColor('ffffff'), equals(Colors.white));
        expect(parseCssHexColor('#ff0000'), equals(const Color(0xFFFF0000)));
        expect(parseCssHexColor('ff0000'), equals(const Color(0xFFFF0000)));
      });
      test('parses 3 digit hex colors', () {
        expect(parseCssHexColor('#000'), equals(Colors.black));
        expect(parseCssHexColor('000'), equals(Colors.black));
        expect(parseCssHexColor('#fff'), equals(Colors.white));
        expect(parseCssHexColor('fff'), equals(Colors.white));
        expect(parseCssHexColor('#f30'), equals(const Color(0xFFFF3300)));
        expect(parseCssHexColor('f30'), equals(const Color(0xFFFF3300)));
      });
      test('parses 8 digit hex colors', () {
        expect(parseCssHexColor('#000000ff'), equals(Colors.black));
        expect(parseCssHexColor('000000ff'), equals(Colors.black));
        expect(
            parseCssHexColor('#00000000'), equals(Colors.black.withAlpha(0)));
        expect(parseCssHexColor('00000000'), equals(Colors.black.withAlpha(0)));
        expect(parseCssHexColor('#ffffffff'), equals(Colors.white));
        expect(parseCssHexColor('ffffffff'), equals(Colors.white));
        expect(
            parseCssHexColor('#ffffff00'), equals(Colors.white.withAlpha(0)));
        expect(parseCssHexColor('ffffff00'), equals(Colors.white.withAlpha(0)));
        expect(parseCssHexColor('#ff0000bb'),
            equals(const Color(0xFF0000).withAlpha(0xbb)));
        expect(parseCssHexColor('ff0000bb'),
            equals(const Color(0xFF0000).withAlpha(0xbb)));
      });
      test('parses 4 digit hex colors', () {
        expect(parseCssHexColor('#000f'), equals(Colors.black));
        expect(parseCssHexColor('000f'), equals(Colors.black));
        expect(parseCssHexColor('#0000'), equals(Colors.black.withAlpha(0)));
        expect(parseCssHexColor('0000'), equals(Colors.black.withAlpha(0)));
        expect(parseCssHexColor('#ffff'), equals(Colors.white));
        expect(parseCssHexColor('ffff'), equals(Colors.white));
        expect(parseCssHexColor('#fff0'), equals(Colors.white.withAlpha(0)));
        expect(parseCssHexColor('ffffff00'), equals(Colors.white.withAlpha(0)));
        expect(parseCssHexColor('#f00b'),
            equals(const Color(0xFF0000).withAlpha(0xbb)));
        expect(parseCssHexColor('f00b'),
            equals(const Color(0xFF0000).withAlpha(0xbb)));
      });
    });

    group('toCssHexColor', () {
      test('generates correct 8 digit CSS colors', () {
        expect(toCssHexColor(Colors.black), equals('#000000ff'));
        expect(toCssHexColor(Colors.white), equals('#ffffffff'));
        expect(toCssHexColor(const Color(0xFFAABBCC)), equals('#aabbccff'));
      });
    });

    group('ListExtension', () {
      test('joinWith generates correct list', () {
        expect([1, 2, 3, 4].joinWith(0), equals([1, 0, 2, 0, 3, 0, 4]));
        expect([1].joinWith(0), equals([1]));
        expect(['a', 'b'].joinWith('z'), equals(['a', 'z', 'b']));
      });
    });
  });
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
