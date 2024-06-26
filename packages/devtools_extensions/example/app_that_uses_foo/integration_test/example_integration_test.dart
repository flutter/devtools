// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:app_that_uses_foo/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foo/foo.dart';

void main() {
  testWidgets('smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyAppThatUsesFoo());
    expect(find.byType(FooWidget), findsOneWidget);
  });
}
