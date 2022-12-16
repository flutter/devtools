// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/performance/panes/flutter_frames/flutter_frames_chart.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/perfetto/_perfetto_web.dart';
import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_utils.dart';

const _testRequiresExperiments = true;

void main() {
  const skipTests = _testRequiresExperiments &&
      (bool.fromEnvironment('enable_experiments') == false);

  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  testWidgets(
    'Perfetto trace viewer',
    (tester) async {
      await pumpDevTools(tester);

      // TODO(kenz): we have to load offline data or the goldens will always be
      // slightly different.
      await connectToTestApp(tester, testApp);

      logStatus('load performance page and switch to Timeline Events tab');
      final performanceTab = find.descendant(
        of: find.byType(AppBar),
        matching: find.widgetWithText(Tab, ScreenMetaData.performance.title),
      );
      await tester.tap(performanceTab);
      await tester.pump(safePumpDuration);

      await tester.tap(find.widgetWithText(InkWell, 'Timeline Events'));
      await tester.pump(longPumpDuration);

      logStatus('verify HtmlElementView has loaded');
      expect(find.byType(Perfetto), findsOneWidget);
      expect(find.byType(HtmlElementView), findsOneWidget);

      await verifyScreenshot(binding, 'perfetto_initial_load');

      logStatus('select a Flutter Frame');
      await tester.tap(find.byType(FlutterFramesChartItem).last);
      await tester.pump(longPumpDuration);

      await verifyScreenshot(binding, 'perfetto_frame_selection');

      logStatus('switch to a different feature tab and back to Timeline Events');
      await tester.tap(find.widgetWithText(InkWell, 'Frame Analysis'));
      await tester.pump(longPumpDuration);

      await tester.tap(find.widgetWithText(InkWell, 'Timeline Events'));
      await tester.pump(longPumpDuration);

      await verifyScreenshot(binding, 'perfetto_frame_selection');
    },
    skip: skipTests,
  );
}
