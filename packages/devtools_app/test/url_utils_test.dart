// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/url_utils.dart';
import 'package:test/test.dart';

void main() {
  group('url utils', () {
    test('getSimplePackageUrl', () {
      expect(getSimplePackageUrl(''), equals(''));
      expect(getSimplePackageUrl(dartSdkUrl), equals(dartSdkUrl));
      expect(
        getSimplePackageUrl(flutterUrl),
        equals('package:flutter/lib/src/widgets/binding.dart'),
      );
      expect(
        getSimplePackageUrl(flutterUrlFromNonFlutterDir),
        equals('package:flutter/lib/src/widgets/binding.dart'),
      );
      expect(
        getSimplePackageUrl(flutterWebUrl),
        equals('package:flutter_web/lib/src/widgets/binding.dart'),
      );
    });
  });
}

const dartSdkUrl =
    'org-dartlang-sdk:///third_party/dart/sdk/lib/async/zone.dart';
const flutterUrl =
    'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart';
const flutterUrlFromNonFlutterDir =
    'file:///path/to/non-flutter/packages/flutter/lib/src/widgets/binding.dart';
const flutterWebUrl =
    'file:///path/to/flutter/packages/flutter_web/lib/src/widgets/binding.dart';
