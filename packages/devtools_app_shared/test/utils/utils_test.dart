// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        parseCssHexColor('#00000000'),
        equals(Colors.black.withAlpha(0)),
      );
      expect(parseCssHexColor('00000000'), equals(Colors.black.withAlpha(0)));
      expect(parseCssHexColor('#ffffffff'), equals(Colors.white));
      expect(parseCssHexColor('ffffffff'), equals(Colors.white));
      expect(
        parseCssHexColor('#ffffff00'),
        equals(Colors.white.withAlpha(0)),
      );
      expect(parseCssHexColor('ffffff00'), equals(Colors.white.withAlpha(0)));
      expect(
        parseCssHexColor('#ff0000bb'),
        equals(const Color(0x00ff0000).withAlpha(0xbb)),
      );
      expect(
        parseCssHexColor('ff0000bb'),
        equals(const Color(0x00ff0000).withAlpha(0xbb)),
      );
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
      expect(
        parseCssHexColor('#f00b'),
        equals(const Color(0x00ff0000).withAlpha(0xbb)),
      );
      expect(
        parseCssHexColor('f00b'),
        equals(const Color(0x00ff0000).withAlpha(0xbb)),
      );
    });
  });

  group('toCssHexColor', () {
    test('generates correct 8 digit CSS colors', () {
      expect(toCssHexColor(Colors.black), equals('#000000ff'));
      expect(toCssHexColor(Colors.white), equals('#ffffffff'));
      expect(toCssHexColor(const Color(0xFFAABBCC)), equals('#aabbccff'));
    });
  });
}
