// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:devtools_app/src/performance/performance_screen.dart';
import 'package:devtools_app/src/profiler/cpu_profiler.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/vm_flag_widgets.dart';
import 'package:devtools_app/src/vm_flags.dart' as vm_flags;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

void main() {
  PerformanceScreen screen;
  FakeServiceManager fakeServiceManager;

  group('PerformanceScreen', () {
    setUp(() async {
      fakeServiceManager = FakeServiceManager(useFakeService: true);
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isDebugFlutterAppNow)
          .thenReturn(false);
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

    Future<void> pumpPerformanceBody(
      WidgetTester tester,
      PerformanceScreenBody body,
    ) async {
      await tester.pumpWidget(wrapWithControllers(
        body,
        performance: PerformanceController(),
      ));
    }

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.buildTab),
        performance: PerformanceController(),
      ));
      expect(find.text('Performance'), findsOneWidget);
    });

    const windowSize = Size(1000.0, 1000.0);

    testWidgetsWithWindowSize(
      'builds proper content for recording state',
      windowSize,
      (WidgetTester tester) async {
        const perfScreenBody = PerformanceScreenBody();
        await pumpPerformanceBody(tester, perfScreenBody);
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
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(CpuProfiler), findsOneWidget);

        // Clear the profile.
        await tester.tap(find.byKey(PerformanceScreen.clearButtonKey));
        await tester.pump();
        verifyBaseState(perfScreenBody, tester);
      },
    );

    testWidgetsWithWindowSize('builds for disabled profiler', windowSize,
        (WidgetTester tester) async {
      await serviceManager.service.setFlag(vm_flags.profiler, 'false');
      const perfScreenBody = PerformanceScreenBody();
      await pumpPerformanceBody(tester, perfScreenBody);
      expect(find.byType(CpuProfilerDisabled), findsOneWidget);
      expect(
        find.byKey(PerformanceScreen.recordingInstructionsKey),
        findsNothing,
      );
      expect(find.byKey(PerformanceScreen.recordButtonKey), findsNothing);
      expect(
          find.byKey(PerformanceScreen.stopRecordingButtonKey), findsNothing);
      expect(find.byKey(PerformanceScreen.clearButtonKey), findsNothing);
      expect(find.byType(ProfileGranularityDropdown), findsNothing);

      await tester.tap(find.text('Enable profiler'));
      await tester.pumpAndSettle();

      verifyBaseState(perfScreenBody, tester);
    });
  });
}
