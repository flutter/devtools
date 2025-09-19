// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/service.dart';
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

    group('identifies correct Flutter channel', () {
      test('uses channel string if it exists', () {
        expect(
            FlutterVersion.identifyChannel('ignored-version',
                channelStr: 'dev'),
            equals(FlutterChannel.dev));

        expect(
            FlutterVersion.identifyChannel('ignored-version',
                channelStr: 'beta'),
            equals(FlutterChannel.beta));

        expect(
            FlutterVersion.identifyChannel('ignored-version',
                channelStr: 'stable'),
            equals(FlutterChannel.stable));
      });

      test('identifies channel from version string', () {
        expect(FlutterVersion.identifyChannel('2.3.0-17.0.pre.355'),
            equals(FlutterChannel.dev));

        expect(FlutterVersion.identifyChannel('2.3.0-17.0.pre-355'),
            equals(FlutterChannel.dev));

        expect(FlutterVersion.identifyChannel('2.3.0-17.0.pre'),
            equals(FlutterChannel.beta));

        expect(FlutterVersion.identifyChannel('2.3.0'),
            equals(FlutterChannel.stable));

        expect(FlutterVersion.identifyChannel('bad-version'), isNull);

        expect(FlutterVersion.identifyChannel('1.10.11-pre42'), isNull);

        expect(FlutterVersion.identifyChannel('2.3.0-17'), isNull);
      });
    });

    group('Flutter channel', () {
      test('channel comparison', () {
        // FlutterChannel.dev comparison:
        // - compare to itself:
        expect(FlutterChannel.dev == FlutterChannel.dev, isTrue);
        expect(FlutterChannel.dev != FlutterChannel.dev, isFalse);
        expect(FlutterChannel.dev < FlutterChannel.dev, isFalse);
        expect(FlutterChannel.dev <= FlutterChannel.dev, isTrue);
        expect(FlutterChannel.dev > FlutterChannel.dev, isFalse);
        expect(FlutterChannel.dev >= FlutterChannel.dev, isTrue);
        // - compare to beta:
        expect(FlutterChannel.dev == FlutterChannel.beta, isFalse);
        expect(FlutterChannel.dev != FlutterChannel.beta, isTrue);
        expect(FlutterChannel.dev < FlutterChannel.beta, isTrue);
        expect(FlutterChannel.dev <= FlutterChannel.beta, isTrue);
        expect(FlutterChannel.dev > FlutterChannel.beta, isFalse);
        expect(FlutterChannel.dev >= FlutterChannel.beta, isFalse);
        // - compare to stable:
        expect(FlutterChannel.dev == FlutterChannel.stable, isFalse);
        expect(FlutterChannel.dev != FlutterChannel.stable, isTrue);
        expect(FlutterChannel.dev < FlutterChannel.stable, isTrue);
        expect(FlutterChannel.dev <= FlutterChannel.stable, isTrue);
        expect(FlutterChannel.dev > FlutterChannel.stable, isFalse);
        expect(FlutterChannel.dev >= FlutterChannel.stable, isFalse);

        // FlutterChannel.beta comparison:
        // - compare to dev:
        expect(FlutterChannel.beta == FlutterChannel.dev, isFalse);
        expect(FlutterChannel.beta != FlutterChannel.dev, isTrue);
        expect(FlutterChannel.beta < FlutterChannel.dev, isFalse);
        expect(FlutterChannel.beta <= FlutterChannel.dev, isFalse);
        expect(FlutterChannel.beta > FlutterChannel.dev, isTrue);
        expect(FlutterChannel.beta >= FlutterChannel.dev, isTrue);
        // - compare to itself:
        expect(FlutterChannel.beta == FlutterChannel.beta, isTrue);
        expect(FlutterChannel.beta != FlutterChannel.beta, isFalse);
        expect(FlutterChannel.beta < FlutterChannel.beta, isFalse);
        expect(FlutterChannel.beta <= FlutterChannel.beta, isTrue);
        expect(FlutterChannel.beta > FlutterChannel.beta, isFalse);
        expect(FlutterChannel.beta >= FlutterChannel.beta, isTrue);
        // - compare to stable:
        expect(FlutterChannel.beta == FlutterChannel.stable, isFalse);
        expect(FlutterChannel.beta != FlutterChannel.stable, isTrue);
        expect(FlutterChannel.beta < FlutterChannel.stable, isTrue);
        expect(FlutterChannel.beta <= FlutterChannel.stable, isTrue);
        expect(FlutterChannel.beta > FlutterChannel.stable, isFalse);
        expect(FlutterChannel.beta >= FlutterChannel.stable, isFalse);

        // FlutterChannel.stable comparison:
        // - compare to dev:
        expect(FlutterChannel.stable == FlutterChannel.dev, isFalse);
        expect(FlutterChannel.stable != FlutterChannel.dev, isTrue);
        expect(FlutterChannel.stable < FlutterChannel.dev, isFalse);
        expect(FlutterChannel.stable <= FlutterChannel.dev, isFalse);
        expect(FlutterChannel.stable > FlutterChannel.dev, isTrue);
        expect(FlutterChannel.stable >= FlutterChannel.dev, isTrue);
        // - compare to beta:
        expect(FlutterChannel.stable == FlutterChannel.beta, isFalse);
        expect(FlutterChannel.stable != FlutterChannel.beta, isTrue);
        expect(FlutterChannel.stable < FlutterChannel.beta, isFalse);
        expect(FlutterChannel.stable <= FlutterChannel.beta, isFalse);
        expect(FlutterChannel.stable > FlutterChannel.beta, isTrue);
        expect(FlutterChannel.stable >= FlutterChannel.beta, isTrue);
        // - compare to itself:
        expect(FlutterChannel.stable == FlutterChannel.stable, isTrue);
        expect(FlutterChannel.stable != FlutterChannel.stable, isFalse);
        expect(FlutterChannel.stable < FlutterChannel.stable, isFalse);
        expect(FlutterChannel.stable <= FlutterChannel.stable, isTrue);
        expect(FlutterChannel.stable > FlutterChannel.stable, isFalse);
        expect(FlutterChannel.stable >= FlutterChannel.stable, isTrue);
      });

      test('fromName factory', () {
        expect(FlutterChannel.fromName('dev'), FlutterChannel.dev);
        expect(FlutterChannel.fromName('beta'), FlutterChannel.beta);
        expect(FlutterChannel.fromName('stable'), FlutterChannel.stable);

        expect(FlutterChannel.fromName('DEV'), isNull);
        expect(FlutterChannel.fromName('unknown'), isNull);
        expect(FlutterChannel.fromName(''), isNull);
        expect(FlutterChannel.fromName(null), isNull);
      });
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
}
