// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceManager());
    setGlobal(IdeTheme, IdeTheme());
  });

  testWidgetsWithWindowSize(
      'Landing screen displays without error', const Size(2000.0, 2000.0),
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(wrap(const LandingScreenBody()));
    expect(find.byType(ConnectDialog), findsOneWidget);
    expect(find.byType(ImportFileInstructions), findsOneWidget);
    expect(find.byType(SampleDataDropDownButton), findsNothing);
    expect(find.byType(AppSizeToolingInstructions), findsOneWidget);
  });

  testWidgetsWithWindowSize(
      'Landing screen displays sample data picker', const Size(2000.0, 2000.0),
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      wrap(
        LandingScreenBody(
          sampleData: [
            DevToolsJsonFile(
              name: 'test-data',
              lastModifiedTime: DateTime.now(),
              data: <String, Object?>{},
            ),
          ],
        ),
      ),
    );
    expect(find.byType(ConnectDialog), findsOneWidget);
    expect(find.byType(ImportFileInstructions), findsOneWidget);
    expect(find.byType(SampleDataDropDownButton), findsOneWidget);
    expect(find.byType(AppSizeToolingInstructions), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<DevToolsJsonFile>));
    await tester.pumpAndSettle();

    expect(find.text('test-data'), findsNWidgets(2));
  });
}
