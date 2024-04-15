// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlutterVersion', () {
    test('infers semantic version', () {
      var flutterVersion =
          FlutterVersion.fromJson({'frameworkVersion': '1.10.7-pre.42'});
      expect(flutterVersion.major, equals(1));
      expect(flutterVersion.minor, equals(10));
      expect(flutterVersion.patch, equals(7));
      expect(flutterVersion.preReleaseMajor, equals(42));
      expect(flutterVersion.preReleaseMinor, equals(0));

      flutterVersion =
          FlutterVersion.fromJson({'frameworkVersion': '1.10.7-pre42'});
      expect(flutterVersion.major, equals(1));
      expect(flutterVersion.minor, equals(10));
      expect(flutterVersion.patch, equals(7));
      expect(flutterVersion.preReleaseMajor, equals(42));
      expect(flutterVersion.preReleaseMinor, equals(0));

      flutterVersion =
          FlutterVersion.fromJson({'frameworkVersion': '1.10.11-pre42'});
      expect(flutterVersion.major, equals(1));
      expect(flutterVersion.minor, equals(10));
      expect(flutterVersion.patch, equals(11));
      expect(flutterVersion.preReleaseMajor, equals(42));
      expect(flutterVersion.preReleaseMinor, equals(0));

      flutterVersion =
          FlutterVersion.fromJson({'frameworkVersion': '2.3.0-17.0.pre.355'});
      expect(flutterVersion.major, equals(2));
      expect(flutterVersion.minor, equals(3));
      expect(flutterVersion.patch, equals(0));
      expect(flutterVersion.preReleaseMajor, equals(17));
      expect(flutterVersion.preReleaseMinor, equals(0));

      flutterVersion =
          FlutterVersion.fromJson({'frameworkVersion': '2.3.0-17.0.pre'});
      expect(flutterVersion.major, equals(2));
      expect(flutterVersion.minor, equals(3));
      expect(flutterVersion.patch, equals(0));
      expect(flutterVersion.preReleaseMajor, equals(17));
      expect(flutterVersion.preReleaseMinor, equals(0));

      flutterVersion =
          FlutterVersion.fromJson({'frameworkVersion': '2.3.0-17'});
      expect(flutterVersion.major, equals(2));
      expect(flutterVersion.minor, equals(3));
      expect(flutterVersion.patch, equals(0));
      expect(flutterVersion.preReleaseMajor, equals(17));
      expect(flutterVersion.preReleaseMinor, equals(0));

      flutterVersion = FlutterVersion.fromJson({'frameworkVersion': '2.3.0'});
      expect(flutterVersion.major, equals(2));
      expect(flutterVersion.minor, equals(3));
      expect(flutterVersion.patch, equals(0));
      expect(flutterVersion.preReleaseMajor, isNull);
      expect(flutterVersion.preReleaseMinor, isNull);

      flutterVersion =
          FlutterVersion.fromJson({'frameworkVersion': 'bad-version'});
      expect(flutterVersion.major, equals(0));
      expect(flutterVersion.minor, equals(0));
      expect(flutterVersion.patch, equals(0));
    });

    test('parses dart version correctly', () {
      var flutterVersion = FlutterVersion.fromJson({
        'frameworkVersion': '2.8.0',
        'dartSdkVersion': '2.15.0',
      });
      expect(flutterVersion.dartSdkVersion.toString(), equals('2.15.0'));
      flutterVersion = FlutterVersion.fromJson({
        'frameworkVersion': '2.8.0',
        'dartSdkVersion': '2.15.0 (build 2.15.0-178.1.beta)',
      });
      expect(flutterVersion.dartSdkVersion.toString(), equals('2.15.0-178.1'));
    });
  });
}
