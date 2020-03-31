// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/version.dart';
import 'package:test/test.dart';

void main() {
  group('FlutterVersion', () {
    test('infers semantic version', () {
      var flutterVersion =
          FlutterVersion.parse({'frameworkVersion': '1.10.7-pre.42'});
      expect(flutterVersion.major, equals(1));
      expect(flutterVersion.minor, equals(10));
      expect(flutterVersion.patch, equals(7));

      flutterVersion =
          FlutterVersion.parse({'frameworkVersion': '1.10.7-pre42'});
      expect(flutterVersion.major, equals(1));
      expect(flutterVersion.minor, equals(10));
      expect(flutterVersion.patch, equals(7));

      flutterVersion =
          FlutterVersion.parse({'frameworkVersion': '1.10.11-pre42'});
      expect(flutterVersion.major, equals(1));
      expect(flutterVersion.minor, equals(10));
      expect(flutterVersion.patch, equals(11));

      flutterVersion =
          FlutterVersion.parse({'frameworkVersion': 'bad-version'});
      expect(flutterVersion.major, equals(0));
      expect(flutterVersion.minor, equals(0));
      expect(flutterVersion.patch, equals(0));
    });
  });

  group('SemanticVersion', () {
    test('isVersionSupported', () {
      final supportedVersion = SemanticVersion(major: 1, minor: 1, patch: 1);
      expect(
        SemanticVersion().isSupported(supportedVersion: SemanticVersion()),
        isTrue,
      );
      expect(
        SemanticVersion(major: 1, minor: 1, patch: 2)
            .isSupported(supportedVersion: supportedVersion),
        isTrue,
      );
      expect(
        SemanticVersion(major: 1, minor: 2, patch: 1)
            .isSupported(supportedVersion: supportedVersion),
        isTrue,
      );
      expect(
        SemanticVersion(major: 2, minor: 1, patch: 1)
            .isSupported(supportedVersion: supportedVersion),
        isTrue,
      );
      expect(
        SemanticVersion(major: 2, minor: 1, patch: 1).isSupported(
            supportedVersion: SemanticVersion(major: 2, minor: 2, patch: 1)),
        isFalse,
      );
    });

    test('compareTo', () {
      final version = SemanticVersion(major: 1, minor: 1, patch: 1);
      expect(
        version.compareTo(SemanticVersion(major: 1, minor: 1, patch: 2)),
        equals(-1),
      );
      expect(
        version.compareTo(SemanticVersion(major: 1, minor: 2, patch: 1)),
        equals(-1),
      );
      expect(
        version.compareTo(SemanticVersion(major: 2, minor: 1, patch: 1)),
        equals(-1),
      );
      expect(
        version.compareTo(SemanticVersion(major: 1, minor: 1)),
        equals(1),
      );
      expect(
        version.compareTo(SemanticVersion(major: 1, minor: 1, patch: 1)),
        equals(0),
      );
    });
  });
}
