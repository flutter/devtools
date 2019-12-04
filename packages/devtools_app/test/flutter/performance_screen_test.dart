// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/performance/flutter/performance_screen.dart';
import 'package:devtools_app/src/profiler/flutter/cpu_profiler.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:devtools_app/src/ui/flutter/vm_flag_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  PerformanceScreen screen;
  FakeServiceManager fakeServiceManager;

  group('TimelineScreen', () {
    setUp(() async {
      fakeServiceManager = FakeServiceManager(useFakeService: true);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      screen = const PerformanceScreen();
    });

    void verifyBaseState(
      PerformanceScreenBody perfScreenBody,
      WidgetTester tester,
    ) {
      expect(find.byKey(PerformanceScreen.recordButtonKey), findsOneWidget);
      expect(
          find.byKey(PerformanceScreen.stopRecordingButtonKey), findsOneWidget);
      expect(find.byKey(PerformanceScreen.clearButtonKey), findsOneWidget);
      expect(find.byType(ProfileGranularityDropdown), findsOneWidget);
      expect(find.byKey(PerformanceScreen.recordingInstructionsKey),
          findsOneWidget);
      expect(find.byKey(PerformanceScreen.recordingStatusKey), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CpuProfiler), findsNothing);
    }

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Performance'), findsOneWidget);
    });

    const windowSize = Size(1000.0, 1000.0);

    testWidgetsWithWindowSize(
      'builds proper content for recording state',
      windowSize,
      (WidgetTester tester) async {
        final perfScreenBody = PerformanceScreenBody();
        await tester.pumpWidget(wrap(perfScreenBody));
        expect(find.byType(PerformanceScreenBody), findsOneWidget);
        verifyBaseState(perfScreenBody, tester);

        // Start recording.
        await tester.tap(find.byKey(PerformanceScreen.recordButtonKey));
        await tester.pump();
        expect(find.byKey(PerformanceScreen.recordingInstructionsKey),
            findsNothing);
        expect(
            find.byKey(PerformanceScreen.recordingStatusKey), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(CpuProfiler), findsNothing);

        // Stop recording.
        await tester.tap(find.byKey(PerformanceScreen.stopRecordingButtonKey));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(CpuProfiler), findsOneWidget);

        // Clear the profile.
        await tester.tap(find.byKey(PerformanceScreen.clearButtonKey));
        await tester.pump();
        verifyBaseState(perfScreenBody, tester);
      },
    );
  });
}
