// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_code_display.dart';
import 'package:devtools_app/src/shared/table/table.dart';
import 'package:devtools_test/devtools_test.dart';
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
      setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());
      setGlobal(PreferencesController, PreferencesController());

      mockCodeObject = MockCodeObject();
      final testCode = Code(
        id: 'code-obj',
        kind: 'Dart',
        name: 'testFuncCode',
      );
      testCode.json = {
        'function': testFunction.toJson(),
        '_objectPool': {
          'id': 'pool-id',
          'length': 0,
        }
      };
      final offset = pow(2, 20) as int;
      const addressCount = 1000;
      testCode.disassembly = Disassembly.parse(<Object?>[
        for (int i = 0; i < addressCount; ++i) ...[
          (i * 4 + offset).toRadixString(16),
          'unknown',
          'noop',
          null,
        ]
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
      when(mockCodeObject.inboundReferences).thenReturn(
        const FixedValueListenable<InboundReferences?>(null),
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

    testWidgetsWithWindowSize(
        'displays CodeTable instructions in order of increasing address',
        windowSize, (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          VmCodeDisplay(
            code: mockCodeObject,
            controller: ObjectInspectorViewController(),
          ),
        ),
      );

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

      // Ensure ordering is correct.
      verifyAddressOrder(
        state.tableController.tableData.value.data,
        mockCodeObject.ticksTable,
      );

      final columns = state.widget.columns;

      // Make sure the table can't be sorted differently.
      for (final column in columns) {
        await tester.tap(find.text(column.title));
        await tester.pumpAndSettle();
        verifyAddressOrder(
          state.tableController.tableData.value.data,
          mockCodeObject.ticksTable,
        );
      }
    });
  });
}
