// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/ui/hover.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _textSpan = TextSpan(
  children: [
    TextSpan(text: 'hello', style: TextStyle(fontWeight: FontWeight.bold)),
    TextSpan(text: ' '),
    TextSpan(text: 'world'),
    TextSpan(text: ' '),
    TextSpan(text: 'foo', style: TextStyle(fontWeight: FontWeight.bold)),
    TextSpan(text: '.'),
    TextSpan(text: 'bar'),
    TextSpan(text: '.'),
    TextSpan(text: 'baz', style: TextStyle(fontWeight: FontWeight.w100)),
    TextSpan(text: ' '),
    TextSpan(text: 'blah'),
  ],
);

void main() {
  test('wordForHover returns the correct word given the provided x offset', () {
    expect(wordForHover(10, _textSpan), 'hello');
    expect(wordForHover(100, _textSpan), 'world');
    expect(wordForHover(5000, _textSpan), '');
  });

  test(
    'wordForHover returns an empty string if there is no underlying word',
    () {
      expect(wordForHover(5000, _textSpan), '');
    },
  );

  test('wordForHover merges words linked with `.`', () {
    expect(wordForHover(200, _textSpan), 'foo');
    expect(wordForHover(250, _textSpan), 'foo.bar');
    expect(wordForHover(300, _textSpan), 'foo.bar.baz');
  });

  group('isPrimitiveValueOrNull', () {
    test('returns false for non-primitives values', () {
      expect(isPrimitiveValueOrNull('myVariable'), isFalse);
      expect(isPrimitiveValueOrNull('MyWidget'), isFalse);
      expect(isPrimitiveValueOrNull('MyClass'), isFalse);
    });

    test('returns true for null', () {
      expect(isPrimitiveValueOrNull('null'), isTrue);
    });

    test('returns true for ints', () {
      expect(isPrimitiveValueOrNull('10'), isTrue);
      expect(isPrimitiveValueOrNull('3'), isTrue);
      expect(isPrimitiveValueOrNull('255'), isTrue);
    });

    test('returns true for doubles', () {
      expect(isPrimitiveValueOrNull('.3'), isTrue);
      expect(isPrimitiveValueOrNull('1.7'), isTrue);
      expect(isPrimitiveValueOrNull('123.389'), isTrue);
    });

    test('returns true for bools', () {
      expect(isPrimitiveValueOrNull('true'), isTrue);
      expect(isPrimitiveValueOrNull('false'), isTrue);
    });

    test('returns true for strings', () {
      expect(isPrimitiveValueOrNull('"Hello World!"'), isTrue);
      expect(isPrimitiveValueOrNull("'Hello World!'"), isTrue);
    });
  });
}
