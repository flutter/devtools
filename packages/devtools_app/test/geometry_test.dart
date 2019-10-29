// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/geometry.dart';
import 'package:devtools_app/src/ui/fake_flutter/fake_flutter.dart'
    hide TypeMatcher;

import 'package:test/test.dart';

void main() {
  group('VerticalLineSegment', () {
    test('constructor enforces vertical', () {
      expect(
        () {
          VerticalLineSegment(const Offset(10, 20), const Offset(11, 40));
        },
        throwsA(const TypeMatcher<AssertionError>()),
      );
      expect(
        () {
          VerticalLineSegment(const Offset(10, 20), const Offset(10, 40));
        },
        isNot(throwsA(const TypeMatcher<AssertionError>())),
      );
    });

    test('intersection', () {
      final line =
          VerticalLineSegment(const Offset(10, 10), const Offset(10, 20));
      var rect = const Rect.fromLTRB(0.0, 0.0, 5.0, 5.0);
      expect(line.crossAxisIntersects(rect), isFalse);
      expect(line.intersects(rect), isFalse);
      rect = const Rect.fromLTRB(5.0, 5.0, 15.0, 15.0);
      expect(line.crossAxisIntersects(rect), isTrue);
      expect(line.intersects(rect), isTrue);
      rect = const Rect.fromLTRB(5.0, 15.0, 15.0, 25.0);
      expect(line.crossAxisIntersects(rect), isTrue);
      expect(line.intersects(rect), isTrue);
      rect = const Rect.fromLTRB(5.0, 11.0, 15.0, 19.0);
      expect(line.crossAxisIntersects(rect), isTrue);
      expect(line.intersects(rect), isTrue);
      rect = const Rect.fromLTRB(5.0, 25.0, 15.0, 30.0);
      expect(line.crossAxisIntersects(rect), isTrue);
      expect(line.intersects(rect), isFalse);
    });
  });

  group('HorizontalLineSegment', () {
    test('constructor enforces horizontal', () {
      expect(
        () {
          HorizontalLineSegment(const Offset(10, 20), const Offset(40, 21));
        },
        throwsA(const TypeMatcher<AssertionError>()),
      );
      expect(
        () {
          HorizontalLineSegment(const Offset(10, 20), const Offset(40, 20));
        },
        isNot(throwsA(const TypeMatcher<AssertionError>())),
      );
    });

    test('intersection', () {
      final line =
      HorizontalLineSegment(const Offset(10, 10), const Offset(20, 10));
      var rect = const Rect.fromLTRB(0.0, 0.0, 5.0, 5.0);
      expect(line.crossAxisIntersects(rect), isFalse);
      expect(line.intersects(rect), isFalse);
      rect = const Rect.fromLTRB(5.0, 5.0, 15.0, 15.0);
      expect(line.crossAxisIntersects(rect), isTrue);
      expect(line.intersects(rect), isTrue);
      rect = const Rect.fromLTRB(15.0, 5.0, 25.0, 15.0);
      expect(line.crossAxisIntersects(rect), isTrue);
      expect(line.intersects(rect), isTrue);
      rect = const Rect.fromLTRB(11.0, 5.0, 19.0, 15.0);
      expect(line.crossAxisIntersects(rect), isTrue);
      expect(line.intersects(rect), isTrue);
      rect = const Rect.fromLTRB(25.0, 5.0, 30.0, 15.0);
      expect(line.crossAxisIntersects(rect), isTrue);
      expect(line.intersects(rect), isFalse);
    });
  });
}
