// Copyright 2018 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:collection/collection.dart';
import 'package:devtools_app/src/shared/primitives/utils.dart';
import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('utils', () {
    group('durationText', () {
      test('infers unit based on duration', () {
        expect(durationText(Duration.zero), equals('0 μs'));
        expect(
          durationText(const Duration(microseconds: 100)),
          equals('0.1 ms'),
        );
        expect(durationText(const Duration(microseconds: 99)), equals('99 μs'));
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
        expect(durationText(const Duration(microseconds: 99)), equals('99 μs'));
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
          durationText(const Duration(microseconds: 1000), includeUnit: false),
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
        expect(() {
          durationText(Duration.zero, allowRoundingToZero: false);
        }, throwsAssertionError);

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
        final timeRange = TimeRange(start: 1000, end: 8000);

        expect(timeRange.duration.inMicroseconds, equals(7000));
        expect(timeRange.toString(), equals('[1000 μs - 8000 μs]'));
        expect(
          timeRange.toString(unit: TimeUnit.milliseconds),
          equals('[1 ms - 8 ms]'),
        );
      });

      test('containsRange', () {
        final t = TimeRange(start: 100, end: 200);
        final containsStart = TimeRange(start: 50, end: 150);
        final containsStartAndEnd = TimeRange(start: 125, end: 175);
        final containsEnd = TimeRange(start: 150, end: 250);
        final invertedContains = TimeRange(start: 50, end: 250);
        final containsNeither = TimeRange(start: 300, end: 400);

        expect(t.containsRange(containsStart), isFalse);
        expect(t.containsRange(containsStartAndEnd), isTrue);
        expect(t.containsRange(containsEnd), isFalse);
        expect(t.containsRange(invertedContains), isFalse);
        expect(t.containsRange(containsNeither), isFalse);
      });

      test('throws exception when start is after end', () {
        expect(() {
          TimeRange(start: 2000, end: 1000);
        }, throwsAssertionError);
      });
    });

    group('TimeRangeBuilder', () {
      test('throws if start or end are not set', () {
        expect(() => TimeRangeBuilder().build(), throwsStateError);
        expect(() => TimeRangeBuilder(start: 1000).build(), throwsStateError);
        expect(() => TimeRangeBuilder(end: 1000).build(), throwsStateError);
        expect(
          () => (TimeRangeBuilder()..start = 1000).build(),
          throwsStateError,
        );
        expect(
          () => (TimeRangeBuilder()..end = 1000).build(),
          throwsStateError,
        );
      });

      test('throws error if start is after end', () {
        expect(
          () => TimeRangeBuilder(start: 2000, end: 1000).build(),
          throwsAssertionError,
        );
      });

      test('builds expected TimeRange', () {
        expect(
          TimeRangeBuilder(start: 1000, end: 2000).build(),
          TimeRange(start: 1000, end: 2000),
        );
        expect(
          TimeRangeBuilder(start: 1000, end: 1000).build(),
          TimeRange(start: 1000, end: 1000),
        );
        expect(
          (TimeRangeBuilder(start: 150)..end = 250).build(),
          TimeRange(start: 150, end: 250),
        );
        expect(
          (TimeRangeBuilder(end: 400)..start = 300).build(),
          TimeRange(start: 300, end: 400),
        );
        expect(
          (TimeRangeBuilder()
                ..start = 0
                ..end = 100)
              .build(),
          TimeRange.ofDuration(100),
        );
      });
    });

    test('formatDateTime', () {
      expect(formatDateTime(DateTime(2020, 1, 16, 13)), '13:00:00.000');
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

      name =
          '__CompactLinkedHashSet&_HashFieldBase&_HashBase&_OperatorEquals'
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
          safeDivide(double.nan, double.negativeInfinity, ifNotFinite: 50.0),
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

    group('SafeListOperations', () {
      test('safeFirst', () {
        final list = <int?>[];
        final iterable = list;
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

      test('safeSublist', () {
        expect([1, 2, 3].safeSublist(-1, 2), [1, 2]);
        expect([1, 2, 3].safeSublist(0, 6), [1, 2, 3]);
        expect([1, 2, 3].safeSublist(2, 1), []);
      });
    });
  });

  group('LogicalKeySetExtension', () {
    testWidgets('meta non-mac', (WidgetTester tester) async {
      final keySet = LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyP,
      );
      expect(keySet.describeKeys(), 'Meta-P');
    });

    testWidgets('meta mac', (WidgetTester tester) async {
      final keySet = LogicalKeySet(
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.keyP,
      );
      expect(keySet.describeKeys(isMacOS: true), '⌘P');
    });

    testWidgets('ctrl', (WidgetTester tester) async {
      final keySet = LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyP,
      );
      expect(keySet.describeKeys(), 'Control-P');
    });
  });

  group('ListExtension', () {
    test('joinWith generates correct list', () {
      expect([1, 2, 3, 4].joinWith(0), equals([1, 0, 2, 0, 3, 0, 4]));
      expect([1].joinWith(0), equals([1]));
      expect(['a', 'b'].joinWith('z'), equals(['a', 'z', 'b']));
    });
  });

  group('NullableListExtension', () {
    test('isNullOrEmpty', () {
      List<int>? nullableList;
      expect(nullableList.isNullOrEmpty, true);
      nullableList = [];
      expect(nullableList.isNullOrEmpty, true);
      nullableList.add(1);
      expect(nullableList.isNullOrEmpty, false);
    });
  });

  group('SetExtension', () {
    test('containsAny', () {
      final test = {1, 2, 3, 4};
      final subSet = {1, 2};
      final disjointSet = {5, 6, 7};
      expect(test.containsAny(test), true);
      expect(test.containsAny(subSet), true);
      expect(test.containsAny(disjointSet), false);
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

  group('subtractMaps', () {
    test('subtracts non-null maps', () {
      final subtract = {1: 'subtract'};
      final from = {1: 1.0, 2: 2.0};
      _SubtractionResult? elementSubtractor({
        required String? subtract,
        required double? from,
      }) => _SubtractionResult(subtract: subtract, from: from);

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
      expect(result[2], equals(_SubtractionResult(subtract: null, from: 2.0)));
    });

    test('subtracts null', () {
      final from = {1: 1.0};
      _SubtractionResult? elementSubtractor({
        required String? subtract,
        required double? from,
      }) => _SubtractionResult(subtract: subtract, from: from);

      final result = subtractMaps<int, double, String, _SubtractionResult>(
        subtract: null,
        from: from,
        subtractor: elementSubtractor,
      );

      expect(const SetEquality<int>().equals(result.keys.toSet(), {1}), true);
      expect(result[1], equals(_SubtractionResult(subtract: null, from: 1.0)));
    });

    test('subtracts from null', () {
      final subtract = {1: 'subtract'};
      _SubtractionResult? elementSubtractor({
        required String? subtract,
        required double? from,
      }) => _SubtractionResult(subtract: subtract, from: from);

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
    // This is how a DevTools url will be structured when DevTools is ran
    // locally using `dt run`.
    expect(
      devtoolsAssetsBasePath(origin: 'http://127.0.0.1:9100/', path: '/home'),
      equals('http://127.0.0.1:9100'),
    );
    // This is how a DevTools url will be structured when it has query
    // parameters (e.g. when it is connected to an app).
    expect(
      devtoolsAssetsBasePath(
        origin:
            'http://127.0.0.1:9100/home?uri=ws://127.0.0.1:50416/Hnr3zwp99d0=/ws',
        path: '/home',
      ),
      equals('http://127.0.0.1:9100'),
    );
  });

  group('ansiToColor', () {
    test('lightens dark colors on dark backgrounds', () {
      const black = Color.fromRGBO(0, 0, 0, 1);
      final adjusted = ansiToColor([0, 0, 0], brightness: Brightness.dark)!;
      expect(adjusted, isNot(equals(black)));
      expect(adjusted.computeLuminance(), greaterThan(0.2));
    });

    test('darkens light colors on light backgrounds', () {
      const white = Color.fromRGBO(255, 255, 255, 1);
      final adjusted = ansiToColor([255, 255, 255], brightness: Brightness.light)!;
      expect(adjusted, isNot(equals(white)));
      expect(adjusted.computeLuminance(), lessThan(0.5));
    });

    test('preserves readable colors', () {
      const red = Color.fromRGBO(187, 0, 0, 1);
      expect(
        ansiToColor([187, 0, 0], brightness: Brightness.dark),
        equals(red),
      );
      expect(
        ansiToColor([187, 0, 0], brightness: Brightness.light),
        equals(red),
      );
    });
  });
  });
}

class _SubtractionResult {
  _SubtractionResult({required this.subtract, required this.from});
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
