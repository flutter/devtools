// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlutterVersion', () {
    test('infers semantic version', () {
      var flutterVersion =
          FlutterVersion.parse({'frameworkVersion': '1.10.7-pre.42'});
      expect(flutterVersion.major, equals(1));
      expect(flutterVersion.minor, equals(10));
      expect(flutterVersion.patch, equals(7));
      expect(flutterVersion.preReleaseMajor, equals(42));
      expect(flutterVersion.preReleaseMinor, equals(0));

      flutterVersion =
          FlutterVersion.parse({'frameworkVersion': '1.10.7-pre42'});
      expect(flutterVersion.major, equals(1));
      expect(flutterVersion.minor, equals(10));
      expect(flutterVersion.patch, equals(7));
      expect(flutterVersion.preReleaseMajor, equals(42));
      expect(flutterVersion.preReleaseMinor, equals(0));

      flutterVersion =
          FlutterVersion.parse({'frameworkVersion': '1.10.11-pre42'});
      expect(flutterVersion.major, equals(1));
      expect(flutterVersion.minor, equals(10));
      expect(flutterVersion.patch, equals(11));
      expect(flutterVersion.preReleaseMajor, equals(42));
      expect(flutterVersion.preReleaseMinor, equals(0));

      flutterVersion =
          FlutterVersion.parse({'frameworkVersion': '2.3.0-17.0.pre.355'});
      expect(flutterVersion.major, equals(2));
      expect(flutterVersion.minor, equals(3));
      expect(flutterVersion.patch, equals(0));
      expect(flutterVersion.preReleaseMajor, equals(17));
      expect(flutterVersion.preReleaseMinor, equals(0));

      flutterVersion =
          FlutterVersion.parse({'frameworkVersion': '2.3.0-17.0.pre'});
      expect(flutterVersion.major, equals(2));
      expect(flutterVersion.minor, equals(3));
      expect(flutterVersion.patch, equals(0));
      expect(flutterVersion.preReleaseMajor, equals(17));
      expect(flutterVersion.preReleaseMinor, equals(0));

      flutterVersion = FlutterVersion.parse({'frameworkVersion': '2.3.0-17'});
      expect(flutterVersion.major, equals(2));
      expect(flutterVersion.minor, equals(3));
      expect(flutterVersion.patch, equals(0));
      expect(flutterVersion.preReleaseMajor, equals(17));
      expect(flutterVersion.preReleaseMinor, equals(0));

      flutterVersion = FlutterVersion.parse({'frameworkVersion': '2.3.0'});
      expect(flutterVersion.major, equals(2));
      expect(flutterVersion.minor, equals(3));
      expect(flutterVersion.patch, equals(0));
      expect(flutterVersion.preReleaseMajor, isNull);
      expect(flutterVersion.preReleaseMinor, isNull);

      flutterVersion =
          FlutterVersion.parse({'frameworkVersion': 'bad-version'});
      expect(flutterVersion.major, equals(0));
      expect(flutterVersion.minor, equals(0));
      expect(flutterVersion.patch, equals(0));
    });

    test('parses dart version correctly', () {
      var flutterVersion = FlutterVersion.parse({
        'frameworkVersion': '2.8.0',
        'dartSdkVersion': '2.15.0',
      });
      expect(flutterVersion.dartSdkVersion.toString(), equals('2.15.0'));
      flutterVersion = FlutterVersion.parse({
        'frameworkVersion': '2.8.0',
        'dartSdkVersion': '2.15.0 (build 2.15.0-178.1.beta)',
      });
      expect(flutterVersion.dartSdkVersion.toString(), equals('2.15.0-178.1'));
    });
  });

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
          supportedVersion: SemanticVersion(major: 2, minor: 2, patch: 1),
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
