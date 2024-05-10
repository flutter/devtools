// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:app_that_uses_foo/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foo/foo.dart';

// This test can be run to verify that the DevTools extensions available for
// package:app_that_uses_foo load properly when debugging a Flutter test target
// with DevTools.
//
// To test this, run the following command and copy the VM service URI to
// connect to DevTools:
//
// flutter test test/flutter_test_2.dart --start-paused
//
// To test this test as part of a suite, use this command instead:
//
// flutter test test/ --start-paused

void main() {
  testWidgets('Builds $MyAppThatUsesFoo', (tester) async {
    await tester.pumpWidget(const MyAppThatUsesFoo());
    await tester.pumpAndSettle();

    expect(find.byType(MyAppThatUsesFoo), findsOneWidget);
    expect(find.byType(FooWidget), findsOneWidget);
  });
}
