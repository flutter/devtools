// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/framework/memory_tabs.dart';
import 'package:devtools_app/src/screens/memory/panes/tracing/tracing_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/tracing/tracing_tree.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_infra/scenes/memory/default.dart';
import '../../test_infra/utils/test_utils.dart';

// TODO(bkonyi): add tests for multi-isolate support.
// See https://github.com/flutter/devtools/issues/4537.

void main() {
  final classList = ClassList(
    classes: [
      ClassRef(id: 'cls/1', name: 'ClassA'),
      ClassRef(id: 'cls/2', name: 'ClassB'),
      ClassRef(id: 'cls/3', name: 'ClassC'),
      ClassRef(id: 'cls/4', name: 'Foo'),
    ],
  );

  /// Clears the class filter text field.
  Future<void> clearFilter(
    WidgetTester tester,
    TracingPaneController controller,
  ) async {
    final originalClassCount = classList.classes!.length;
    final clearFilterButton = find.byIcon(Icons.clear);
    expect(clearFilterButton, findsOneWidget);
    await tester.tap(clearFilterButton);
    await tester.pumpAndSettle();
    expect(
      controller.selection.value.filteredClassList.value.length,
      originalClassCount,
    );
  }

  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);

  group('Allocation Tracing', () {
    late MemoryDefaultScene scene;

    late final CpuSamples allocationTracingProfile;

    Future<void> pumpScene(WidgetTester tester) async {
      await scene.pump(tester);
      await tester.tap(
        find.byKey(MemoryScreenKeys.traceTab),
      );
      await tester.pumpAndSettle();
    }

    setUpAll(() {
      final rawProfile = File(
        'test/test_infra/test_data/memory/allocation_tracing/allocation_trace.json',
      ).readAsStringSync();
      allocationTracingProfile = CpuSamples.parse(jsonDecode(rawProfile))!;
    });

    setUp(() async {
      setCharacterWidthForTables();

      scene = MemoryDefaultScene();
      await scene.setUp(classList: classList);
      mockConnectedApp(
        scene.fakeServiceConnection.serviceManager.connectedApp!,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: false,
      );

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

    tearDown(() {
      scene.tearDown();
    });

    testWidgetsWithWindowSize(
      'basic tracing flow',
      windowSize,
      (WidgetTester tester) async {
        await pumpScene(tester);

        final controller = scene.controller.trace!;
        final state = controller.selection.value;
        expect(state.filteredClassList.value.isNotEmpty, isTrue);
        expect(controller.initializing.value, isFalse);
        expect(controller.refreshing.value, isFalse);
        expect(state.selectedTracedClass.value, isNull);
        expect(state.selectedTracedClassAllocationData, isNull);

        final refresh = find.text('Refresh');
        expect(refresh, findsOneWidget);

        expect(find.text('Trace'), findsOneWidget);
        expect(find.text('Class'), findsOneWidget);
        expect(find.text('Delta'), findsOneWidget);

        // There should be classes in the example class list.
        expect(find.byType(Checkbox), findsNWidgets(classList.classes!.length));
        for (final cls in state.filteredClassList.value) {
          expect(find.byKey(Key(cls.cls.id!)), findsOneWidget);
        }

        // Enable allocation tracing for one of them.
        await tester.tap(find.byType(Checkbox).first);
        await tester.pumpAndSettle();

        expect(
          state.filteredClassList.value
              .map((e) => e.traceAllocations)
              .where((e) => e)
              .length,
          1,
        );

        final selectedTrace = state.filteredClassList.value.firstWhere(
          (e) => e.traceAllocations,
        );

        expect(find.byType(TracingTable), findsNothing);
        final traceElement = find.byKey(Key(selectedTrace.cls.id!));
        expect(traceElement, findsOneWidget);

        // Select the list item for the traced class and refresh to fetch data.
        await tester.tap(traceElement);
        await tester.pumpAndSettle();
        await tester.tap(refresh);
        await tester.pumpAndSettle();

        // No allocations have occurred, so the trace viewer shows an error message.
        expect(state.selectedTracedClass.value, selectedTrace);
        expect(state.selectedTracedClassAllocationData, isNotNull);
        expect(
          find.text(
            'No allocation samples have been collected for class ${selectedTrace.cls.name}.\n',
          ),
          findsOneWidget,
        );

        // Set fake sample data and refresh to populate the trace view.
        final fakeService =
            serviceConnection.serviceManager.service as FakeVmServiceWrapper;
        fakeService.allocationSamples = allocationTracingProfile;

        await tester.tap(refresh);
        await tester.pumpAndSettle();
        expect(
          find.byType(TracingTable),
          findsOneWidget,
        );

        // Verify the expected widget components are present.
        expect(find.textContaining('Traced allocations for: '), findsOneWidget);
        expect(find.text('Bottom Up'), findsOneWidget);
        expect(find.text('Call Tree'), findsOneWidget);
        expect(find.text('Expand All'), findsOneWidget);
        expect(find.text('Collapse All'), findsOneWidget);
        expect(find.text('Inclusive'), findsOneWidget);
        expect(find.text('Exclusive'), findsOneWidget);
        expect(find.text('Method'), findsOneWidget);

        final bottomUpRoots =
            state.selectedTracedClassAllocationData!.bottomUpRoots;
        final callTreeRoots =
            state.selectedTracedClassAllocationData!.callTreeRoots;
        for (final root in bottomUpRoots) {
          expect(root.isExpanded, false);
        }
        for (final root in callTreeRoots) {
          expect(root.isExpanded, false);
        }

        await tester.tap(find.text('Expand All'));
        await tester.pumpAndSettle();

        // Check all nodes in the bottom up tree have been expanded.
        for (final root in bottomUpRoots) {
          breadthFirstTraversal<CpuStackFrame>(
            root,
            action: (e) {
              expect(e.isExpanded, true);
            },
          );
        }

        // But also make sure that the call tree nodes haven't been expanded.
        for (final root in callTreeRoots) {
          expect(root.isExpanded, false);
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

        // Switch from bottom up view to call tree view.
        await tester.tap(find.text('Call Tree'));
        await tester.pumpAndSettle();

        // Expand the call tree.
        await tester.tap(find.text('Expand All'));
        await tester.pumpAndSettle();

        // Check all nodes in the call tree have been expanded.
        for (final root in callTreeRoots) {
          breadthFirstTraversal<CpuStackFrame>(
            root,
            action: (e) {
              expect(e.isExpanded, true);
            },
          );
        }

        // But also make sure that the bottom up tree nodes haven't been expanded.
        for (final root in bottomUpRoots) {
          expect(root.isExpanded, false);
        }

        await tester.tap(find.text('Collapse All'));
        await tester.pumpAndSettle();

        // Check all nodes have been collapsed.
        for (final root in callTreeRoots) {
          breadthFirstTraversal<CpuStackFrame>(
            root,
            action: (e) {
              expect(e.isExpanded, false);
            },
          );
        }
      },
    );

    testWidgetsWithWindowSize(
      'clear state',
      windowSize,
      (WidgetTester tester) async {
        await pumpScene(tester);

        final controller = scene.controller.trace!;
        final state = controller.selection.value;
        expect(state.filteredClassList.value.isNotEmpty, isTrue);
        expect(controller.initializing.value, isFalse);
        expect(controller.refreshing.value, isFalse);
        expect(state.selectedTracedClass.value, isNull);
        expect(state.selectedTracedClassAllocationData, isNull);

        final refresh = find.text('Refresh');
        expect(refresh, findsOneWidget);

        expect(find.text('Trace'), findsOneWidget);
        expect(find.text('Class'), findsOneWidget);
        expect(find.text('Delta'), findsOneWidget);

        // There should be classes in the example class list.
        expect(find.byType(Checkbox), findsNWidgets(classList.classes!.length));
        for (final cls in state.filteredClassList.value) {
          expect(find.byKey(Key(cls.cls.id!)), findsOneWidget);
        }

        // Enable allocation tracing for one of them.
        await tester.tap(find.byType(Checkbox).first);
        await tester.pumpAndSettle();

        expect(
          state.filteredClassList.value
              .map((e) => e.traceAllocations)
              .where((e) => e)
              .length,
          1,
        );

        final selectedTrace = state.filteredClassList.value.firstWhere(
          (e) => e.traceAllocations,
        );

        expect(find.byType(TracingTable), findsNothing);
        final traceElement = find.byKey(Key(selectedTrace.cls.id!));
        expect(traceElement, findsOneWidget);

        // Select the list item for the traced class and refresh to fetch data.
        await tester.tap(traceElement);
        await tester.pumpAndSettle();
        await tester.tap(refresh);
        await tester.pumpAndSettle();

        // No allocations have occurred, so the trace viewer shows an error message.
        expect(state.selectedTracedClass.value, selectedTrace);
        expect(state.selectedTracedClassAllocationData, isNotNull);
        expect(
          find.text(
            'No allocation samples have been collected for class ${selectedTrace.cls.name}.\n',
          ),
          findsOneWidget,
        );

        // Set fake sample data and refresh to populate the trace view.
        final fakeService =
            serviceConnection.serviceManager.service as FakeVmServiceWrapper;
        fakeService.allocationSamples = allocationTracingProfile;

        await tester.tap(refresh);
        await tester.pumpAndSettle();
        expect(
          find.byType(TracingTable),
          findsOneWidget,
        );

        final clearButton = find.byType(ClearButton);
        expect(clearButton, findsOneWidget);
        await tester.tap(clearButton);
        await tester.pumpAndSettle();

        // Clearing should zero out all the instance counts.
        expect(state.selectedTracedClass.value, isNotNull);
        for (final cls in state.filteredClassList.value) {
          expect(cls.instances, 0);
        }

        // Clear the fake sample data to emulate no additional samples collected
        // after a clear.
        fakeService.allocationSamples = CpuSamples(
          functions: [],
          samples: [],
          sampleCount: 0,
          timeOriginMicros: 0,
          timeExtentMicros: 0,
        );
        await tester.tap(refresh);
        await tester.pumpAndSettle();

        // Expect no new samples.
        expect(state.selectedTracedClass.value, isNotNull);
        for (final cls in state.filteredClassList.value) {
          expect(cls.instances, 0);
        }
      },
    );

    group('filtering', () {
      testWidgetsWithWindowSize('simple', windowSize, (tester) async {
        await pumpScene(tester);

        final controller = scene.controller.trace!;
        final state = controller.selection.value;

        final filterTextField = find.byType(DevToolsClearableTextField);
        expect(filterTextField, findsOneWidget);

        // Filter for 'F'
        await tester.enterText(filterTextField, 'F');
        await tester.pumpAndSettle();
        expect(state.filteredClassList.value.length, 1);
        expect(state.filteredClassList.value.first.cls.name, 'Foo');

        // Filter for 'Fooo'
        await tester.enterText(filterTextField, 'Fooo');
        await tester.pumpAndSettle();
        expect(state.filteredClassList.value.isEmpty, true);

        // Clear filter
        await clearFilter(tester, controller);
      });

      testWidgetsWithWindowSize(
        'persisted tracing state',
        windowSize,
        (tester) async {
          await pumpScene(tester);

          final controller = scene.controller.trace!;
          final state = controller.selection.value;

          final checkboxes = find.byType(Checkbox);
          expect(checkboxes, findsNWidgets(classList.classes!.length));

          // Enable allocation tracing for one of them
          await tester.tap(checkboxes.first);
          await tester.pumpAndSettle();

          final tracedClassList = state.filteredClassList.value
              .where((e) => e.traceAllocations)
              .toList();
          expect(tracedClassList.length, 1);
          expect(tracedClassList.first.cls, classList.classes!.first);

          // Filter out all classes and then clear the filter
          final filterTextField = find.byType(DevToolsClearableTextField);
          expect(filterTextField, findsOneWidget);

          await tester.enterText(filterTextField, 'Garbage');
          await tester.pumpAndSettle();
          expect(state.filteredClassList.value.isEmpty, true);

          await clearFilter(tester, controller);

          // Check tracing state wasn't corrupted
          final updatedTracedClassList = state.filteredClassList.value
              .where((e) => e.traceAllocations)
              .toList();
          expect(updatedTracedClassList, containsAll(tracedClassList));
          expect(updatedTracedClassList.first.traceAllocations, true);
        },
      );

      testWidgetsWithWindowSize(
        'persisted selection state',
        windowSize,
        (tester) async {
          await pumpScene(tester);

          final controller = scene.controller.trace!;
          final state = controller.selection.value;

          expect(state.selectedTracedClass.value, isNull);

          // Select one of the class entries.
          final selection = find.richTextContaining(
            classList.classes!.last.name!,
          );
          expect(selection, findsOneWidget);

          await tester.tap(selection);
          await tester.pumpAndSettle();

          expect(state.selectedTracedClass.value, isNotNull);
          final originalSelection = state.selectedTracedClass.value;

          // Filter out all classes, ensure the selection is still valid, then
          // clear the filter and check again.
          final filterTextField = find.byType(DevToolsClearableTextField);
          expect(filterTextField, findsOneWidget);

          await tester.enterText(filterTextField, 'Garbage');
          await tester.pumpAndSettle();
          expect(state.filteredClassList.value.isEmpty, true);

          expect(state.selectedTracedClass.value, originalSelection);

          await clearFilter(tester, controller);

          expect(state.selectedTracedClass.value, originalSelection);
        },
      );
    });
  });
}
