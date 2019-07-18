// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('utils', () {
    test('printMb', () {
      const int MB = 1024 * 1024;

      expect(printMb(10 * MB, 0), '10');
      expect(printMb(10 * MB), '10.0');
      expect(printMb(10 * MB, 1), '10.0');
      expect(printMb(10 * MB, 2), '10.00');

      expect(printMb(1000 * MB, 0), '1000');
      expect(printMb(1000 * MB), '1000.0');
      expect(printMb(1000 * MB, 1), '1000.0');
      expect(printMb(1000 * MB, 2), '1000.00');
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
