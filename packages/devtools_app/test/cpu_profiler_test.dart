// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/charts/flame_chart.dart';
import 'package:devtools_app/src/common_widgets.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/profiler/cpu_profile_bottom_up.dart';
import 'package:devtools_app/src/profiler/cpu_profile_call_tree.dart';
import 'package:devtools_app/src/profiler/cpu_profile_controller.dart';
import 'package:devtools_app/src/profiler/cpu_profile_flame_chart.dart';
import 'package:devtools_app/src/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/profiler/cpu_profile_transformer.dart';
import 'package:devtools_app/src/profiler/cpu_profiler.dart';
import 'package:devtools_app/src/profiler/profiler_screen.dart';
import 'package:devtools_app/src/profiler/profiler_screen_controller.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_testing/support/cpu_profile_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

void main() {
  CpuProfiler cpuProfiler;
  CpuProfileData cpuProfileData;
  CpuProfilerController controller;

  setUp(() async {
    final transformer = CpuProfileTransformer();
    controller = CpuProfilerController();
    cpuProfileData = CpuProfileData.parse(goldenCpuProfileDataJson);
    await transformer.processData(cpuProfileData);

    setGlobal(ServiceConnectionManager, FakeServiceManager());
  });

  group('CpuProfiler', () {
    const windowSize = Size(2000.0, 1000.0);
    final searchFieldKey = GlobalKey(debugLabel: 'test search field key');

    testWidgetsWithWindowSize('builds for null cpuProfileData', windowSize,
        (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: null,
        controller: controller,
        searchFieldKey: searchFieldKey,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byKey(CpuProfiler.dataProcessingKey), findsOneWidget);
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.byType(CpuCallTreeTable), findsNothing);
      expect(find.byType(CpuBottomUpTable), findsNothing);
      expect(find.byType(UserTagDropdown), findsNothing);
      expect(find.byType(ExpandAllButton), findsNothing);
      expect(find.byType(CollapseAllButton), findsNothing);
      expect(find.byType(FlameChartHelpButton), findsNothing);
      expect(find.byKey(searchFieldKey), findsNothing);
      expect(find.byKey(CpuProfiler.flameChartTab), findsNothing);
      expect(find.byKey(CpuProfiler.callTreeTab), findsNothing);
      expect(find.byKey(CpuProfiler.bottomUpTab), findsNothing);
      expect(find.byKey(CpuProfiler.summaryTab), findsNothing);
    });

    testWidgetsWithWindowSize('builds for empty cpuProfileData', windowSize,
        (WidgetTester tester) async {
      cpuProfileData = CpuProfileData.parse(emptyCpuProfileDataJson);
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
        searchFieldKey: searchFieldKey,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byKey(CpuProfiler.dataProcessingKey), findsNothing);
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.byType(CpuCallTreeTable), findsNothing);
      expect(find.byType(CpuBottomUpTable), findsNothing);
      expect(find.byType(UserTagDropdown), findsNothing);
      expect(find.byType(ExpandAllButton), findsNothing);
      expect(find.byType(CollapseAllButton), findsNothing);
      expect(find.byType(FlameChartHelpButton), findsNothing);
      expect(find.byKey(searchFieldKey), findsNothing);
      expect(find.byKey(CpuProfiler.flameChartTab), findsNothing);
      expect(find.byKey(CpuProfiler.callTreeTab), findsNothing);
      expect(find.byKey(CpuProfiler.bottomUpTab), findsNothing);
      expect(find.byKey(CpuProfiler.summaryTab), findsNothing);
    });

    testWidgetsWithWindowSize(
        'builds for empty cpuProfileData with summary view', windowSize,
        (WidgetTester tester) async {
      cpuProfileData = CpuProfileData.parse(emptyCpuProfileDataJson);
      const summaryViewKey = Key('test summary view');
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
        searchFieldKey: searchFieldKey,
        summaryView: const SizedBox(key: summaryViewKey),
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byKey(CpuProfiler.dataProcessingKey), findsNothing);
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.byType(CpuCallTreeTable), findsNothing);
      expect(find.byType(CpuBottomUpTable), findsNothing);
      expect(find.byType(UserTagDropdown), findsNothing);
      expect(find.byType(ExpandAllButton), findsNothing);
      expect(find.byType(CollapseAllButton), findsNothing);
      expect(find.byType(FlameChartHelpButton), findsNothing);
      expect(find.byKey(searchFieldKey), findsNothing);
      expect(find.byKey(CpuProfiler.flameChartTab), findsNothing);
      expect(find.byKey(CpuProfiler.callTreeTab), findsNothing);
      expect(find.byKey(CpuProfiler.bottomUpTab), findsNothing);
      expect(find.byKey(CpuProfiler.summaryTab), findsOneWidget);
      expect(find.byKey(summaryViewKey), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds for valid cpuProfileData', windowSize,
        (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
        searchFieldKey: searchFieldKey,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byKey(CpuProfiler.dataProcessingKey), findsNothing);
      expect(find.byType(CpuBottomUpTable), findsOneWidget);
      expect(find.byType(UserTagDropdown), findsOneWidget);
      expect(find.byType(ExpandAllButton), findsOneWidget);
      expect(find.byType(CollapseAllButton), findsOneWidget);
      expect(find.byType(FlameChartHelpButton), findsNothing);
      expect(find.byKey(searchFieldKey), findsNothing);
      expect(find.byKey(CpuProfiler.flameChartTab), findsOneWidget);
      expect(find.byKey(CpuProfiler.callTreeTab), findsOneWidget);
      expect(find.byKey(CpuProfiler.bottomUpTab), findsOneWidget);
      expect(find.byKey(CpuProfiler.summaryTab), findsNothing);
    });

    testWidgetsWithWindowSize(
        'builds for valid cpuProfileData with summaryView', windowSize,
        (WidgetTester tester) async {
      const summaryViewKey = Key('test summary view');
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
        searchFieldKey: searchFieldKey,
        summaryView: const SizedBox(key: summaryViewKey),
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byKey(CpuProfiler.dataProcessingKey), findsNothing);
      expect(find.byKey(summaryViewKey), findsOneWidget);
      expect(find.byType(UserTagDropdown), findsNothing);
      expect(find.byType(ExpandAllButton), findsNothing);
      expect(find.byType(CollapseAllButton), findsNothing);
      expect(find.byType(FlameChartHelpButton), findsNothing);
      expect(find.byKey(searchFieldKey), findsNothing);
      expect(find.byKey(CpuProfiler.flameChartTab), findsOneWidget);
      expect(find.byKey(CpuProfiler.callTreeTab), findsOneWidget);
      expect(find.byKey(CpuProfiler.bottomUpTab), findsOneWidget);
      expect(find.byKey(CpuProfiler.summaryTab), findsOneWidget);
    });

    testWidgetsWithWindowSize('switches tabs', windowSize,
        (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
        searchFieldKey: searchFieldKey,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byKey(CpuProfiler.dataProcessingKey), findsNothing);
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.byType(CpuCallTreeTable), findsNothing);
      expect(find.byType(CpuBottomUpTable), findsOneWidget);
      expect(find.byType(ExpandAllButton), findsOneWidget);
      expect(find.byType(CollapseAllButton), findsOneWidget);
      expect(find.byType(FlameChartHelpButton), findsNothing);
      expect(find.byKey(searchFieldKey), findsNothing);

      await tester.tap(find.text('Call Tree'));
      await tester.pumpAndSettle();
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.byType(CpuCallTreeTable), findsOneWidget);
      expect(find.byType(CpuBottomUpTable), findsNothing);
      expect(find.byType(UserTagDropdown), findsOneWidget);
      expect(find.byType(ExpandAllButton), findsOneWidget);
      expect(find.byType(CollapseAllButton), findsOneWidget);
      expect(find.byType(FlameChartHelpButton), findsNothing);
      expect(find.byKey(searchFieldKey), findsNothing);

      await tester.tap(find.text('CPU Flame Chart'));
      await tester.pumpAndSettle();
      expect(find.byType(CpuProfileFlameChart), findsOneWidget);
      expect(find.byType(CpuCallTreeTable), findsNothing);
      expect(find.byType(CpuBottomUpTable), findsNothing);
      expect(find.byType(UserTagDropdown), findsOneWidget);
      expect(find.byType(ExpandAllButton), findsNothing);
      expect(find.byType(CollapseAllButton), findsNothing);
      expect(find.byType(FlameChartHelpButton), findsOneWidget);
      expect(find.byKey(searchFieldKey), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'does not include search field without search field key', windowSize,
        (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
        // No search field key.
        // searchFieldKey: searchFieldKey,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CPU Flame Chart'));
      await tester.pumpAndSettle();
      expect(find.byType(CpuProfileFlameChart), findsOneWidget);
      expect(find.byType(CpuCallTreeTable), findsNothing);
      expect(find.byType(CpuBottomUpTable), findsNothing);
      expect(find.byType(UserTagDropdown), findsOneWidget);
      expect(find.byType(ExpandAllButton), findsNothing);
      expect(find.byType(CollapseAllButton), findsNothing);
      expect(find.byType(FlameChartHelpButton), findsOneWidget);
      expect(find.byKey(searchFieldKey), findsNothing);
    });

    testWidgetsWithWindowSize('can expand and collapse data', windowSize,
        (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
        searchFieldKey: searchFieldKey,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      await tester.tap(find.text('Call Tree'));
      await tester.pumpAndSettle();

      expect(cpuProfileData.cpuProfileRoot.isExpanded, isFalse);
      await tester.tap(find.byType(ExpandAllButton));
      expect(cpuProfiler.callTreeRoots.first.isExpanded, isTrue);
      await tester.tap(find.byType(CollapseAllButton));
      expect(cpuProfiler.callTreeRoots.first.isExpanded, isFalse);

      await tester.tap(find.text('Bottom Up'));
      await tester.pumpAndSettle();
      for (final root in cpuProfiler.bottomUpRoots) {
        expect(root.isExpanded, isFalse);
      }
      await tester.tap(find.byType(ExpandAllButton));
      for (final root in cpuProfiler.bottomUpRoots) {
        expect(root.isExpanded, isTrue);
      }
      await tester.tap(find.byType(CollapseAllButton));
      for (final root in cpuProfiler.bottomUpRoots) {
        expect(root.isExpanded, isFalse);
      }
    });

    group('UserTag filters', () {
      ProfilerScreenController controller;

      setUp(() async {
        controller = ProfilerScreenController();
        cpuProfileData = CpuProfileData.parse(cpuProfileDataWithUserTagsJson);
        await controller.cpuProfilerController.transformer
            .processData(cpuProfileData);
        // Call this to force the value of `_dataByTag[userTagNone]` to be set.
        controller.cpuProfilerController.loadProcessedData(cpuProfileData);
      });

      testWidgetsWithWindowSize('can filter data by user tag', windowSize,
          (WidgetTester tester) async {
        // We need to pump the entire `ProfilerScreenBody` widget because the
        // CpuProfiler widget has `cpuProfileData` passed in from there, and
        // CpuProfiler needs to be rebuilt on data updates.
        await tester.pumpWidget(wrapWithControllers(
          const ProfilerScreenBody(),
          profiler: controller,
        ));
        expect(controller.cpuProfilerController.userTags.length, equals(3));

        expect(find.byType(UserTagDropdown), findsOneWidget);
        // There is a Text widget and a RichText widget.
        expect(find.text('Filter by tag: userTagA'), findsWidgets);
        expect(find.text('Filter by tag: userTagB'), findsWidgets);
        expect(find.text('Filter by tag: userTagC'), findsWidgets);

        await tester.tap(find.text('CPU Flame Chart'));
        await tester.pumpAndSettle();
        expect(find.byType(CpuProfileFlameChart), findsOneWidget);

        expect(
          controller
              .cpuProfileData.profileMetaData.time.duration.inMicroseconds,
          equals(250),
        );
        expect(find.text('Frame1'), findsOneWidget);
        expect(find.text('Frame2'), findsOneWidget);
        expect(find.text('Frame3'), findsOneWidget);
        expect(find.text('Frame4'), findsOneWidget);
        expect(find.text('Frame5'), findsOneWidget);
        expect(find.text('Frame6'), findsOneWidget);

        await tester.tap(find.byType(UserTagDropdown));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Filter by tag: userTagA').last);
        await tester.pumpAndSettle();
        expect(
          controller
              .cpuProfileData.profileMetaData.time.duration.inMicroseconds,
          equals(100),
        );
        expect(find.text('Frame1'), findsOneWidget);
        expect(find.text('Frame2'), findsOneWidget);
        expect(find.text('Frame3'), findsOneWidget);
        expect(find.text('Frame4'), findsNothing);
        expect(find.text('Frame5'), findsOneWidget);
        expect(find.text('Frame6'), findsNothing);

        await tester.tap(find.byType(UserTagDropdown));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Filter by tag: userTagB').last);
        await tester.pumpAndSettle();
        expect(
          controller
              .cpuProfileData.profileMetaData.time.duration.inMicroseconds,
          equals(50),
        );
        expect(find.text('Frame1'), findsOneWidget);
        expect(find.text('Frame2'), findsOneWidget);
        expect(find.text('Frame3'), findsNothing);
        expect(find.text('Frame4'), findsOneWidget);
        expect(find.text('Frame5'), findsNothing);
        expect(find.text('Frame6'), findsNothing);

        await tester.tap(find.byType(UserTagDropdown));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Filter by tag: userTagC').last);
        await tester.pumpAndSettle();
        expect(
          controller
              .cpuProfileData.profileMetaData.time.duration.inMicroseconds,
          equals(100),
        );
        expect(find.text('Frame1'), findsOneWidget);
        expect(find.text('Frame2'), findsNothing);
        expect(find.text('Frame3'), findsNothing);
        expect(find.text('Frame4'), findsNothing);
        expect(find.text('Frame5'), findsOneWidget);
        expect(find.text('Frame6'), findsOneWidget);
      });
    });
  });
}
