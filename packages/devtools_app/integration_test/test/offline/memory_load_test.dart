// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/performance/panes/flutter_frames/flutter_frames_chart.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/perfetto/_perfetto_web.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_test/helpers.dart';
import 'package:devtools_test/integration_test.dart';
import 'package:devtools_test/test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// To run:
// dart run integration_test/run_tests.dart --target=integration_test/test/offline/memory_load_test.dart

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  FeatureFlags.memoryOfflineRuntime = true;

  testWidgets(
    'Perfetto trace viewer loads data and scrolls for Flutter frames',
    (tester) async {
      await pumpDevTools(tester);
      await loadSampleData(tester, performanceFileName);

      await tester.tap(find.widgetWithText(InkWell, 'Timeline Events'));
      await tester.pumpAndSettle(longPumpDuration);

      logStatus('verify HtmlElementView has loaded');
      expect(find.byType(Perfetto), findsOneWidget);
      expect(find.byType(HtmlElementView), findsOneWidget);

      await verifyScreenshot(binding, 'perfetto_initial_load');

      logStatus('select a different Flutter Frame');
      await tester.tap(find.byType(FlutterFramesChartItem).last);
      await tester.pumpAndSettle(safePumpDuration);

      await verifyScreenshot(binding, 'perfetto_frame_selection');

      logStatus(
        'switch to a different feature tab and back to Timeline Events',
      );
      await tester.tap(find.widgetWithText(InkWell, 'Frame Analysis'));
      await tester.pump(safePumpDuration);

      await tester.tap(find.widgetWithText(InkWell, 'Timeline Events'));
      await tester.pump(safePumpDuration);

      await verifyScreenshot(
        binding,
        'perfetto_frame_selection_2',
        lastScreenshot: true,
      );
    },
  );
}
