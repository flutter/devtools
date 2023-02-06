// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profiler.dart';
import 'package:devtools_app/src/service/vm_flags.dart' as vm_flags;
import 'package:devtools_app/src/shared/ui/vm_flag_widgets.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/scenes/cpu_profiler/default.dart';
import '../test_infra/utils/test_utils.dart';

void main() {
  late CpuProfilerDefaultScene scene;

  setUp(() async {
    setCharacterWidthForTables();
    scene = CpuProfilerDefaultScene();
    await scene.setUp();
  });

  const windowSize = Size(2000.0, 1000.0);

  group('ProfilerScreen', () {
    void verifyBaseState() {
      expect(find.byType(RecordButton), findsOneWidget);
      expect(find.byType(StopRecordingButton), findsOneWidget);
      expect(find.byType(ClearButton), findsOneWidget);
      expect(find.text('Load all CPU samples'), findsOneWidget);
      if (scene.fakeServiceManager.connectedApp!.isFlutterNativeAppNow) {
        expect(find.text('Profile app start up'), findsOneWidget);
      }
      expect(find.byType(CpuSamplingRateDropdown), findsOneWidget);
      expect(
        find.byKey(ProfilerScreen.recordingInstructionsKey),
        findsOneWidget,
      );
      expect(find.byKey(ProfilerScreen.recordingStatusKey), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CpuProfiler), findsNothing);
      expect(find.byType(ModeDropdown), findsNothing);
    }

    Future<void> pumpProfilerScreen(WidgetTester tester) async {
      await tester.pumpWidget(scene.build());
      // Delay to ensure the memory profiler has collected data.
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(ProfilerScreenBody), findsOneWidget);
    }

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: scene.screen.buildTab),
          profiler: ProfilerScreenController(),
        ),
      );
      expect(find.text('CPU Profiler'), findsOneWidget);
    });

    testWidgetsWithWindowSize(
      'builds base state for Dart CLI app',
      windowSize,
      (WidgetTester tester) async {
        await pumpProfilerScreen(tester);
        verifyBaseState();
      },
    );

    testWidgetsWithWindowSize(
      'builds base state for Flutter native app',
      windowSize,
      (WidgetTester tester) async {
        mockConnectedApp(
          scene.fakeServiceManager.connectedApp!,
          isFlutterApp: true,
          isProfileBuild: true,
          isWebApp: false,
        );
        await pumpProfilerScreen(tester);
        verifyBaseState();
      },
    );

    testWidgetsWithWindowSize(
      'builds proper content for recording state',
      windowSize,
      (WidgetTester tester) async {
        await pumpProfilerScreen(tester);
        verifyBaseState();

        // Start recording.
        await tester.tap(find.byType(RecordButton));
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.byKey(ProfilerScreen.recordingInstructionsKey),
          findsNothing,
        );
        expect(find.byKey(ProfilerScreen.recordingStatusKey), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(CpuProfiler), findsNothing);

        // Stop recording.
        await tester.tap(find.byType(StopRecordingButton));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(CpuProfiler), findsOneWidget);

        // Clear the profile.
        await tester.tap(find.byType(ClearButton));
        await tester.pump();
        verifyBaseState();
      },
    );

    testWidgetsWithWindowSize(
      'builds for disabled profiler',
      windowSize,
      (WidgetTester tester) async {
        await scene.fakeServiceManager.service!.setFlag(
          vm_flags.profiler,
          'false',
        );
        await pumpProfilerScreen(tester);

        expect(find.byType(CpuProfilerDisabled), findsOneWidget);
        expect(
          find.byKey(ProfilerScreen.recordingInstructionsKey),
          findsNothing,
        );
        expect(find.byType(RecordButton), findsNothing);
        expect(find.byType(StopRecordingButton), findsNothing);
        expect(find.byType(ClearButton), findsNothing);
        expect(find.byType(CpuSamplingRateDropdown), findsNothing);

        await tester.tap(find.text('Enable profiler'));
        await tester.pumpAndSettle();

        verifyBaseState();
      },
    );
  });
}
