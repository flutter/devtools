// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'test_infra/_run_test.dart';

// To run this test:
// `dart run integration_test/e2e.dart` from `devtools_app/`

void main(List<String> args) async {
  const testTarget = 'integration_test/test/app_test.dart';
  await runTest([...args, '$testTargetArg$testTarget']);
}
