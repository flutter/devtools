// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profiler.dart';
import 'package:devtools_app/src/screens/profiler/panes/controls/cpu_profiler_controls.dart';
import 'package:devtools_app/src/screens/profiler/profiler_status.dart';
import 'package:devtools_app/src/service/vm_flags.dart' as vm_flags;
import 'package:devtools_app/src/shared/file_import.dart';
import 'package:devtools_app/src/shared/ui/vm_flag_widgets.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/scenes/cpu_profiler/default.dart';
import '../test_infra/scenes/scene_test_extensions.dart';
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
      if (scene.fakeServiceConnection.serviceManager.connectedApp!
          .isFlutterNativeAppNow) {
        expect(find.text('Profile app start up'), findsOneWidget);
      }
      expect(find.byType(CpuSamplingRateDropdown), findsOneWidget);
      expect(find.byType(OpenSaveButtonGroup), findsOneWidget);
      expect(
        find.byType(ProfileRecordingInstructions),
        findsOneWidget,
      );
      expect(find.byType(RecordingStatus), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CpuProfiler), findsNothing);
      expect(find.byType(ModeDropdown), findsNothing);
    }

    Future<void> pumpProfilerScreen(WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpScene(scene);
        // Delay to ensure the memory profiler has collected data.
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ProfilerScreenBody), findsOneWidget);
      });
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
          scene.fakeServiceConnection.serviceManager.connectedApp!,
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
          find.byType(ProfileRecordingInstructions),
          findsNothing,
        );
        expect(find.byType(RecordingStatus), findsOneWidget);
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
        await tester.runAsync(() async {
          await scene.fakeServiceConnection.serviceManager.service!.setFlag(
            vm_flags.profiler,
            'false',
          );
        });
        await pumpProfilerScreen(tester);

        expect(find.byType(CpuProfilerDisabled), findsOneWidget);
        expect(
          find.byType(ProfileRecordingInstructions),
          findsNothing,
        );
        expect(find.byType(RecordButton), findsNothing);
        expect(find.byType(StopRecordingButton), findsNothing);
        expect(find.byType(ClearButton), findsNothing);
        expect(find.byType(CpuSamplingRateDropdown), findsNothing);
        expect(find.byType(OpenSaveButtonGroup), findsNothing);

        await tester.runAsync(() async {
          await tester.tap(find.text('Enable profiler'));
          // Delay to ensure the memory profiler has collected data.
          await tester.pump(const Duration(seconds: 1));
        });
        await tester.pumpAndSettle();
        verifyBaseState();
      },
    );
  });
}
