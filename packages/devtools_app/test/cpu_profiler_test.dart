// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/profiler/cpu_profile_bottom_up.dart';
import 'package:devtools_app/src/profiler/cpu_profile_call_tree.dart';
import 'package:devtools_app/src/profiler/cpu_profile_controller.dart';
import 'package:devtools_app/src/profiler/cpu_profile_flame_chart.dart';
import 'package:devtools_app/src/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/profiler/cpu_profile_transformer.dart';
import 'package:devtools_app/src/profiler/cpu_profiler.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_testing/support/cpu_profile_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

void main() {
  CpuProfiler cpuProfiler;
  CpuProfileData cpuProfileData;
  CpuProfilerController controller;
  FakeServiceManager fakeServiceManager;

  setUp(() async {
    final transformer = CpuProfileTransformer();
    controller = CpuProfilerController();
    cpuProfileData = CpuProfileData.parse(goldenCpuProfileDataJson);
    await transformer.processData(cpuProfileData);

    fakeServiceManager = FakeServiceManager();
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    when(fakeServiceManager.connectedApp.isDartCliAppNow).thenReturn(true);
  });

  group('Cpu Profiler', () {
    testWidgets('builds for null cpuProfileData', (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: null,
        controller: controller,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(CpuProfiler.emptyCpuProfile), findsNothing);
      expect(find.byKey(CpuProfiler.dataProcessingKey), findsOneWidget);
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.byType(CpuCallTreeTable), findsNothing);
      expect(find.byType(CpuBottomUpTable), findsNothing);
    });

    testWidgets('builds for empty cpuProfileData', (WidgetTester tester) async {
      cpuProfileData = CpuProfileData.parse(emptyCpuProfileDataJson);
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(CpuProfiler.emptyCpuProfile), findsOneWidget);
      expect(find.byKey(CpuProfiler.dataProcessingKey), findsNothing);
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.byType(CpuCallTreeTable), findsNothing);
      expect(find.byType(CpuBottomUpTable), findsNothing);
    });

    testWidgets('builds for valid cpuProfileData', (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(CpuProfiler.emptyCpuProfile), findsNothing);
      expect(find.byKey(CpuProfiler.dataProcessingKey), findsNothing);
      expect(find.byType(CpuProfileFlameChart), findsOneWidget);
    });

    testWidgetsWithWindowSize('switches tabs', const Size(1000, 1000),
        (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(CpuProfiler.emptyCpuProfile), findsNothing);
      expect(find.byKey(CpuProfiler.dataProcessingKey), findsNothing);
      expect(find.byType(CpuProfileFlameChart), findsOneWidget);
      expect(find.byType(CpuCallTreeTable), findsNothing);
      expect(find.byType(CpuBottomUpTable), findsNothing);
      expect(find.byKey(CpuProfiler.expandButtonKey), findsNothing);
      expect(find.byKey(CpuProfiler.collapseButtonKey), findsNothing);

      await tester.tap(find.text('Call Tree'));
      await tester.pumpAndSettle();
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.byType(CpuCallTreeTable), findsOneWidget);
      expect(find.byType(CpuBottomUpTable), findsNothing);
      expect(find.byKey(CpuProfiler.expandButtonKey), findsOneWidget);
      expect(find.byKey(CpuProfiler.collapseButtonKey), findsOneWidget);

      await tester.tap(find.text('Bottom Up'));
      await tester.pumpAndSettle();
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.byType(CpuCallTreeTable), findsNothing);
      expect(find.byType(CpuBottomUpTable), findsOneWidget);
      expect(find.byKey(CpuProfiler.expandButtonKey), findsOneWidget);
      expect(find.byKey(CpuProfiler.collapseButtonKey), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'can expand and collapse data', const Size(1000, 1000),
        (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      await tester.tap(find.text('Call Tree'));
      await tester.pumpAndSettle();

      expect(cpuProfileData.cpuProfileRoot.isExpanded, isFalse);
      await tester.tap(find.byKey(CpuProfiler.expandButtonKey));
      expect(cpuProfiler.callTreeRoots.first.isExpanded, isTrue);
      await tester.tap(find.byKey(CpuProfiler.collapseButtonKey));
      expect(cpuProfiler.callTreeRoots.first.isExpanded, isFalse);

      await tester.tap(find.text('Bottom Up'));
      await tester.pumpAndSettle();
      for (final root in cpuProfiler.bottomUpRoots) {
        expect(root.isExpanded, isFalse);
      }
      await tester.tap(find.byKey(CpuProfiler.expandButtonKey));
      for (final root in cpuProfiler.bottomUpRoots) {
        expect(root.isExpanded, isTrue);
      }
      await tester.tap(find.byKey(CpuProfiler.collapseButtonKey));
      for (final root in cpuProfiler.bottomUpRoots) {
        expect(root.isExpanded, isFalse);
      }
    });
  });
}
