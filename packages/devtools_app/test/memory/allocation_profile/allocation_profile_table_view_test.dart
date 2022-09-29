// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/memory/memory_controller.dart';
import 'package:devtools_app/src/screens/memory/memory_heap_tree_view.dart';
import 'package:devtools_app/src/screens/memory/memory_screen.dart';
import 'package:devtools_app/src/screens/memory/panes/allocation_profile/allocation_profile_table_view_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_service_private_extensions.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_app/src/shared/table.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_data/memory_allocation.dart';

void main() {
  late MemoryController controller;
  late FakeServiceManager fakeServiceManager;

  void _setUpServiceManagerForMemory() {
    // Load canned data testHeapSampleData.
    final allocationJson =
        AllocationMemoryJson.decode(argJsonString: testAllocationData);

    fakeServiceManager = FakeServiceManager(
      service: FakeServiceManager.createFakeService(
        allocationData: allocationJson,
      ),
    );
    mockConnectedApp(
      fakeServiceManager.connectedApp!,
      isFlutterApp: true,
      isProfileBuild: false,
      isWebApp: false,
    );
    setGlobal(ServiceConnectionManager, fakeServiceManager);
  }

  Future<void> pumpMemoryScreen(
    WidgetTester tester, {
    MemoryController? memoryController,
  }) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const MemoryBody(),
        memory: controller = memoryController ?? MemoryController(),
      ),
    );

    // Delay to ensure the memory profiler has collected data.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(MemoryBody), findsOneWidget);
  }

  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);
  setGlobal(NotificationService, NotificationService());

  group('Allocation Profile Table', () {
    setUp(() async {
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(PreferencesController, PreferencesController());
      _setUpServiceManagerForMemory();
    });

    Future<void> navigateToAllocationProfile(
      WidgetTester tester,
      AllocationProfileTableViewController allocationProfileController,
    ) async {
      await tester.tap(find.byKey(MemoryScreenKeys.dartHeapTableProfileTab));
      await tester.pumpAndSettle();

      // We should have requested an allocation profile by navigating to the tab.
      expect(
        allocationProfileController.currentAllocationProfile.value,
        isNotNull,
      );
    }

    testWidgetsWithWindowSize('respects VM Developer Mode setting', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      final allocationProfileController =
          controller.allocationProfileController;

      preferences.toggleVmDeveloperMode(false);
      await navigateToAllocationProfile(tester, allocationProfileController);

      // Only "total" statistics are shown when VM Developer Mode is disabled.
      expect(preferences.vmDeveloperModeEnabled.value, isFalse);
      expect(find.text('Class'), findsOneWidget);
      expect(find.text('Instances'), findsOneWidget);
      expect(find.text('Total Size'), findsOneWidget);
      expect(find.text('Dart Heap'), findsOneWidget);
      expect(find.text('External'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Old Space'), findsNothing);
      expect(find.text('New Space'), findsNothing);

      // Enable VM Developer Mode to display new/old space column groups.
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
    });

    testWidgetsWithWindowSize('manually refreshes', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      final allocationProfileController =
          controller.allocationProfileController;
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
    });

    testWidgetsWithWindowSize('refreshes on GC', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      final allocationProfileController =
          controller.allocationProfileController;

      await navigateToAllocationProfile(tester, allocationProfileController);

      // We'll clear it for now so we can tell when it's refreshed.
      allocationProfileController.clearCurrentProfile();
      await tester.pump();

      // Emit a GC event and confirm we don't perform a refresh.
      final fakeService = fakeServiceManager.service as FakeVmServiceWrapper;
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
    });

    // Regression test for https://github.com/flutter/devtools/issues/4484.
    testWidgetsWithWindowSize('sorts correctly', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      final table = find.byType(FlatTable<ClassHeapStats?>);
      expect(table, findsOneWidget);

      final cls = find.text('Class');
      final instances = find.text('Instances');
      final size = find.text('Total Size');
      final internal = find.text('Dart Heap');
      final external = find.text('External');

      final columns = <Finder>[
        cls,
        instances,
        size,
        internal,
        external,
      ];

      for (final columnFinder in columns) {
        expect(columnFinder, findsOneWidget);
      }

      final state = tester.state<FlatTableState<ClassHeapStats?>>(table.first);

      // Initial state should be sorted by size, largest to smallest.
      int lastValue = state.data.first!.bytesCurrent!;
      for (final element in state.data) {
        expect(element!.bytesCurrent! <= lastValue, isTrue);
        lastValue = element.bytesCurrent!;
      }

      // Sort by size, smallest to largest.
      await tester.tap(size);
      await tester.pumpAndSettle();

      lastValue = state.data.first!.bytesCurrent!;
      for (final element in state.data) {
        expect(element!.bytesCurrent! >= lastValue, isTrue);
        lastValue = element.bytesCurrent!;
      }

      // Sort by class name, alphabetically
      await tester.tap(cls);
      await tester.pumpAndSettle();

      String lastClassName = state.data.first!.classRef!.name!;
      for (final element in state.data) {
        final name = element!.classRef!.name!;
        expect(name.compareTo(lastClassName) >= 0, isTrue);
        lastClassName = name;
      }

      // Sort by class name, reverse alphabetical order
      await tester.tap(cls);
      await tester.pumpAndSettle();

      lastClassName = state.data.first!.classRef!.name!;
      for (final element in state.data) {
        final name = element!.classRef!.name!;
        expect(name.compareTo(lastClassName) <= 0, isTrue);
        lastClassName = name;
      }

      // Sort by instance count, largest to smallest.
      await tester.tap(instances);
      await tester.pumpAndSettle();

      lastValue = state.data.first!.instancesCurrent!;
      for (final element in state.data) {
        expect(element!.instancesCurrent! <= lastValue, isTrue);
        lastValue = element.instancesCurrent!;
      }

      // Sort by instance count, smallest to largest.
      await tester.tap(instances);
      await tester.pumpAndSettle();

      lastValue = state.data.first!.instancesCurrent!;
      for (final element in state.data) {
        expect(element!.instancesCurrent! >= lastValue, isTrue);
        lastValue = element.instancesCurrent!;
      }

      // Sort by internal size, largest to smallest.
      await tester.tap(internal);
      await tester.pumpAndSettle();

      lastValue =
          state.data.first!.newSpace.size + state.data.first!.oldSpace.size;
      for (final element in state.data) {
        final internalSize = element!.newSpace.size + element.oldSpace.size;
        expect(internalSize <= lastValue, isTrue);
        lastValue = internalSize;
      }

      // Sort by internal size, smallest to largest.
      await tester.tap(instances);
      await tester.pumpAndSettle();

      lastValue =
          state.data.first!.newSpace.size + state.data.first!.oldSpace.size;
      for (final element in state.data) {
        final internalSize = element!.newSpace.size + element.oldSpace.size;
        expect(internalSize >= lastValue, isTrue);
        lastValue = internalSize;
      }

      // Sort by external size, largest to smallest.
      await tester.tap(internal);
      await tester.pumpAndSettle();

      lastValue = state.data.first!.newSpace.externalSize +
          state.data.first!.oldSpace.externalSize;
      for (final element in state.data) {
        final externalSize =
            element!.newSpace.externalSize + element.oldSpace.externalSize;
        expect(externalSize <= lastValue, isTrue);
        lastValue = externalSize;
      }

      // Sort by external size, smallest to largest.
      await tester.tap(instances);
      await tester.pumpAndSettle();

      lastValue = state.data.first!.newSpace.externalSize +
          state.data.first!.oldSpace.externalSize;
      for (final element in state.data) {
        final externalSize =
            element!.newSpace.externalSize + element.oldSpace.externalSize;
        expect(externalSize >= lastValue, isTrue);
        lastValue = externalSize;
      }
    });
  });
}
