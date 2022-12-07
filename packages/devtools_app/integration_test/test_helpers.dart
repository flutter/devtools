// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/main.dart' as app;
import 'package:devtools_app/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpDevTools(WidgetTester tester) async {
  app.main();
  // Await a delay to ensure the widget tree has loaded. It is important to use
  // `pump` instead of `pumpAndSettle` here.
  await tester.pump(const Duration(seconds: 2));
  expect(find.byType(DevToolsApp), findsOneWidget);
}
