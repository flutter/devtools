// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/memory/memory_controller.dart';
import 'package:devtools_app/src/screens/memory/memory_heap_tree_view.dart';
import 'package:devtools_app/src/screens/memory/memory_screen.dart';
import 'package:devtools_app/src/screens/memory/panes/allocation_profile/allocation_profile_table_view.dart';
import 'package:devtools_app/src/screens/memory/panes/allocation_profile/allocation_profile_table_view_controller.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

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
    when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
    when(fakeServiceManager.connectedApp!.isFlutterAppNow).thenReturn(true);
    when(fakeServiceManager.connectedApp!.isDartCliAppNow).thenReturn(false);
    when(fakeServiceManager.connectedApp!.isDebugFlutterAppNow)
        .thenReturn(false);
    when(fakeServiceManager.connectedApp!.isDartWebApp)
        .thenAnswer((_) => Future.value(false));
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

  test('Allocation profile disabled by default', () {
    // TODO(bkonyi): remove this check once we enable the tab by default.
    expect(enableNewAllocationProfileTable, isFalse);
  });

  group('Allocation Profile Table', () {
    setUpAll(() => enableNewAllocationProfileTable = true);
    tearDownAll(() => enableNewAllocationProfileTable = false);

    setUp(() async {
      fakeServiceManager = FakeServiceManager();
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(PreferencesController, PreferencesController());
    });

    Future<void> navigateToAllocationProfile(
      WidgetTester tester,
      AllocationProfileTableViewController allocationProfileController,
    ) async {
      expect(
        allocationProfileController.currentAllocationProfile.value,
        isNull,
      );

      await tester.tap(find.byKey(HeapTreeViewState.dartHeapTableTabKey));
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
      _setUpServiceManagerForMemory();

      final allocationProfileController =
          controller.allocationProfileController;

      preferences.toggleVmDeveloperMode(false);
      await navigateToAllocationProfile(tester, allocationProfileController);

      // Only "total" statistics are shown when VM Developer Mode is disabled.
      expect(preferences.vmDeveloperModeEnabled.value, isFalse);
      expect(find.text('Class'), findsOneWidget);
      expect(find.text('Instances'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('Internal'), findsOneWidget);
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
      expect(find.text('Size'), findsNWidgets(3));
      expect(find.text('Internal'), findsNWidgets(3));
      expect(find.text('External'), findsNWidgets(3));
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Old Space'), findsOneWidget);
      expect(find.text('New Space'), findsOneWidget);
    });

    testWidgetsWithWindowSize('manually refreshes', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);
      _setUpServiceManagerForMemory();

      final allocationProfileController =
          controller.allocationProfileController;
      await navigateToAllocationProfile(tester, allocationProfileController);

      // We'll clear it for now so we can tell when it's refreshed.
      allocationProfileController.clearCurrentProfile();
      await tester.pump();

      // Refresh the profile.
      await tester.tap(
        find.byKey(AllocationProfileTableViewState.refreshKey).first,
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
      _setUpServiceManagerForMemory();

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
        find.byKey(AllocationProfileTableViewState.refreshOnGcKey).first,
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
  });
}
