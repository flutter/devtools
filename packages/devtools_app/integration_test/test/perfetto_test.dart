// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/performance/panes/flutter_frames/flutter_frames_chart.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/perfetto/_perfetto_web.dart';
import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_utils.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  testWidgets('Perfetto workflow', (tester) async {
    await pumpDevTools(tester);
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

    print('before take screenshot');
    await binding.takeScreenshot('perfetto_initial_load');
    print('after take screenshot');

    logStatus('select a Flutter Frame');
    await tester.tap(find.byType(FlutterFramesChartItem).last);
    await tester.pump(longPumpDuration);
    await tester.pumpAndSettle();

    // print('before take screenshot');
    // await binding.takeScreenshot('perfetto_frame_selection');
    // print('after take screenshot');
    // await expectLater(
    //   goldenBytes,
    //   matchesDevToolsGolden(
    //     '../test_infra/goldens/perfetto_frame_selection.png',
    //   ),
    // );

    logStatus('switch to a different feature tab and back to Timeline Events');
    await tester.tap(find.widgetWithText(InkWell, 'Frame Analysis'));
    await tester.pump(longPumpDuration);

    await tester.tap(find.widgetWithText(InkWell, 'Timeline Events'));
    await tester.pump(longPumpDuration);

    // print('before take screenshot');
    // await binding.takeScreenshot('perfetto_frame_selection');
    // print('after take screenshot');
    // await expectLater(
    //   goldenBytes,
    //   matchesDevToolsGolden(
    //     '../test_infra/goldens/perfetto_frame_selection.png',
    //   ),
    // );

    await tester.pump(longPumpDuration);
  });
}
