// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:devtools_app/src/geometry.dart';

import 'package:test/test.dart';

void main() {
  group('LineSegment', () {
    test('zoomedXPosition', () {
      expect(
        LineSegment.zoomedXPosition(x: 10, zoom: 2.0, unzoomableOffset: 5),
        equals(15.0),
      );
      expect(
        LineSegment.zoomedXPosition(x: 10, zoom: 2.0, unzoomableOffset: 10),
        equals(10.0),
      );
      expect(
        () {
          LineSegment.zoomedXPosition(x: 10, zoom: 2.0, unzoomableOffset: 11);
        },
        throwsA(const TypeMatcher<AssertionError>()),
      );
    });
  });

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
      final line = VerticalLineSegment(
        const Offset(10, 10),
        const Offset(10, 20),
      );
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

    test('compareTo', () {
      final a = VerticalLineSegment(
        const Offset(0.0, 0.0),
        const Offset(0.0, 10.0),
      );
      final b = VerticalLineSegment(
        const Offset(1.0, 0.0),
        const Offset(1.0, 10.0),
      );
      final c = VerticalLineSegment(
        const Offset(2.0, 0.0),
        const Offset(2.0, 10.0),
      );
      final d = VerticalLineSegment(
        const Offset(0.0, 11.0),
        const Offset(0.0, 20.0),
      );
      expect(a.compareTo(b), equals(-1));
      expect(a.compareTo(d), equals(-1));
      expect(d.compareTo(b), equals(-1));
      expect(c.compareTo(b), equals(1));
    });

    test('toZoomed', () {
      final line = VerticalLineSegment(
        const Offset(10, 10),
        const Offset(10, 20),
      );
      var zoomedLine = line.toZoomed(
        zoom: 2.0,
        unzoomableOffsetLineStart: 5.0,
        unzoomableOffsetLineEnd: 5.0,
      );
      expect(zoomedLine.x, equals(15.0));

      zoomedLine = line.toZoomed(
        zoom: 2.0,
        unzoomableOffsetLineStart: 9.0,
        unzoomableOffsetLineEnd: 9.0,
      );
      expect(zoomedLine.x, equals(11.0));

      zoomedLine = line.toZoomed(
        zoom: 2.0,
        unzoomableOffsetLineStart: 10.0,
        unzoomableOffsetLineEnd: 10.0,
      );
      expect(zoomedLine.x, equals(10.0));
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
      final line = HorizontalLineSegment(
        const Offset(10, 10),
        const Offset(20, 10),
      );
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

    test('compareTo', () {
      final a = HorizontalLineSegment(
        const Offset(0.0, 0.0),
        const Offset(10.0, 0.0),
      );
      final b = HorizontalLineSegment(
        const Offset(0.0, 1.0),
        const Offset(10.0, 1.0),
      );
      final c = HorizontalLineSegment(
        const Offset(0.0, 2.0),
        const Offset(10.0, 2.0),
      );
      final d = HorizontalLineSegment(
        const Offset(11.0, 0.0),
        const Offset(20.0, 0.0),
      );
      expect(a.compareTo(b), equals(-1));
      expect(a.compareTo(d), equals(-1));
      expect(d.compareTo(b), equals(-1));
      expect(c.compareTo(b), equals(1));
    });

    test('toZoomed', () {
      final line = HorizontalLineSegment(
        const Offset(10, 10),
        const Offset(20, 10),
      );
      var zoomedLine = line.toZoomed(
        zoom: 2.0,
        unzoomableOffsetLineStart: 6.0,
        unzoomableOffsetLineEnd: 5.0,
      );
      expect(zoomedLine.start.dx, equals(14.0));
      expect(zoomedLine.end.dx, equals(35.0));

      zoomedLine = line.toZoomed(
        zoom: 2.0,
        unzoomableOffsetLineStart: 9.0,
        unzoomableOffsetLineEnd: 9.0,
      );
      expect(zoomedLine.start.dx, equals(11.0));
      expect(zoomedLine.end.dx, equals(31.0));

      zoomedLine = line.toZoomed(
        zoom: 2.0,
        unzoomableOffsetLineStart: 10.0,
        unzoomableOffsetLineEnd: 10.0,
      );
      expect(zoomedLine.start.dx, equals(10.0));
      expect(zoomedLine.end.dx, equals(30.0));
    });
  });
}
