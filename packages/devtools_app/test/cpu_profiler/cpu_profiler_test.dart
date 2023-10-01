// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/profiler/common.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_transformer.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profiler.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profiler_controller.dart';
import 'package:devtools_app/src/screens/profiler/panes/bottom_up.dart';
import 'package:devtools_app/src/screens/profiler/panes/call_tree.dart';
import 'package:devtools_app/src/screens/profiler/panes/controls/cpu_profiler_controls.dart';
import 'package:devtools_app/src/screens/profiler/panes/cpu_flame_chart.dart';
import 'package:devtools_app/src/screens/profiler/panes/method_table/method_table.dart';
import 'package:devtools_app/src/screens/profiler/panes/method_table/method_table_controller.dart';
import 'package:devtools_app/src/shared/charts/flame_chart.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/matchers/matchers.dart';
import '../test_infra/test_data/cpu_profiler/cpu_profile.dart';
import '../test_infra/utils/test_utils.dart';

void main() {
  late CpuProfiler cpuProfiler;
  late CpuProfileData cpuProfileData;
  late CpuProfilerController controller;

  final ServiceConnectionManager fakeServiceManager =
      FakeServiceConnectionManager();
  final app = fakeServiceManager.serviceManager.connectedApp!;
  when(app.isFlutterNativeAppNow).thenReturn(false);
  when(app.isFlutterAppNow).thenReturn(false);
  when(app.isDebugFlutterAppNow).thenReturn(false);

  setUp(() async {
    setCharacterWidthForTables();
    setGlobal(ServiceConnectionManager, fakeServiceManager);

    final transformer = CpuProfileTransformer();
    controller = CpuProfilerController();
    cpuProfileData = CpuProfileData.parse(goldenCpuProfileDataJson);
    await transformer.processData(
      cpuProfileData,
      processId: 'test',
    );

    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BannerMessagesController, BannerMessagesController());
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

    testWidgetsWithWindowSize(
      'builds for empty cpuProfileData',
      windowSize,
      (WidgetTester tester) async {
        cpuProfileData = CpuProfileData.parse(emptyCpuProfileDataJson);
        cpuProfiler = CpuProfiler(
          data: cpuProfileData,
          controller: controller,
        );
        await tester.pumpWidget(wrap(cpuProfiler));
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.byKey(CpuProfiler.dataProcessingKey), findsNothing);
        expect(find.byType(CpuBottomUpTable), findsOneWidget);
        expect(find.byType(CpuCallTreeTable), findsNothing);
        expect(find.byType(CpuMethodTable), findsNothing);
        expect(find.byType(CpuProfileFlameChart), findsNothing);
        expect(find.byType(CpuProfileStats), findsOneWidget);
        expect(find.byType(DisplayTreeGuidelinesToggle), findsOneWidget);
        expect(find.byType(UserTagDropdown), findsOneWidget);
        expect(find.byType(ExpandAllButton), findsOneWidget);
        expect(find.byType(CollapseAllButton), findsOneWidget);
        expect(find.byType(FlameChartHelpButton), findsNothing);
        expect(
          find.byType(SearchField<MethodTableController>),
          findsNothing,
        );
        expect(
          find.byType(SearchField<CpuProfilerController>),
          findsNothing,
        );
        expect(find.byKey(ProfilerTab.bottomUp.key), findsOneWidget);
        expect(find.byKey(ProfilerTab.callTree.key), findsOneWidget);
        expect(find.byKey(ProfilerTab.methodTable.key), findsOneWidget);
        expect(find.byKey(ProfilerTab.cpuFlameChart.key), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'builds for valid cpuProfileData',
      windowSize,
      (WidgetTester tester) async {
        cpuProfiler = CpuProfiler(
          data: cpuProfileData,
          controller: controller,
        );
        await tester.pumpWidget(wrap(cpuProfiler));
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.byKey(CpuProfiler.dataProcessingKey), findsNothing);
        expect(find.byType(CpuBottomUpTable), findsOneWidget);
        expect(find.byType(CpuProfileStats), findsOneWidget);
        expect(find.byType(DisplayTreeGuidelinesToggle), findsOneWidget);
        expect(find.byType(UserTagDropdown), findsOneWidget);
        expect(find.byType(ExpandAllButton), findsOneWidget);
        expect(find.byType(CollapseAllButton), findsOneWidget);
        expect(find.byType(FlameChartHelpButton), findsNothing);
        expect(
          find.byType(SearchField<MethodTableController>),
          findsNothing,
        );
        expect(
          find.byType(SearchField<CpuProfilerController>),
          findsNothing,
        );
        expect(find.byKey(ProfilerTab.bottomUp.key), findsOneWidget);
        expect(find.byKey(ProfilerTab.callTree.key), findsOneWidget);
        expect(find.byKey(ProfilerTab.methodTable.key), findsOneWidget);
        expect(find.byKey(ProfilerTab.cpuFlameChart.key), findsOneWidget);
      },
    );

    group('profile views', () {
      late ProfilerScreenController controller;

      Future<void> loadData() async {
        for (final filter in controller
            .cpuProfilerController.activeFilter.value.toggleFilters) {
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

        // Await a small delay to allow the ProfilerScreenController to complete
        // initialization.
        await Future.delayed(const Duration(seconds: 1));

        cpuProfileData = CpuProfileData.parse(cpuProfileDataWithUserTagsJson);
      });

      testWidgetsWithWindowSize(
        'shows function / code view selector when in VM developer mode',
        windowSize,
        (WidgetTester tester) async {
          await tester.runAsync(() async {
            // We need to pump the entire `ProfilerScreenBody` widget because the
            // CpuProfiler widget has `cpuProfileData` passed in from there, and
            // CpuProfiler needs to be rebuilt on data updates.
            await tester.pumpWidget(
              wrapWithControllers(
                const ProfilerScreenBody(),
                profiler: controller,
              ),
            );
            await tester.pump();

            // Verify the profile view dropdown is not visible.
            expect(find.byType(ModeDropdown), findsNothing);

            // Enabling VM developer mode will clear the current profile as it's
            // possible there's no code profile associated with it.
            preferences.toggleVmDeveloperMode(true);
            await tester.pumpAndSettle();
            expect(find.byType(CpuProfiler), findsNothing);

            // Verify the profile view dropdown appears when toggling VM developer
            // mode and data is present.
            await loadData();
            await tester.pumpAndSettle();
            expect(find.byType(ModeDropdown), findsOneWidget);

            // Verify the profile view dropdown is no longer visible.
            preferences.toggleVmDeveloperMode(false);
            await tester.pumpAndSettle();
            expect(find.byType(ModeDropdown), findsNothing);
          });
        },
      );

      testWidgetsWithWindowSize(
        'resets view to function when leaving VM developer mode',
        windowSize,
        (WidgetTester tester) async {
          await tester.runAsync(() async {
            // We need to pump the entire `ProfilerScreenBody` widget because the
            // CpuProfiler widget has `cpuProfileData` passed in from there, and
            // CpuProfiler needs to be rebuilt on data updates.
            await tester.pumpWidget(
              wrapWithControllers(
                const ProfilerScreenBody(),
                profiler: controller,
              ),
            );
            await tester.pump();

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
            await loadData();
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
          });
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
        );
        await tester.pumpWidget(wrap(cpuProfiler));
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.byKey(CpuProfiler.dataProcessingKey), findsNothing);
        expect(find.byType(CpuBottomUpTable), findsOneWidget);
        expect(find.byType(CpuCallTreeTable), findsNothing);
        expect(find.byType(CpuMethodTable), findsNothing);
        expect(find.byType(CpuProfileFlameChart), findsNothing);
        expect(find.byType(DevToolsFilterButton), findsOneWidget);
        expect(find.byType(DisplayTreeGuidelinesToggle), findsOneWidget);
        expect(find.byType(UserTagDropdown), findsOneWidget);
        expect(find.byType(ExpandAllButton), findsOneWidget);
        expect(find.byType(CollapseAllButton), findsOneWidget);
        expect(find.byType(FlameChartHelpButton), findsNothing);
        expect(find.byType(ModeDropdown), findsNothing);
        expect(
          find.byType(SearchField<MethodTableController>),
          findsNothing,
        );
        expect(
          find.byType(SearchField<CpuProfilerController>),
          findsNothing,
        );

        await tester.tap(find.text('Call Tree'));
        await tester.pumpAndSettle();
        expect(find.byType(CpuBottomUpTable), findsNothing);
        expect(find.byType(CpuCallTreeTable), findsOneWidget);
        expect(find.byType(CpuMethodTable), findsNothing);
        expect(find.byType(CpuProfileFlameChart), findsNothing);
        expect(find.byType(DevToolsFilterButton), findsOneWidget);
        expect(find.byType(DisplayTreeGuidelinesToggle), findsOneWidget);
        expect(find.byType(UserTagDropdown), findsOneWidget);
        expect(find.byType(ExpandAllButton), findsOneWidget);
        expect(find.byType(CollapseAllButton), findsOneWidget);
        expect(find.byType(FlameChartHelpButton), findsNothing);
        expect(find.byType(ModeDropdown), findsNothing);
        expect(
          find.byType(SearchField<MethodTableController>),
          findsNothing,
        );
        expect(
          find.byType(SearchField<CpuProfilerController>),
          findsNothing,
        );

        await tester.tap(find.text('Method Table'));
        await tester.pumpAndSettle();
        expect(find.byType(CpuBottomUpTable), findsNothing);
        expect(find.byType(CpuCallTreeTable), findsNothing);
        expect(find.byType(CpuMethodTable), findsOneWidget);
        expect(find.byType(CpuProfileFlameChart), findsNothing);
        expect(find.byType(DevToolsFilterButton), findsOneWidget);
        expect(find.byType(DisplayTreeGuidelinesToggle), findsNothing);
        expect(find.byType(UserTagDropdown), findsOneWidget);
        expect(find.byType(ExpandAllButton), findsNothing);
        expect(find.byType(CollapseAllButton), findsNothing);
        expect(find.byType(FlameChartHelpButton), findsNothing);
        expect(find.byType(ModeDropdown), findsNothing);
        expect(
          find.byType(SearchField<MethodTableController>),
          findsOneWidget,
        );
        expect(
          find.byType(SearchField<CpuProfilerController>),
          findsNothing,
        );

        await tester.tap(find.text('CPU Flame Chart'));
        await tester.pumpAndSettle();
        expect(find.byType(CpuBottomUpTable), findsNothing);
        expect(find.byType(CpuCallTreeTable), findsNothing);
        expect(find.byType(CpuMethodTable), findsNothing);
        expect(find.byType(CpuProfileFlameChart), findsOneWidget);
        expect(find.byType(DevToolsFilterButton), findsOneWidget);
        expect(find.byType(DisplayTreeGuidelinesToggle), findsNothing);
        expect(find.byType(UserTagDropdown), findsOneWidget);
        expect(find.byType(ExpandAllButton), findsNothing);
        expect(find.byType(CollapseAllButton), findsNothing);
        expect(find.byType(FlameChartHelpButton), findsOneWidget);
        expect(find.byType(ModeDropdown), findsNothing);
        expect(
          find.byType(SearchField<MethodTableController>),
          findsNothing,
        );
        expect(
          find.byType(SearchField<CpuProfilerController>),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'can expand and collapse data',
      windowSize,
      (WidgetTester tester) async {
        cpuProfiler = CpuProfiler(
          data: cpuProfileData,
          controller: controller,
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
            '../test_infra/goldens/cpu_profiler/call_tree_no_guidelines.png',
          ),
        );
        await tester.tap(find.byType(DisplayTreeGuidelinesToggle));
        await tester.pumpAndSettle();

        expect(preferences.cpuProfiler.displayTreeGuidelines.value, true);
        await expectLater(
          find.byType(CpuProfiler),
          matchesDevToolsGolden(
            '../test_infra/goldens/cpu_profiler/call_tree_guidelines.png',
          ),
        );
        await tester.tap(find.byType(DisplayTreeGuidelinesToggle));
        await tester.pumpAndSettle();

        expect(preferences.cpuProfiler.displayTreeGuidelines.value, false);
        await expectLater(
          find.byType(CpuProfiler),
          matchesDevToolsGolden(
            '../test_infra/goldens/cpu_profiler/call_tree_no_guidelines.png',
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
            '../test_infra/goldens/cpu_profiler/bottom_up_no_guidelines.png',
          ),
        );
        await tester.tap(find.byType(DisplayTreeGuidelinesToggle));
        await tester.pumpAndSettle();

        expect(preferences.cpuProfiler.displayTreeGuidelines.value, true);
        await expectLater(
          find.byType(CpuProfiler),
          matchesDevToolsGolden(
            '../test_infra/goldens/cpu_profiler/bottom_up_guidelines.png',
          ),
        );
        await tester.tap(find.byType(DisplayTreeGuidelinesToggle));
        await tester.pumpAndSettle();

        expect(preferences.cpuProfiler.displayTreeGuidelines.value, false);
        await expectLater(
          find.byType(CpuProfiler),
          matchesDevToolsGolden(
            '../test_infra/goldens/cpu_profiler/bottom_up_no_guidelines.png',
          ),
        );
      },
    );

    group('UserTag filters', () {
      late ProfilerScreenController controller;

      setUp(() async {
        controller = ProfilerScreenController();

        // Await a small delay to allow the ProfilerScreenController to complete
        // initialization.
        await Future.delayed(const Duration(seconds: 1));

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
          await tester.runAsync(() async {
            // We need to pump the entire `ProfilerScreenBody` widget because the
            // CpuProfiler widget has `cpuProfileData` passed in from there, and
            // CpuProfiler needs to be rebuilt on data updates.
            await tester.pumpWidget(
              wrapWithControllers(
                const ProfilerScreenBody(),
                profiler: controller,
              ),
            );
            await tester.pump();

            expect(controller.cpuProfilerController.userTags.length, equals(3));

            expect(find.byType(UserTagDropdown), findsOneWidget);
            // There is a Text widget and a RichText widget.
            expect(
              find.text('Filter by tag: userTagA', skipOffstage: false),
              findsWidgets,
            );
            expect(
              find.text('Filter by tag: userTagB', skipOffstage: false),
              findsWidgets,
            );
            expect(
              find.text('Filter by tag: userTagC', skipOffstage: false),
              findsWidgets,
            );
            expect(
              find.text('Group by: User Tag', skipOffstage: false),
              findsWidgets,
            );

            await tester.tap(find.text('Call Tree'));
            await tester.pumpAndSettle();
            expect(find.byType(CpuCallTreeTable), findsOneWidget);
            await tester.tap(find.text('Expand All'));
            await tester.pumpAndSettle();

            expect(
              controller.cpuProfileData!.profileMetaData.time!.duration
                  .inMicroseconds,
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

            // Await a small delay to allow the CpuProfilerController to finish
            // processing data for the new user tag.
            await Future.delayed(const Duration(seconds: 1));
            await tester.pumpAndSettle();

            await tester.tap(find.text('Expand All'));
            await tester.pumpAndSettle();
            expect(
              controller.cpuProfileData!.profileMetaData.time!.duration
                  .inMicroseconds,
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

            // Await a small delay to allow the CpuProfilerController to finish
            // processing data for the new user tag.
            await Future.delayed(const Duration(seconds: 1));
            await tester.pumpAndSettle();

            await tester.tap(find.text('Expand All'));
            await tester.pumpAndSettle();
            expect(
              controller.cpuProfileData!.profileMetaData.time!.duration
                  .inMicroseconds,
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

            // Await a small delay to allow the CpuProfilerController to finish
            // processing data for the new user tag.
            await Future.delayed(const Duration(seconds: 1));
            await tester.pumpAndSettle();

            await tester.tap(find.text('Expand All'));
            await tester.pumpAndSettle();
            expect(
              controller.cpuProfileData!.profileMetaData.time!.duration
                  .inMicroseconds,
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
          });
        },
      );
    });

    group('Group by ', () {
      late ProfilerScreenController controller;

      setUp(() async {
        controller = ProfilerScreenController();

        // Await a small delay to allow the ProfilerScreenController to complete
        // initialization.
        await Future.delayed(const Duration(seconds: 1));

        preferences.toggleVmDeveloperMode(true);
        cpuProfileData = CpuProfileData.parse(cpuProfileDataWithUserTagsJson);
        for (final filter in controller
            .cpuProfilerController.activeFilter.value.toggleFilters) {
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
        await tester.runAsync(() async {
          // We need to pump the entire `ProfilerScreenBody` widget because the
          // CpuProfiler widget has `cpuProfileData` passed in from there, and
          // CpuProfiler needs to be rebuilt on data updates.
          await tester.pumpWidget(
            wrapWithControllers(
              const ProfilerScreenBody(),
              profiler: controller,
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Call Tree'));
          await tester.pumpAndSettle();
          expect(find.byType(CpuCallTreeTable), findsOneWidget);
          await tester.tap(find.byType(UserTagDropdown));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Group by: User Tag').last);

          // Await a small delay to allow the CpuProfilerController to finish
          // processing data for the new user tag.
          await Future.delayed(const Duration(seconds: 1));
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
      });

      testWidgetsWithWindowSize('VM tags', windowSize, (tester) async {
        await tester.runAsync(() async {
          // We need to pump the entire `ProfilerScreenBody` widget because the
          // CpuProfiler widget has `cpuProfileData` passed in from there, and
          // CpuProfiler needs to be rebuilt on data updates.
          await tester.pumpWidget(
            wrapWithControllers(
              const ProfilerScreenBody(),
              profiler: controller,
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Call Tree'));
          await tester.pumpAndSettle();
          expect(find.byType(CpuCallTreeTable), findsOneWidget);
          await tester.tap(find.byType(UserTagDropdown));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Group by: VM Tag').last);

          // Await a small delay to allow the CpuProfilerController to finish
          // processing data for the new user tag.
          await Future.delayed(const Duration(seconds: 1));
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
  });

  group('$CpuProfileStats', () {
    testWidgets('displays correctly', (WidgetTester tester) async {
      final metadata = CpuProfileMetaData(
        sampleCount: 100,
        samplePeriod: 100,
        stackDepth: 128,
        time: TimeRange()
          ..start = const Duration()
          ..end = const Duration(microseconds: 10000),
      );
      await tester.pumpWidget(wrap(CpuProfileStats(metadata: metadata)));
      await tester.pumpAndSettle();

      expect(
        find.byTooltip('The duration of time spanned by the CPU samples'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('The number of samples included in the profile'),
        findsOneWidget,
      );
      expect(
        find.byTooltip(
          'The frequency at which samples are collected by the profiler'
          ' (once every 100 micros)',
        ),
        findsOneWidget,
      );
      expect(
        find.byTooltip('The maximum stack trace depth of a collected sample'),
        findsOneWidget,
      );
      expect(find.text('Duration: 10.0 ms'), findsOneWidget);
      expect(find.text('Sample count: 100'), findsOneWidget);
      expect(find.text('Sampling rate: 10000 Hz'), findsOneWidget);
      expect(find.text('Sampling depth: 128'), findsOneWidget);
    });

    testWidgets(
      'displays correctly for invalid data',
      (WidgetTester tester) async {
        final metadata = CpuProfileMetaData(
          sampleCount: 100,
          samplePeriod: 0,
          stackDepth: 128,
          time: TimeRange()
            ..start = const Duration()
            ..end = const Duration(microseconds: 10000),
        );
        await tester.pumpWidget(wrap(CpuProfileStats(metadata: metadata)));
        await tester.pumpAndSettle();

        expect(
          find.byTooltip('The duration of time spanned by the CPU samples'),
          findsOneWidget,
        );
        expect(
          find.byTooltip('The number of samples included in the profile'),
          findsOneWidget,
        );
        expect(
          find.byTooltip(
            'The frequency at which samples are collected by the profiler',
          ),
          findsOneWidget,
        );
        expect(
          find.byTooltip('The maximum stack trace depth of a collected sample'),
          findsOneWidget,
        );
        expect(find.text('Duration: 10.0 ms'), findsOneWidget);
        expect(find.text('Sample count: 100'), findsOneWidget);
        expect(find.text('Sampling rate: -- Hz'), findsOneWidget);
        expect(find.text('Sampling depth: 128'), findsOneWidget);
      },
    );
  });
}
