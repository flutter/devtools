// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/common_widgets.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/profiler/profiler_screen_controller.dart';
import 'package:devtools_app/src/profiler/profiler_screen.dart';
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
  ProfilerScreen screen;
  FakeServiceManager fakeServiceManager;

  group('ProfilerScreen', () {
    setUp(() async {
      fakeServiceManager = FakeServiceManager();
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isDebugFlutterAppNow)
          .thenReturn(false);
      when(fakeServiceManager.connectedApp.isDartCliAppNow).thenReturn(true);
      when(fakeServiceManager.errorBadgeManager.errorCountNotifier(any))
          .thenReturn(ValueNotifier<int>(0));
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      screen = const ProfilerScreen();
    });

    void verifyBaseState(
      ProfilerScreenBody perfScreenBody,
      WidgetTester tester,
    ) {
      expect(find.byType(RecordButton), findsOneWidget);
      expect(find.byType(StopRecordingButton), findsOneWidget);
      expect(find.byType(ClearButton), findsOneWidget);
      expect(find.byType(ProfileGranularityDropdown), findsOneWidget);
      expect(
          find.byKey(ProfilerScreen.recordingInstructionsKey), findsOneWidget);
      expect(find.byKey(ProfilerScreen.recordingStatusKey), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CpuProfiler), findsNothing);
    }

    Future<void> pumpProfilerScreenBody(
      WidgetTester tester,
      ProfilerScreenBody body,
    ) async {
      await tester.pumpWidget(wrapWithControllers(
        body,
        profiler: ProfilerScreenController(),
      ));
    }

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.buildTab),
        profiler: ProfilerScreenController(),
      ));
      expect(find.text('CPU Profiler'), findsOneWidget);
    });

    const windowSize = Size(1000.0, 1000.0);

    testWidgetsWithWindowSize(
      'builds proper content for recording state',
      windowSize,
      (WidgetTester tester) async {
        const perfScreenBody = ProfilerScreenBody();
        await pumpProfilerScreenBody(tester, perfScreenBody);
        expect(find.byType(ProfilerScreenBody), findsOneWidget);
        verifyBaseState(perfScreenBody, tester);

        // Start recording.
        await tester.tap(find.byType(RecordButton));
        await tester.pump();
        expect(
            find.byKey(ProfilerScreen.recordingInstructionsKey), findsNothing);
        expect(find.byKey(ProfilerScreen.recordingStatusKey), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(CpuProfiler), findsNothing);

        // Stop recording.
        await tester.tap(find.byType(StopRecordingButton));
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(CpuProfiler), findsOneWidget);

        // Clear the profile.
        await tester.tap(find.byType(ClearButton));
        await tester.pump();
        verifyBaseState(perfScreenBody, tester);
      },
    );

    testWidgetsWithWindowSize('builds for disabled profiler', windowSize,
        (WidgetTester tester) async {
      await serviceManager.service.setFlag(vm_flags.profiler, 'false');
      const perfScreenBody = ProfilerScreenBody();
      await pumpProfilerScreenBody(tester, perfScreenBody);
      expect(find.byType(CpuProfilerDisabled), findsOneWidget);
      expect(
        find.byKey(ProfilerScreen.recordingInstructionsKey),
        findsNothing,
      );
      expect(find.byType(RecordButton), findsNothing);
      expect(find.byType(StopRecordingButton), findsNothing);
      expect(find.byType(ClearButton), findsNothing);
      expect(find.byType(ProfileGranularityDropdown), findsNothing);

      await tester.tap(find.text('Enable profiler'));
      await tester.pumpAndSettle();

      verifyBaseState(perfScreenBody, tester);
    });
  });
}
