// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_tool/commands/update_version.dart';
import 'package:test/test.dart';

void main() {
  group('calculateNewVersion', () {
    test('release type strips pre-release when on dev version', () {
      expect(calculateNewVersion('2.28.0-dev.0', 'release'), '2.28.0');
      expect(calculateNewVersion('2.28.0-dev.5', 'release'), '2.28.0');
    });

    test('release type increments minor version when not on dev version', () {
      expect(calculateNewVersion('2.28.0', 'release'), '2.29.0');
      expect(calculateNewVersion('2.28.1', 'release'), '2.29.0');
    });

    test('dev type increments dev version', () {
      expect(calculateNewVersion('1.2.3', 'dev'), '1.2.3-dev.0');
      expect(calculateNewVersion('1.2.3-dev.4', 'dev'), '1.2.3-dev.5');
    });

    test('patch type increments patch version', () {
      expect(calculateNewVersion('1.2.3', 'patch'), '1.2.4');
      expect(calculateNewVersion('1.2.3-dev.4', 'patch'), '1.2.4');
    });

    test('minor type increments minor version', () {
      expect(calculateNewVersion('1.2.3', 'minor'), '1.3.0');
      expect(calculateNewVersion('1.2.3-dev.4', 'minor'), '1.3.0');
    });

    test('major type increments major version', () {
      expect(calculateNewVersion('1.2.3', 'major'), '2.0.0');
      expect(calculateNewVersion('1.2.3-dev.4', 'major'), '2.0.0');
    });
  });
}
