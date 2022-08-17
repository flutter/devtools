// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/primitives/trees.dart';
import 'package:devtools_app/src/screens/memory/memory_controller.dart';
import 'package:devtools_app/src/screens/memory/memory_heap_tree_view.dart';
import 'package:devtools_app/src/screens/memory/memory_screen.dart';
import 'package:devtools_app/src/screens/memory/panes/allocation_tracing/allocation_profile_class_table.dart';
import 'package:devtools_app/src/screens/memory/panes/allocation_tracing/allocation_profile_tracing_tree.dart';
import 'package:devtools_app/src/screens/memory/panes/allocation_tracing/allocation_profile_tracing_view.dart';
import 'package:devtools_app/src/screens/memory/panes/allocation_tracing/allocation_profile_tracing_view_controller.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_data/memory_allocation.dart';

void main() {
  late FakeServiceManager fakeServiceManager;

  final classList = ClassList(
    classes: [
      ClassRef(id: 'cls/1', name: 'ClassA'),
      ClassRef(id: 'cls/2', name: 'ClassB'),
      ClassRef(id: 'cls/3', name: 'ClassC'),
      ClassRef(id: 'cls/4', name: 'Foo'),
    ],
  );

  void _setUpServiceManager() {
    // Load canned data testHeapSampleData.
    final allocationJson =
        AllocationMemoryJson.decode(argJsonString: testAllocationData);

    fakeServiceManager = FakeServiceManager(
      service: FakeServiceManager.createFakeService(
        allocationData: allocationJson,
        classList: classList,
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

  Future<void> pumpMemoryScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const MemoryBody(),
        memory: MemoryController(),
      ),
    );

    // Delay to ensure the memory profiler has collected data.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(MemoryBody), findsOneWidget);
  }

  /// Clears the class filter text field.
  Future<void> clearFilter(
    WidgetTester tester,
    AllocationProfileTracingViewController controller,
  ) async {
    final originalClassCount = classList.classes!.length;
    final clearFilterButton = find.byIcon(Icons.clear);
    expect(clearFilterButton, findsOneWidget);
    await tester.tap(clearFilterButton);
    await tester.pumpAndSettle();
    expect(controller.classList.value.length, originalClassCount);
  }

  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);

  test('Allocation tracing disabled by default', () {
    // TODO(bkonyi): remove this check once we enable the tab by default.
    expect(enableNewAllocationProfileTable, isFalse);
  });

  group('Allocation Tracing', () {
    late final CpuSamples allocationTracingProfile;

    setUpAll(() {
      enableNewAllocationProfileTable = true;
      final rawProfile = File(
        'test/test_data/memory/allocation_tracing/allocation_trace.json',
      ).readAsStringSync();
      allocationTracingProfile = CpuSamples.parse(jsonDecode(rawProfile))!;
    });

    tearDownAll(() => enableNewAllocationProfileTable = false);

    setUp(() async {
      setGlobal(NotificationService, NotificationService());
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(PreferencesController, PreferencesController());
      _setUpServiceManager();
    });

    Future<AllocationProfileTracingViewController> navigateToAllocationTracing(
      WidgetTester tester,
    ) async {
      await tester.tap(
        find.byKey(HeapTreeViewState.dartHeapAllocationTracingKey),
      );
      await tester.pumpAndSettle();

      final view = find.byType(AllocationProfileTracingView).first;
      final state = tester.state<AllocationProfileTracingViewState>(view);

      return state.controller;
    }

    testWidgetsWithWindowSize('basic tracing flow', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      final controller = await navigateToAllocationTracing(tester);
      expect(controller.classList.value.isNotEmpty, isTrue);
      expect(controller.initializing.value, isFalse);
      expect(controller.refreshing.value, isFalse);
      expect(controller.selectedTracedClass.value, isNull);
      expect(controller.selectedTracedClassAllocationData, isNull);

      final refresh = find.text('Refresh');
      expect(refresh, findsOneWidget);

      expect(find.text('Trace'), findsOneWidget);
      expect(find.text('Class'), findsOneWidget);
      expect(find.text('Instances'), findsOneWidget);

      // There should be classes in the example class list.
      expect(find.byType(Checkbox), findsNWidgets(classList.classes!.length));
      for (final cls in controller.classList.value) {
        expect(find.byKey(Key(cls.cls.id!)), findsOneWidget);
      }

      // Enable allocation tracing for one of them.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(
        controller.classList.value
            .map((e) => e.traceAllocations)
            .where((e) => e)
            .length,
        1,
      );

      final selectedTrace = controller.classList.value.firstWhere(
        (e) => e.traceAllocations,
      );

      expect(find.byType(AllocationProfileTracingBottomUpTable), findsNothing);
      final traceElement = find.byKey(Key(selectedTrace.cls.id!));
      expect(traceElement, findsOneWidget);

      // Select the list item for the traced class and refresh to fetch data.
      await tester.tap(traceElement);
      await tester.pumpAndSettle();
      await tester.tap(refresh);
      await tester.pumpAndSettle();

      // No allocations have occurred, so the trace viewer shows an error message.
      expect(controller.selectedTracedClass.value, selectedTrace);
      expect(controller.selectedTracedClassAllocationData, isNotNull);
      expect(
        find.text(
          'No allocation samples have been collected for class ${selectedTrace.cls.name}.\n',
        ),
        findsOneWidget,
      );

      // Set fake sample data and refresh to populate the trace view.
      final fakeService = serviceManager.service as FakeVmServiceWrapper;
      fakeService.allocationSamples = allocationTracingProfile;

      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(
        find.byType(AllocationProfileTracingBottomUpTable),
        findsOneWidget,
      );

      // Verify the expected widget components are present.
      expect(find.textContaining('Traced allocations for: '), findsOneWidget);
      expect(find.text('Expand All'), findsOneWidget);
      expect(find.text('Collapse All'), findsOneWidget);
      expect(find.text('Inclusive'), findsOneWidget);
      expect(find.text('Exclusive'), findsOneWidget);
      expect(find.text('Method'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);

      final bottomUpRoots =
          controller.selectedTracedClassAllocationData!.bottomUpRoots;
      for (final root in bottomUpRoots) {
        expect(root.isExpanded, false);
      }

      await tester.tap(find.text('Expand All'));
      await tester.pumpAndSettle();

      // Check all nodes have been expanded.
      for (final root in bottomUpRoots) {
        breadthFirstTraversal<CpuStackFrame>(
          root,
          action: (e) {
            expect(e.isExpanded, true);
          },
        );
      }

      await tester.tap(find.text('Collapse All'));
      await tester.pumpAndSettle();

      // Check all nodes have been collapsed.
      for (final root in bottomUpRoots) {
        breadthFirstTraversal<CpuStackFrame>(
          root,
          action: (e) {
            expect(e.isExpanded, false);
          },
        );
      }
    });

    group('filtering', () {
      final originalClassCount = classList.classes!.length;

      testWidgetsWithWindowSize('simple', windowSize, (tester) async {
        await pumpMemoryScreen(tester);

        final controller = await navigateToAllocationTracing(tester);

        final filterTextField = find.byType(ClassFilterTextField);
        expect(filterTextField, findsOneWidget);

        // Filter for 'F'
        await tester.enterText(filterTextField, 'F');
        await tester.pumpAndSettle();
        expect(controller.classList.value.length, 1);
        expect(controller.classList.value.first.cls.name, 'Foo');

        // Filter for 'Fooo'
        await tester.enterText(filterTextField, 'Fooo');
        await tester.pumpAndSettle();
        expect(controller.classList.value.isEmpty, true);

        // Clear filter
        await clearFilter(tester, controller);
      });

      testWidgetsWithWindowSize('persisted tracing state', windowSize,
          (tester) async {
        await pumpMemoryScreen(tester);

        final controller = await navigateToAllocationTracing(tester);

        final checkboxes = find.byType(Checkbox);
        expect(checkboxes, findsNWidgets(originalClassCount));

        // Enable allocation tracing for one of them
        await tester.tap(checkboxes.first);
        await tester.pumpAndSettle();

        final tracedClassList = controller.classList.value
            .where((e) => e.traceAllocations)
            .toList();
        expect(tracedClassList.length, 1);
        expect(tracedClassList.first.cls, classList.classes!.first);

        // Filter out all classes and then clear the filter
        final filterTextField = find.byType(ClassFilterTextField);
        expect(filterTextField, findsOneWidget);

        await tester.enterText(filterTextField, 'Garbage');
        await tester.pumpAndSettle();
        expect(controller.classList.value.isEmpty, true);

        await clearFilter(tester, controller);

        // Check tracing state wasn't corrupted
        final updatedTracedClassList = controller.classList.value
            .where((e) => e.traceAllocations)
            .toList();
        expect(updatedTracedClassList, containsAll(tracedClassList));
        expect(updatedTracedClassList.first.traceAllocations, true);
      });

      testWidgetsWithWindowSize('persisted selection state', windowSize,
          (tester) async {
        await pumpMemoryScreen(tester);

        final controller = await navigateToAllocationTracing(tester);

        expect(controller.selectedTracedClass.value, isNull);

        // Select one of the class entries.
        final selection = find.richTextContaining(
          classList.classes!.last.name!,
        );
        expect(selection, findsOneWidget);

        await tester.tap(selection);
        await tester.pumpAndSettle();

        expect(controller.selectedTracedClass.value, isNotNull);
        final originalSelection = controller.selectedTracedClass.value;

        // Filter out all classes, ensure the selection is still valid, then
        // clear the filter and check again.
        final filterTextField = find.byType(ClassFilterTextField);
        expect(filterTextField, findsOneWidget);

        await tester.enterText(filterTextField, 'Garbage');
        await tester.pumpAndSettle();
        expect(controller.classList.value.isEmpty, true);

        expect(controller.selectedTracedClass.value, originalSelection);

        await clearFilter(tester, controller);

        expect(controller.selectedTracedClass.value, originalSelection);
      });
    });
  });
}
