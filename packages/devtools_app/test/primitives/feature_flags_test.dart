// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constants have expected values', () {
    expect(enableExperiments, false);
    expect(enableBeta, false);
    expect(isExternalBuild, true);
  });
}
