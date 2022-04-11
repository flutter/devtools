// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/primitives/url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('getSimplePackageUrl', () {
    expect(getSimplePackageUrl(''), equals(''));
    expect(getSimplePackageUrl(dartSdkUrl), equals('dart:async/zone.dart'));
    expect(
      getSimplePackageUrl(flutterUrl),
      equals('package:flutter/widgets/binding.dart'),
    );
    expect(
      getSimplePackageUrl(flutterUrlFromNonFlutterDir),
      equals('package:flutter/widgets/binding.dart'),
    );
    expect(
      getSimplePackageUrl('org-dartlang-sdk:///flutter/lib/ui/hooks.dart'),
      equals('dart:ui/hooks.dart'),
    );
  });
}

const dartSdkUrl =
    'org-dartlang-sdk:///third_party/dart/sdk/lib/async/zone.dart';
const flutterUrl =
    'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart';
const flutterUrlFromNonFlutterDir =
    'file:///path/to/non-flutter/packages/flutter/lib/src/widgets/binding.dart';
