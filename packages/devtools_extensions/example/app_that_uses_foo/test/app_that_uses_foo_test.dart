// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:app_that_uses_foo/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foo/foo.dart';

// This test can be run to verify that the `package:foo` DevTools extension
// loads properly when debugging a test target with DevTools.
//
// To test this, run the following command and copy the VM service URI to
// connect to DevTools:
//
// flutter test test/app_that_uses_foo_test.dart --start-paused

void main() {
  testWidgets('Builds $MyAppThatUsesFoo', (tester) async {
    await tester.pumpWidget(const MyAppThatUsesFoo());
    await tester.pumpAndSettle();

    expect(find.byType(MyAppThatUsesFoo), findsOneWidget);
    expect(find.byType(FooWidget), findsOneWidget);
  });
}
