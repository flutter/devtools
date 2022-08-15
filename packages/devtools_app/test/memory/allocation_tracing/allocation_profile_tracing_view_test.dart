// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/memory/memory_heap_tree_view.dart';
import 'package:devtools_app/src/screens/memory/panes/allocation_tracing/allocation_profile_tracing_tree.dart';
import 'package:devtools_app/src/screens/memory/panes/allocation_tracing/allocation_profile_tracing_view.dart';
import 'package:devtools_app/src/screens/memory/panes/allocation_tracing/allocation_profile_tracing_view_controller.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_data/memory_allocation.dart';

void main() {
  late FakeServiceManager fakeServiceManager;

  void _setUpServiceManager() {
    // Load canned data testHeapSampleData.
    final allocationJson =
        AllocationMemoryJson.decode(argJsonString: testAllocationData);

    final classList = ClassList(
      classes: [
        ClassRef(id: 'cls/1', name: 'ClassA'),
        ClassRef(id: 'cls/2', name: 'ClassB'),
        ClassRef(id: 'cls/3', name: 'ClassC'),
      ],
    );

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

  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);
  setGlobal(NotificationService, NotificationService());

  test('Allocation tracing disabled by default', () {
    // TODO(bkonyi): remove this check once we enable the tab by default.
    expect(enableNewAllocationProfileTable, isFalse);
  });

  group('Allocation Tracing', () {
    late final CpuSamples allocationTracingProfile;
    setUpAll(() {
      enableNewAllocationProfileTable = true;
      final rawProfile = File(
        'test/test_data/allocation_trace.json',
      ).readAsStringSync();
      allocationTracingProfile = CpuSamples.parse(jsonDecode(rawProfile))!;
    });
    tearDownAll(() => enableNewAllocationProfileTable = false);

    setUp(() async {
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

      // There should be three classes in the example class list.
      expect(find.byType(Checkbox), findsNWidgets(3));
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
  });
}
