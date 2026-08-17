// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/service_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('ServiceExtensions', () {
    test('brightnessMode is properly configured', () {
      expect(
        brightnessMode.extension,
        equals('ext.flutter.brightnessOverride'),
      );
      expect(
        brightnessMode.values,
        equals(['system', 'Brightness.light', 'Brightness.dark']),
      );
      expect(
        serviceExtensionsAllowlist[brightnessMode.extension],
        equals(brightnessMode),
      );
    });

    test('brightnessMode is in unsafe before first frame set', () {
      expect(
        isUnsafeBeforeFirstFlutterFrame('ext.flutter.brightnessOverride'),
        isTrue,
      );
    });
  });
}
