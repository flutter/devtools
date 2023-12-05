// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/framework/connected/memory_tabs.dart';
import 'package:devtools_app/src/screens/memory/framework/memory_screen.dart';
import 'package:devtools_app/src/screens/memory/panes/profile/model.dart';
import 'package:devtools_app/src/screens/memory/panes/profile/profile_pane_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_service_private_extensions.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/primitives/utils.dart';
import 'package:devtools_app/src/shared/table/table.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/scenes/memory/default.dart';
import '../../test_infra/scenes/scene_test_extensions.dart';

void main() {
  late MemoryDefaultScene scene;

  setUp(() async {
    scene = MemoryDefaultScene();
    await scene.setUp();
  });

  Future<void> pumpMemoryScreen(WidgetTester tester) async {
    await tester.pumpScene(scene);
    // Delay to ensure the memory profiler has collected data.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(MemoryBody), findsOneWidget);
  }

  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1200.0);
  //setGlobal(NotificationService, NotificationService());

  group('Allocation Profile Table', () {
    // setUp(() async {
    //   setGlobal(OfflineModeController, OfflineModeController());
    //   setGlobal(IdeTheme, IdeTheme());
    //   setGlobal(PreferencesController, PreferencesController());
    //   _setUpServiceManagerForMemory();
    // });

    Future<void> navigateToAllocationProfile(
      WidgetTester tester,
      ProfilePaneController allocationProfileController,
    ) async {
      await tester.tap(find.byKey(MemoryScreenKeys.dartHeapTableProfileTab));
      await tester.pumpAndSettle();

      // We should have requested an allocation profile by navigating to the tab.
      expect(
        allocationProfileController.currentAllocationProfile.value,
        isNotNull,
      );
    }

    testWidgetsWithWindowSize(
      'respects VM Developer Mode setting',
      windowSize,
      (WidgetTester tester) async {
        await pumpMemoryScreen(tester);

        final allocationProfileController =
            scene.controller.controllers.profile;

        preferences.toggleVmDeveloperMode(false);
        await navigateToAllocationProfile(tester, allocationProfileController);

        // Only "total" statistics are shown when VM Developer Mode is disabled.
        expect(preferences.vmDeveloperModeEnabled.value, isFalse);
        expect(find.text('Class'), findsOneWidget);
        expect(find.text('Instances'), findsOneWidget);
        expect(find.text('Total Size'), findsOneWidget);
        expect(find.text('Dart Heap'), findsOneWidget);
        expect(find.text('External'), findsNothing);
        expect(find.text('Old Space'), findsNothing);
        expect(find.text('New Space'), findsNothing);
        expect(find.text('Usage'), findsNothing);
        expect(find.text('Capacity'), findsNothing);
        expect(find.text('Collections'), findsNothing);
        expect(find.text('Latency'), findsNothing);

        // Enable VM Developer Mode to display new/old space column groups as
        // well as GC statistics.
        preferences.toggleVmDeveloperMode(true);
        await tester.pumpAndSettle();

        expect(preferences.vmDeveloperModeEnabled.value, isTrue);
        expect(find.text('Class'), findsOneWidget);
        expect(find.text('Instances'), findsNWidgets(3));
        expect(find.text('Total Size'), findsNWidgets(3));
        expect(find.text('Dart Heap'), findsNWidgets(3));
        expect(find.text('External'), findsNWidgets(3));
        expect(find.text('Total'), findsOneWidget);
        expect(find.text('Old Space'), findsOneWidget);
        expect(find.text('New Space'), findsOneWidget);
        expect(find.text('Usage'), findsNWidgets(3));
        expect(find.text('Capacity'), findsNWidgets(3));
        expect(find.text('Collections'), findsNWidgets(3));
        expect(find.text('Latency'), findsNWidgets(3));
        final currentProfile =
            allocationProfileController.currentAllocationProfile.value!;

        void checkGCStats(GCStats stats) {
          // Usage
          expect(
            find.text(
              prettyPrintBytes(
                stats.usage,
                includeUnit: true,
              )!,
              findRichText: true,
            ),
            findsOneWidget,
          );

          // Capacity
          expect(
            find.text(
              prettyPrintBytes(
                stats.capacity,
                includeUnit: true,
              )!,
              findRichText: true,
            ),
            findsOneWidget,
          );

          // Average collection time
          expect(
            find.text(
              durationText(
                Duration(milliseconds: stats.averageCollectionTime.toInt()),
                fractionDigits: 2,
              ),
              findRichText: true,
            ),
            findsOneWidget,
          );

          // # of collections
          expect(
            find.text(
              stats.collections.toString(),
              findRichText: true,
            ),
            findsOneWidget,
          );
        }

        checkGCStats(currentProfile.newSpaceGCStats);
        checkGCStats(currentProfile.oldSpaceGCStats);
        checkGCStats(currentProfile.totalGCStats);
      },
    );

    testWidgetsWithWindowSize(
      'manually refreshes',
      windowSize,
      (WidgetTester tester) async {
        await pumpMemoryScreen(tester);

        final allocationProfileController =
            scene.controller.controllers.profile;
        await navigateToAllocationProfile(tester, allocationProfileController);

        // We'll clear it for now so we can tell when it's refreshed.
        allocationProfileController.clearCurrentProfile();
        await tester.pump();

        // Refresh the profile.
        await tester.tap(
          find.byIcon(Icons.refresh).first,
        );
        await tester.pumpAndSettle();

        // Ensure that we have populated the current allocation profile.
        expect(
          allocationProfileController.currentAllocationProfile.value,
          isNotNull,
        );

        expect(find.text('Class'), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'refreshes on GC',
      windowSize,
      (WidgetTester tester) async {
        await pumpMemoryScreen(tester);

        final allocationProfileController =
            scene.controller.controllers.profile;

        await navigateToAllocationProfile(tester, allocationProfileController);

        // We'll clear it for now so we can tell when it's refreshed.
        allocationProfileController.clearCurrentProfile();
        await tester.pump();

        // Emit a GC event and confirm we don't perform a refresh.
        final fakeService = scene.fakeServiceConnection.serviceManager.service
            as FakeVmServiceWrapper;
        fakeService.emitGCEvent();
        expect(
          allocationProfileController.currentAllocationProfile.value,
          isNull,
        );

        // Enable "Refresh on GC" functionality.
        await tester.tap(
          find.text('Refresh on GC').first,
        );
        await tester.pump();

        // Emit a GC event to trigger a refresh.
        fakeService.emitGCEvent();
        await tester.pumpAndSettle();

        // Ensure that we have populated the current allocation profile.
        expect(
          allocationProfileController.currentAllocationProfile.value,
          isNotNull,
        );
      },
    );

    // Regression test for https://github.com/flutter/devtools/issues/4484.
    testWidgetsWithWindowSize(
      'sorts correctly',
      windowSize,
      (WidgetTester tester) async {
        await pumpMemoryScreen(tester);

        final table = find.byType(FlatTable<ProfileRecord>);
        expect(table, findsOneWidget);

        final cls = find.text('Class');
        final instances = find.text('Instances');
        final size = find.text('Total Size');
        final dartHeap = find.text('Dart Heap');

        final columns = <Finder>[
          cls,
          instances,
          size,
          dartHeap,
        ];

        for (final columnFinder in columns) {
          expect(columnFinder, findsOneWidget);
        }

        final state = tester.state<FlatTableState<ProfileRecord>>(table.first);
        var data = state.tableController.tableData.value.data;

        // Initial state should be sorted by size, largest to smallest.
        int lastValue = data.first.totalDartHeapSize;
        for (final element in data) {
          expect(element.totalDartHeapSize <= lastValue, isTrue);
          lastValue = element.totalDartHeapSize;
        }

        // Sort by size, smallest to largest.
        await tester.tap(size);
        await tester.pumpAndSettle();

        data = state.tableController.tableData.value.data;

        lastValue = data.first.totalDartHeapSize;
        for (final element in data) {
          expect(element.totalDartHeapSize >= lastValue, isTrue);
          lastValue = element.totalDartHeapSize;
        }

        // Sort by class name, alphabetically
        await tester.tap(cls);
        await tester.pumpAndSettle();

        data = state.tableController.tableData.value.data;

        String lastClassName = data.first.heapClass.className;
        for (final element in data) {
          final name = element.heapClass.className;
          expect(name.compareTo(lastClassName) >= 0, isTrue);
          lastClassName = name;
        }

        // Sort by class name, reverse alphabetical order
        await tester.tap(cls);
        await tester.pumpAndSettle();

        data = state.tableController.tableData.value.data;

        lastClassName = data.first.heapClass.className;
        for (final element in data) {
          final name = element.heapClass.className;
          expect(name.compareTo(lastClassName) <= 0, isTrue);
          lastClassName = name;
        }

        // Sort by instance count, largest to smallest.
        await tester.tap(instances);
        await tester.pumpAndSettle();

        data = state.tableController.tableData.value.data;

        lastValue = data.first.totalInstances!;
        for (final element in data) {
          if (element.isTotal) continue;
          expect(element.totalInstances! <= lastValue, isTrue);
          lastValue = element.totalInstances!;
        }

        // Sort by instance count, smallest to largest.
        await tester.tap(instances);
        await tester.pumpAndSettle();

        data = state.tableController.tableData.value.data;

        lastValue = data.first.totalInstances!;
        for (final element in data) {
          expect(element.totalInstances! >= lastValue, isTrue);
          lastValue = element.totalInstances!;
        }

        // Sort by dart heap size, largest to smallest.
        await tester.tap(dartHeap);
        await tester.pumpAndSettle();

        data = state.tableController.tableData.value.data;

        lastValue = data.first.totalDartHeapSize;
        for (final element in data) {
          final internalSize = element.totalDartHeapSize;
          expect(internalSize <= lastValue, isTrue);
          lastValue = internalSize;
        }

        // Sort by dart heap size, smallest to largest.
        await tester.tap(dartHeap);
        await tester.pumpAndSettle();

        data = state.tableController.tableData.value.data;

        lastValue = data.first.totalDartHeapSize;
        for (final element in data) {
          final internalSize = element.totalDartHeapSize;
          expect(internalSize >= lastValue, isTrue);
          lastValue = internalSize;
        }
      },
    );
  });
}
