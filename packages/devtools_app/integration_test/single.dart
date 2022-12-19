// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'test_infra/_run_test.dart';

// To run this test, run the following from `devtools_app/`:
// `dart run integration_test/single.dart --target=path/to/test.dart`
//
// Additional arguments that may be passed to this command:
// --test-app-uri=<some vm service uri> - this will connect DevTools to the app
//    you specify instead of spinning up a test app inside 
//    [runFlutterIntegrationTest].
// --enable-experiments - this will run the DevTools integration tests with
//    DevTools experiments enabled (see feature_flags.dart)
// --headless - this will run the integration test on the 'web-server' device
//    instead of the 'chrome' device, meaning you will not be able to see the
//    integration test run in Chrome when running locally.

Future<void> main(List<String> args) async {
  // The call to [runFlutterIntegrationTest] will fail if a test target has not
  // been provided (e.g. --target=path/to/test.dart).
  await runFlutterIntegrationTest(args);
}
