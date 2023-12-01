// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/inbound_references_tree.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_code_display.dart';
import 'package:devtools_app/src/shared/table/table.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  late MockCodeObject mockCodeObject;

  const windowSize = Size(4000.0, 4000.0);

  group('VmCodeDisplay', () {
    setUp(() {
      setUpMockScriptManager();
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());

      mockCodeObject = MockCodeObject();
      final testCode = Code(
        id: 'code-obj',
        kind: 'Dart',
        name: 'testFuncCode',
      );

      final offset = pow(2, 20) as int;
      const addressCount = 1000;
      testCode.json = {
        'function': testFunction.toJson(),
        '_objectPool': {
          'id': 'pool-id',
          'length': 0,
        },
        InliningData.kInlinedFunctions: [
          testFunction.toJson(),
        ],
        InliningData.kStartAddressKey: offset.toRadixString(16),
        InliningData.kInlinedIntervals: [
          // Pretend that each group of 4 instructions are inlined.
          for (int i = 0; i < addressCount / 4; ++i)
            [
              (i * 16), // Start address
              ((i + 1) * 16 - 1), // End address
              0, // The third entry is always 0, for... reasons.
              0, // The remaining entries are indicies into kInlinedFunctions
              0,
            ],
        ],
      };

      testCode.disassembly = Disassembly.parse(<Object?>[
        for (int i = 0; i < addressCount; ++i) ...[
          (i * 4 + offset).toRadixString(16),
          'unknown',
          'noop',
          null,
        ],
      ]);

      final ticksTable = CpuProfilerTicksTable.parse(
        sampleCount: 1000,
        ticks: [
          for (int i = 0; i < addressCount; ++i) ...[
            (i * 4 + offset).toRadixString(16),
            1,
            1,
          ],
        ],
      );

      when(mockCodeObject.obj).thenReturn(testCode);
      when(mockCodeObject.script).thenReturn(null);
      when(mockCodeObject.retainingPath).thenReturn(
        const FixedValueListenable<RetainingPath?>(null),
      );
      when(mockCodeObject.inboundReferencesTree).thenReturn(
        const FixedValueListenable<List<InboundReferencesTreeNode>>([]),
      );
      when(mockCodeObject.fetchingReachableSize).thenReturn(
        const FixedValueListenable<bool>(false),
      );
      when(mockCodeObject.fetchingRetainedSize).thenReturn(
        const FixedValueListenable<bool>(false),
      );
      when(mockCodeObject.retainedSize).thenReturn(null);
      when(mockCodeObject.reachableSize).thenReturn(null);
      when(mockCodeObject.ticksTable).thenReturn(ticksTable);
    });

    Future<void> verifyCodeTable(WidgetTester tester) async {
      expect(find.byType(CodeTable), findsOneWidget);
      final FlatTableState<Instruction> state =
          tester.state(find.byType(FlatTable<Instruction>));

      // Check that the profiler columns render ticks correctly.
      final profilerColumns = state.tableController.columns.where(
        (c) => c.title == 'Total %' || c.title == 'Self %',
      );
      expect(profilerColumns.length, 2);
      for (final profilerColumn in profilerColumns) {
        for (final instr in state.tableController.tableData.value.data) {
          expect(profilerColumn.getDisplayValue(instr), '0.10% (1)');
        }
      }

      void verifyAddressOrder(
        List<Instruction> data,
        CpuProfilerTicksTable? ticks,
      ) {
        int lastAddress = 0;
        for (final instr in data) {
          final currentAddress = int.parse(instr.address, radix: 16);
          expect(currentAddress > lastAddress, isTrue);
          lastAddress = currentAddress;

          final tick = ticks![instr.unpaddedAddress];
          expect(tick, isNotNull);
          expect(tick!.inclusiveTicks, 1);
          expect(tick.exclusiveTicks, 1);
        }
      }

      // Ensure ordering is correct.
      verifyAddressOrder(
        state.tableController.tableData.value.data,
        mockCodeObject.ticksTable,
      );

      final columns = state.widget.columns;

      // Make sure the table can't be sorted differently.
      for (final column in columns) {
        await tester.tap(
          find.descendant(
            of: find.byType(CodeTable),
            matching: find.text(column.title),
          ),
        );
        await tester.pumpAndSettle();
        verifyAddressOrder(
          state.tableController.tableData.value.data,
          mockCodeObject.ticksTable,
        );
      }
    }

    Future<void> verifyInliningTable(WidgetTester tester) async {
      expect(find.byType(InliningTable), findsOneWidget);
      final FlatTableState<InliningEntry> state =
          tester.state(find.byType(FlatTable<InliningEntry>));

      // Check that the profiler columns render ticks correctly.
      final profilerColumns = state.tableController.columns.where(
        (c) => c.title == 'Total %' || c.title == 'Self %',
      );
      expect(profilerColumns.length, 2);
      for (final profilerColumn in profilerColumns) {
        for (final instr in state.tableController.tableData.value.data) {
          expect(profilerColumn.getDisplayValue(instr), '0.40% (4)');
        }
      }

      void verifyAddressOrder(
        List<InliningEntry> data,
        CpuProfilerTicksTable? ticks,
      ) {
        int lastAddress = 0;
        for (final inlining in data) {
          final inliningRange = inlining.addressRange;
          final begin = inliningRange.begin.toInt();
          final end = inliningRange.end.toInt();

          expect(begin < end, isTrue);
          expect(begin > lastAddress, isTrue);
          lastAddress = end;

          final tick = ticks!.forRange(begin, end);
          expect(tick, isNotNull);
          expect(tick!.inclusiveTicks, 4);
          expect(tick.exclusiveTicks, 4);
        }
      }

      // Ensure ordering is correct.
      verifyAddressOrder(
        state.tableController.tableData.value.data,
        mockCodeObject.ticksTable,
      );

      final columns = state.widget.columns;

      // Make sure the table can't be sorted differently.
      for (final column in columns) {
        await tester.tap(
          find.descendant(
            of: find.byType(InliningTable),
            matching: find.text(column.title),
          ),
        );
        await tester.pumpAndSettle();
        verifyAddressOrder(
          state.tableController.tableData.value.data,
          mockCodeObject.ticksTable,
        );
      }
    }

    testWidgetsWithWindowSize(
      'displays CodeTable and InliningTable instructions in order of increasing address',
      windowSize,
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapSimple(
            VmCodeDisplay(
              code: mockCodeObject,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );

        await verifyCodeTable(tester);
        await verifyInliningTable(tester);
      },
    );
  });
}
