// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_bottom_up.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_call_tree.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_controller.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_flame_chart.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_transformer.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profiler.dart';
import 'package:devtools_app/src/shared/charts/flame_chart.dart';
import 'package:devtools_app/src/shared/config_specific/import_export/import_export.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/matchers/matchers.dart';
import '../test_infra/test_data/cpu_profile.dart';
import '../test_infra/utils/test_utils.dart';

void main() {
  late CpuProfiler cpuProfiler;
  late CpuProfileData cpuProfileData;
  late CpuProfilerController controller;

  final ServiceConnectionManager fakeServiceManager = FakeServiceManager();
  final app = fakeServiceManager.connectedApp!;
  when(app.isFlutterNativeAppNow).thenReturn(false);
  when(app.isFlutterAppNow).thenReturn(false);
  when(app.isDebugFlutterAppNow).thenReturn(false);

  setUp(() async {
    setCharacterWidthForTables();

    final transformer = CpuProfileTransformer();
    controller = CpuProfilerController();
    cpuProfileData = CpuProfileData.parse(goldenCpuProfileDataJson);
    await transformer.processData(
      cpuProfileData,
      processId: 'test',
    );

    setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(NotificationService, NotificationService());
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(IdeTheme, IdeTheme());
    final mockScriptManager = MockScriptManager();
    when(mockScriptManager.sortedScripts).thenReturn(
      ValueNotifier<List<ScriptRef>>([]),
    );
    when(mockScriptManager.scriptRefForUri(any)).thenReturn(
      ScriptRef(
        uri: 'package:test/script.dart',
        id: 'script.dart',
      ),
    );
    setGlobal(ScriptManager, mockScriptManager);
  });

  group('CpuProfiler', () {
    const windowSize = Size(2000.0, 1000.0);
    final searchFieldKey = GlobalKey(debugLabel: 'test search field key');

    testWidgetsWithWindowSize(
      'builds for empty cpuProfileData',
      windowSize,
      (WidgetTester tester) async {
        cpuProfileData = CpuProfileData.parse(emptyCpuProfileDataJson);
        cpuProfiler = CpuProfiler(
          data: cpuProfileData,
          controller: controller,
          searchFieldKey: searchFieldKey,
        );
        await tester.pumpWidget(wrap(cpuProfiler));
        expect(find.byType(TabBar), findsNothing);
        expect(find.byKey(CpuProfiler.dataProcessingKey), findsNothing);
        expect(find.byType(CpuProfileFlameChart), findsNothing);
        expect(find.byType(CpuCallTreeTable), findsNothing);
        expect(find.byType(CpuBottomUpTable), findsNothing);
        expect(find.byType(DisplayTreeGuidelinesToggle), findsNothing);
        expect(find.byType(UserTagDropdown), findsNothing);
        expect(find.byType(ExpandAllButton), findsNothing);
        expect(find.byType(CollapseAllButton), findsNothing);
        expect(find.byType(FlameChartHelpButton), findsNothing);
        expect(find.byKey(searchFieldKey), findsNothing);
        expect(find.byKey(CpuProfiler.flameChartTab), findsNothing);
        expect(find.byKey(CpuProfiler.callTreeTab), findsNothing);
        expect(find.byKey(CpuProfiler.bottomUpTab), findsNothing);
        expect(find.byKey(CpuProfiler.summaryTab), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'builds for empty cpuProfileData with summary view',
      windowSize,
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
        expect(find.byType(DisplayTreeGuidelinesToggle), findsNothing);
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
      },
    );

    testWidgetsWithWindowSize(
      'builds for valid cpuProfileData',
      windowSize,
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
        expect(find.byType(DisplayTreeGuidelinesToggle), findsOneWidget);
        expect(find.byType(UserTagDropdown), findsOneWidget);
        expect(find.byType(ExpandAllButton), findsOneWidget);
        expect(find.byType(CollapseAllButton), findsOneWidget);
        expect(find.byType(FlameChartHelpButton), findsNothing);
        expect(find.byKey(searchFieldKey), findsNothing);
        expect(find.byKey(CpuProfiler.flameChartTab), findsOneWidget);
        expect(find.byKey(CpuProfiler.callTreeTab), findsOneWidget);
        expect(find.byKey(CpuProfiler.bottomUpTab), findsOneWidget);
        expect(find.byKey(CpuProfiler.summaryTab), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'builds for valid cpuProfileData with summaryView',
      windowSize,
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
        expect(find.byType(DisplayTreeGuidelinesToggle), findsNothing);
        expect(find.byType(ExpandAllButton), findsNothing);
        expect(find.byType(CollapseAllButton), findsNothing);
        expect(find.byType(FlameChartHelpButton), findsNothing);
        expect(find.byKey(searchFieldKey), findsNothing);
        expect(find.byKey(CpuProfiler.flameChartTab), findsOneWidget);
        expect(find.byKey(CpuProfiler.callTreeTab), findsOneWidget);
        expect(find.byKey(CpuProfiler.bottomUpTab), findsOneWidget);
        expect(find.byKey(CpuProfiler.summaryTab), findsOneWidget);
      },
    );

    group('profile views', () {
      late ProfilerScreenController controller;

      Future<void> loadData() async {
        for (final filter in controller.cpuProfilerController.toggleFilters) {
          filter.enabled.value = false;
        }
        final data = CpuProfilePair(
          functionProfile: cpuProfileData,
          // Function and code profiles have the same structure, so just use
          // the function profile in place of a dedicated code profile for
          // testing since we don't care about the contents as much as we
          // care about testing the ability to switch between function and
          // code profile views.
          codeProfile: cpuProfileData,
        );
        await data.process(
          transformer: controller.cpuProfilerController.transformer,
          processId: 'test',
        );
        // Call this to force the value of `_dataByTag[userTagNone]` to be set.
        controller.cpuProfilerController.loadProcessedData(
          data,
          storeAsUserTagNone: true,
        );
      }

      setUp(() async {
        controller = ProfilerScreenController();
        cpuProfileData = CpuProfileData.parse(cpuProfileDataWithUserTagsJson);
      });

      testWidgetsWithWindowSize(
        'shows function / code view selector when in VM developer mode',
        windowSize,
        (WidgetTester tester) async {
          // We need to pump the entire `ProfilerScreenBody` widget because the
          // CpuProfiler widget has `cpuProfileData` passed in from there, and
          // CpuProfiler needs to be rebuilt on data updates.
          await tester.pumpWidget(
            wrapWithControllers(
              const ProfilerScreenBody(),
              profiler: controller,
            ),
          );
          // Verify the profile view dropdown is not visible.
          expect(find.byType(ModeDropdown), findsNothing);

          // Enabling VM developer mode will clear the current profile as it's
          // possible there's no code profile associated with it.
          preferences.toggleVmDeveloperMode(true);
          await tester.pumpAndSettle();
          expect(find.byType(CpuProfiler), findsNothing);

          // Verify the profile view dropdown appears when toggling VM developer
          // mode and data is present.
          await tester.runAsync(() async => await loadData());
          await tester.pumpAndSettle();
          expect(find.byType(ModeDropdown), findsOneWidget);

          // Verify the profile view dropdown is no longer visible.
          preferences.toggleVmDeveloperMode(false);
          await tester.pumpAndSettle();
          expect(find.byType(ModeDropdown), findsNothing);
        },
      );

      testWidgetsWithWindowSize(
        'resets view to function when leaving VM developer mode',
        windowSize,
        (WidgetTester tester) async {
          // We need to pump the entire `ProfilerScreenBody` widget because the
          // CpuProfiler widget has `cpuProfileData` passed in from there, and
          // CpuProfiler needs to be rebuilt on data updates.
          await tester.pumpWidget(
            wrapWithControllers(
              const ProfilerScreenBody(),
              profiler: controller,
            ),
          );

          // Verify the profile view dropdown is not visible.
          expect(find.byType(ModeDropdown), findsNothing);

          // The default view is the function profile, even when the profile view
          // selector isn't visible.
          expect(
            controller.cpuProfilerController.viewType.value,
            CpuProfilerViewType.function,
          );

          // Enable VM developer mode and reset the profile data.
          preferences.toggleVmDeveloperMode(true);
          await tester.pumpAndSettle();
          expect(find.byType(CpuProfiler), findsNothing);
          await tester.runAsync(() async => await loadData());
          await tester.pumpAndSettle();

          // Verify the function profile view is still selected.
          expect(
            controller.cpuProfilerController.viewType.value,
            CpuProfilerViewType.function,
          );
          expect(find.text('View: Function'), findsOneWidget);

          // Switch to the code profile view.
          await tester.tap(find.byType(ModeDropdown));
          await tester.pumpAndSettle();
          expect(find.text('View: Function'), findsWidgets);
          expect(find.text('View: Code'), findsWidgets);
          await tester.tap(find.text('View: Code').last);
          await tester.pumpAndSettle();
          expect(
            controller.cpuProfilerController.viewType.value,
            CpuProfilerViewType.code,
          );
          expect(find.byType(ModeDropdown), findsOneWidget);
          expect(find.text('View: Code'), findsOneWidget);

          // Disabling VM developer mode will reset the view to the function
          // profile as the dropdown will no longer be visible.
          preferences.toggleVmDeveloperMode(false);
          await tester.pumpAndSettle();
          expect(
            controller.cpuProfilerController.viewType.value,
            CpuProfilerViewType.function,
          );
        },
      );
    });

    testWidgetsWithWindowSize(
      'switches tabs',
      windowSize,
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
        expect(find.byType(FilterButton), findsOneWidget);
        expect(find.byType(DisplayTreeGuidelinesToggle), findsOneWidget);
        expect(find.byType(UserTagDropdown), findsOneWidget);
        expect(find.byType(ExpandAllButton), findsOneWidget);
        expect(find.byType(CollapseAllButton), findsOneWidget);
        expect(find.byType(FlameChartHelpButton), findsNothing);
        expect(find.byType(ModeDropdown), findsNothing);
        expect(find.byKey(searchFieldKey), findsNothing);

        await tester.tap(find.text('Call Tree'));
        await tester.pumpAndSettle();
        expect(find.byType(CpuProfileFlameChart), findsNothing);
        expect(find.byType(CpuCallTreeTable), findsOneWidget);
        expect(find.byType(CpuBottomUpTable), findsNothing);
        expect(find.byType(FilterButton), findsOneWidget);
        expect(find.byType(DisplayTreeGuidelinesToggle), findsOneWidget);
        expect(find.byType(UserTagDropdown), findsOneWidget);
        expect(find.byType(ExpandAllButton), findsOneWidget);
        expect(find.byType(CollapseAllButton), findsOneWidget);
        expect(find.byType(FlameChartHelpButton), findsNothing);
        expect(find.byType(ModeDropdown), findsNothing);
        expect(find.byKey(searchFieldKey), findsNothing);

        await tester.tap(find.text('CPU Flame Chart'));
        await tester.pumpAndSettle();
        expect(find.byType(CpuProfileFlameChart), findsOneWidget);
        expect(find.byType(CpuCallTreeTable), findsNothing);
        expect(find.byType(CpuBottomUpTable), findsNothing);
        expect(find.byType(FilterButton), findsOneWidget);
        expect(find.byType(DisplayTreeGuidelinesToggle), findsNothing);
        expect(find.byType(UserTagDropdown), findsOneWidget);
        expect(find.byType(ExpandAllButton), findsNothing);
        expect(find.byType(CollapseAllButton), findsNothing);
        expect(find.byType(FlameChartHelpButton), findsOneWidget);
        expect(find.byType(ModeDropdown), findsNothing);
        expect(find.byKey(searchFieldKey), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'does not include search field without search field key',
      windowSize,
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
      },
    );

    testWidgetsWithWindowSize(
      'can expand and collapse data',
      windowSize,
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
      },
    );

    testWidgetsWithWindowSize(
      'can enable and disable guidelines',
      windowSize,
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
        await tester.pumpAndSettle();

        expect(cpuProfiler.callTreeRoots.first.isExpanded, isTrue);
        expect(preferences.cpuProfiler.displayTreeGuidelines.value, false);
        await expectLater(
          find.byType(CpuProfiler),
          matchesDevToolsGolden(
            '../test_infra/goldens/cpu_profiler_call_tree_no_guidelines.png',
          ),
        );
        await tester.tap(find.byType(DisplayTreeGuidelinesToggle));
        await tester.pumpAndSettle();

        expect(preferences.cpuProfiler.displayTreeGuidelines.value, true);
        await expectLater(
          find.byType(CpuProfiler),
          matchesDevToolsGolden(
            '../test_infra/goldens/cpu_profiler_call_tree_guidelines.png',
          ),
        );
        await tester.tap(find.byType(DisplayTreeGuidelinesToggle));
        await tester.pumpAndSettle();

        expect(preferences.cpuProfiler.displayTreeGuidelines.value, false);
        await expectLater(
          find.byType(CpuProfiler),
          matchesDevToolsGolden(
            '../test_infra/goldens/cpu_profiler_call_tree_no_guidelines.png',
          ),
        );

        await tester.tap(find.text('Bottom Up'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ExpandAllButton));
        for (final root in cpuProfiler.bottomUpRoots) {
          expect(root.isExpanded, isTrue);
        }
        await tester.pumpAndSettle();

        expect(preferences.cpuProfiler.displayTreeGuidelines.value, false);
        await expectLater(
          find.byType(CpuProfiler),
          matchesDevToolsGolden(
            '../test_infra/goldens/cpu_profiler_bottom_up_no_guidelines.png',
          ),
        );
        await tester.tap(find.byType(DisplayTreeGuidelinesToggle));
        await tester.pumpAndSettle();

        expect(preferences.cpuProfiler.displayTreeGuidelines.value, true);
        await expectLater(
          find.byType(CpuProfiler),
          matchesDevToolsGolden(
            '../test_infra/goldens/cpu_profiler_bottom_up_guidelines.png',
          ),
        );
        await tester.tap(find.byType(DisplayTreeGuidelinesToggle));
        await tester.pumpAndSettle();

        expect(preferences.cpuProfiler.displayTreeGuidelines.value, false);
        await expectLater(
          find.byType(CpuProfiler),
          matchesDevToolsGolden(
            '../test_infra/goldens/cpu_profiler_bottom_up_no_guidelines.png',
          ),
        );
      },
    );

    group('UserTag filters', () {
      late ProfilerScreenController controller;

      setUp(() async {
        controller = ProfilerScreenController();
        cpuProfileData = CpuProfileData.parse(cpuProfileDataWithUserTagsJson);
        await controller.cpuProfilerController.transformer.processData(
          cpuProfileData,
          processId: 'test',
        );
        // Call this to force the value of `_dataByTag[userTagNone]` to be set.
        controller.cpuProfilerController.loadProcessedData(
          CpuProfilePair(
            functionProfile: cpuProfileData,
            // Function and code profiles have the same structure, so just use
            // the function profile in place of a dedicated code profile for
            // testing since we don't care about the contents as much as we
            // care about testing the ability to switch between function and
            // code profile views.
            codeProfile: cpuProfileData,
          ),
          storeAsUserTagNone: true,
        );
      });

      testWidgetsWithWindowSize(
        'can filter data by user tag',
        windowSize,
        (WidgetTester tester) async {
          // We need to pump the entire `ProfilerScreenBody` widget because the
          // CpuProfiler widget has `cpuProfileData` passed in from there, and
          // CpuProfiler needs to be rebuilt on data updates.
          await tester.pumpWidget(
            wrapWithControllers(
              const ProfilerScreenBody(),
              profiler: controller,
            ),
          );
          expect(controller.cpuProfilerController.userTags.length, equals(3));

          expect(find.byType(UserTagDropdown), findsOneWidget);
          // There is a Text widget and a RichText widget.
          expect(find.text('Filter by tag: userTagA'), findsWidgets);
          expect(find.text('Filter by tag: userTagB'), findsWidgets);
          expect(find.text('Filter by tag: userTagC'), findsWidgets);
          expect(find.text('Group by: User Tag'), findsWidgets);

          await tester.tap(find.text('Call Tree'));
          await tester.pumpAndSettle();
          expect(find.byType(CpuCallTreeTable), findsOneWidget);
          await tester.tap(find.text('Expand All'));
          await tester.pumpAndSettle();

          expect(
            controller
                .cpuProfileData!.profileMetaData.time!.duration.inMicroseconds,
            equals(250),
          );

          expect(find.richTextContaining('Frame1'), findsOneWidget);
          expect(find.richTextContaining('Frame2'), findsOneWidget);
          expect(find.richTextContaining('Frame3'), findsOneWidget);
          expect(find.richTextContaining('Frame4'), findsOneWidget);
          expect(find.richTextContaining('Frame5'), findsOneWidget);
          expect(find.richTextContaining('Frame6'), findsOneWidget);
          expect(find.text('userTagA'), findsNothing);
          expect(find.text('userTagB'), findsNothing);
          expect(find.text('userTagC'), findsNothing);

          await tester.tap(find.byType(UserTagDropdown));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Filter by tag: userTagA').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Expand All'));
          await tester.pumpAndSettle();
          expect(
            controller
                .cpuProfileData!.profileMetaData.time!.duration.inMicroseconds,
            equals(100),
          );
          expect(find.richTextContaining('Frame1'), findsNothing);
          expect(find.richTextContaining('Frame2'), findsOneWidget);
          expect(find.richTextContaining('Frame3'), findsNothing);
          expect(find.richTextContaining('Frame4'), findsNothing);
          expect(find.richTextContaining('Frame5'), findsOneWidget);
          expect(find.richTextContaining('Frame6'), findsNothing);
          expect(find.text('userTagA'), findsNothing);
          expect(find.text('userTagB'), findsNothing);
          expect(find.text('userTagC'), findsNothing);

          await tester.tap(find.byType(UserTagDropdown));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Filter by tag: userTagB').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Expand All'));
          await tester.pumpAndSettle();
          expect(
            controller
                .cpuProfileData!.profileMetaData.time!.duration.inMicroseconds,
            equals(50),
          );
          expect(find.richTextContaining('Frame1'), findsNothing);
          expect(find.richTextContaining('Frame2'), findsOneWidget);
          expect(find.richTextContaining('Frame3'), findsNothing);
          expect(find.richTextContaining('Frame4'), findsNothing);
          expect(find.richTextContaining('Frame5'), findsNothing);
          expect(find.richTextContaining('Frame6'), findsNothing);
          expect(find.text('userTagA'), findsNothing);
          expect(find.text('userTagB'), findsNothing);
          expect(find.text('userTagC'), findsNothing);

          await tester.tap(find.byType(UserTagDropdown));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Filter by tag: userTagC').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Expand All'));
          await tester.pumpAndSettle();
          expect(
            controller
                .cpuProfileData!.profileMetaData.time!.duration.inMicroseconds,
            equals(100),
          );
          expect(find.richTextContaining('Frame1'), findsNothing);
          expect(find.richTextContaining('Frame2'), findsNothing);
          expect(find.richTextContaining('Frame3'), findsNothing);
          expect(find.richTextContaining('Frame4'), findsNothing);
          expect(find.richTextContaining('Frame5'), findsOneWidget);
          expect(find.richTextContaining('Frame6'), findsOneWidget);
          expect(find.text('userTagA'), findsNothing);
          expect(find.text('userTagB'), findsNothing);
          expect(find.text('userTagC'), findsNothing);
        },
      );
    });

    group('Group by ', () {
      late ProfilerScreenController controller;

      setUp(() async {
        controller = ProfilerScreenController();
        preferences.toggleVmDeveloperMode(true);
        cpuProfileData = CpuProfileData.parse(cpuProfileDataWithUserTagsJson);
        for (final filter in controller.cpuProfilerController.toggleFilters) {
          filter.enabled.value = false;
        }
        final data = CpuProfilePair(
          functionProfile: cpuProfileData,
          // Function and code profiles have the same structure, so just use
          // the function profile in place of a dedicated code profile for
          // testing since we don't care about the contents as much as we
          // care about testing the ability to switch between function and
          // code profile views.
          codeProfile: cpuProfileData,
        );
        await data.process(
          transformer: controller.cpuProfilerController.transformer,
          processId: 'test',
        );
        // Call this to force the value of `_dataByTag[userTagNone]` to be set.
        controller.cpuProfilerController.loadProcessedData(
          data,
          storeAsUserTagNone: true,
        );
      });

      testWidgetsWithWindowSize('user tags', windowSize, (tester) async {
        // We need to pump the entire `ProfilerScreenBody` widget because the
        // CpuProfiler widget has `cpuProfileData` passed in from there, and
        // CpuProfiler needs to be rebuilt on data updates.
        await tester.pumpWidget(
          wrapWithControllers(
            const ProfilerScreenBody(),
            profiler: controller,
          ),
        );

        await tester.tap(find.text('Call Tree'));
        await tester.pumpAndSettle();
        expect(find.byType(CpuCallTreeTable), findsOneWidget);
        await tester.tap(find.byType(UserTagDropdown));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Group by: User Tag').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Expand All'));
        await tester.pumpAndSettle();

        expect(find.richTextContaining('Frame1'), findsNWidgets(3));
        expect(find.richTextContaining('Frame2'), findsNWidgets(2));
        expect(find.richTextContaining('Frame3'), findsNWidgets(1));
        expect(find.richTextContaining('Frame4'), findsNWidgets(1));
        expect(find.richTextContaining('Frame5'), findsNWidgets(2));
        expect(find.richTextContaining('Frame6'), findsNWidgets(1));
        expect(find.richText('userTagA'), findsOneWidget);
        expect(find.richText('userTagB'), findsOneWidget);
        expect(find.richText('userTagC'), findsOneWidget);
      });

      testWidgetsWithWindowSize('VM tags', windowSize, (tester) async {
        // We need to pump the entire `ProfilerScreenBody` widget because the
        // CpuProfiler widget has `cpuProfileData` passed in from there, and
        // CpuProfiler needs to be rebuilt on data updates.
        await tester.pumpWidget(
          wrapWithControllers(
            const ProfilerScreenBody(),
            profiler: controller,
          ),
        );

        await tester.tap(find.text('Call Tree'));
        await tester.pumpAndSettle();
        expect(find.byType(CpuCallTreeTable), findsOneWidget);
        await tester.tap(find.byType(UserTagDropdown));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Group by: VM Tag').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Expand All'));
        await tester.pumpAndSettle();

        expect(find.richTextContaining('Frame1'), findsNWidgets(3));
        expect(find.richTextContaining('Frame2'), findsNWidgets(2));
        expect(find.richTextContaining('Frame3'), findsNWidgets(1));
        expect(find.richTextContaining('Frame4'), findsNWidgets(1));
        expect(find.richTextContaining('Frame5'), findsNWidgets(2));
        expect(find.richTextContaining('Frame6'), findsNWidgets(1));
        expect(find.richText('vmTagA'), findsOneWidget);
        expect(find.richText('vmTagB'), findsOneWidget);
        expect(find.richText('vmTagC'), findsOneWidget);

        // Check that disabling VM developer mode when grouping by VM tag
        // automatically resets the view to 'Filter by tag: none'.
        preferences.toggleVmDeveloperMode(false);
        await tester.pumpAndSettle();
        expect(find.byType(CpuCallTreeTable), findsOneWidget);
        expect(find.text('Filter by tag: none'), findsOneWidget);
        await tester.tap(find.byType(UserTagDropdown));
        await tester.pumpAndSettle();
        expect(find.text('Group by: VM Tag'), findsNothing);
      });
    });
  });
}
