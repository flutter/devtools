// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SemanticVersion', () {
    test('parse', () {
      expect(
        SemanticVersion.parse(
          '2.15.0-233.0.dev (dev) (Mon Oct 18 14:06:26 2021 -0700) on "ios_x64"',
        ).toString(),
        equals('2.15.0-233.0'),
      );
      expect(
        SemanticVersion.parse('2.15.0-178.1.beta').toString(),
        equals('2.15.0-178.1'),
      );
      expect(
        SemanticVersion.parse('2.6.0-12.0.pre.443').toString(),
        equals('2.6.0-12.0'),
      );

      expect(
        SemanticVersion.parse('2.6.0-1.2.dev+build.metadata').toString(),
        equals('2.6.0-1.2'),
      );

      expect(
        SemanticVersion.parse('2.6.0+build.metadata').toString(),
        equals('2.6.0'),
      );
    });

    test('downgrade', () {
      var version = SemanticVersion(
        major: 3,
        minor: 2,
        patch: 1,
        preReleaseMajor: 1,
        preReleaseMinor: 2,
      );
      expect(
        version.downgrade().toString(),
        equals('3.2.1'),
      );

      version = SemanticVersion(major: 3, minor: 2, patch: 1);
      expect(
        version.downgrade().toString(),
        equals('3.2.1'),
      );
      expect(
        version.downgrade(downgradeMajor: true).toString(),
        equals('2.2.1'),
      );
      expect(
        version.downgrade(downgradeMinor: true).toString(),
        equals('3.1.1'),
      );
      expect(
        version.downgrade(downgradePatch: true).toString(),
        equals('3.2.0'),
      );

      version = SemanticVersion(major: 3);
      expect(
        version
            .downgrade(
              downgradeMajor: true,
              downgradeMinor: true,
              downgradePatch: true,
            )
            .toString(),
        equals('2.0.0'),
      );
    });

    test('isVersionSupported', () {
      final supportedVersion = SemanticVersion(major: 1, minor: 1, patch: 1);
      expect(
        SemanticVersion().isSupported(minSupportedVersion: SemanticVersion()),
        isTrue,
      );
      expect(
        SemanticVersion(major: 1, minor: 1, patch: 2)
            .isSupported(minSupportedVersion: supportedVersion),
        isTrue,
      );
      expect(
        SemanticVersion(major: 1, minor: 2, patch: 1)
            .isSupported(minSupportedVersion: supportedVersion),
        isTrue,
      );
      expect(
        SemanticVersion(major: 2, minor: 1, patch: 1)
            .isSupported(minSupportedVersion: supportedVersion),
        isTrue,
      );
      expect(
        SemanticVersion(major: 2, minor: 1, patch: 1).isSupported(
          minSupportedVersion: SemanticVersion(major: 2, minor: 2, patch: 1),
        ),
        isFalse,
      );
    });

    test('compareTo', () {
      var version = SemanticVersion(major: 1, minor: 1, patch: 1);
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
      expect(
        version.compareTo(
          SemanticVersion(
            major: 1,
            minor: 1,
            patch: 1,
            preReleaseMajor: 0,
            preReleaseMinor: 0,
          ),
        ),
        equals(0),
      );

      expect(
        version.compareTo(
          SemanticVersion(major: 1, minor: 1, patch: 1, preReleaseMajor: 1),
        ),
        equals(1),
      );

      version = SemanticVersion(
        major: 1,
        minor: 1,
        patch: 1,
        preReleaseMajor: 1,
        preReleaseMinor: 2,
      );
      expect(
        version.compareTo(
          SemanticVersion(major: 1, minor: 1, patch: 1, preReleaseMajor: 1),
        ),
        equals(1),
      );
      expect(
        version.compareTo(
          SemanticVersion(
            major: 1,
            minor: 1,
            patch: 1,
            preReleaseMajor: 2,
            preReleaseMinor: 1,
          ),
        ),
        equals(-1),
      );
    });

    test('toString', () {
      expect(
        SemanticVersion(major: 1, minor: 1, patch: 1).toString(),
        equals('1.1.1'),
      );
      expect(
        SemanticVersion(major: 1, minor: 1, patch: 1, preReleaseMajor: 17)
            .toString(),
        equals('1.1.1-17'),
      );
      expect(
        SemanticVersion(
          major: 1,
          minor: 1,
          patch: 1,
          preReleaseMajor: 17,
          preReleaseMinor: 1,
        ).toString(),
        equals('1.1.1-17.1'),
      );
      expect(
        SemanticVersion(
          major: 1,
          minor: 1,
          patch: 1,
          preReleaseMinor: 1,
        ).toString(),
        equals('1.1.1-0.1'),
      );
    });
  });
}
