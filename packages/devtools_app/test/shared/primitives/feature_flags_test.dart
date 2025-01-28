// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constants have expected values', () {
    expect(enableExperiments, false);
    expect(enableBeta, false);
    expect(isExternalBuild, true);
    expect(FeatureFlags.memorySaveLoad, false);
    expect(FeatureFlags.deepLinkIosCheck, true);
    expect(FeatureFlags.dapDebugging, false);
    expect(FeatureFlags.wasmOptInSetting, true);
    expect(FeatureFlags.inspectorV2, true);
    expect(FeatureFlags.propertyEditor, false);
  });
}
