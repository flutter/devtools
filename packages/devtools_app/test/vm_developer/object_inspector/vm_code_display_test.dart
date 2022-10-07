// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/object_inspector_view_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_code_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_service_private_extensions.dart';
import 'package:devtools_app/src/shared/globals.dart';
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

      mockCodeObject = MockCodeObject();
      final testCode = Code(
        id: 'code-obj',
        kind: 'Dart',
        name: 'testFuncCode',
      );
      testCode.json = {};
      final offset = pow(2, 20) as int;
      testCode.disassembly = Disassembly.parse(<dynamic>[
        for (int i = 0; i < 1000; ++i) ...[
          (i * 4 + offset).toRadixString(16),
          'unknown',
          'noop',
          null,
        ]
      ]);

      when(mockCodeObject.obj).thenReturn(testCode);
    });

    void verifyAddressOrder(List<Instruction> data) {
      int lastAddress = 0;
      for (final instr in data) {
        final currentAddress = int.parse(instr.address, radix: 16);
        expect(currentAddress > lastAddress, isTrue);
        lastAddress = currentAddress;
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

      // Ensure ordering is correct.
      verifyAddressOrder(state.tableController.tableData.value.data);

      final columns = state.widget.columns;

      // Make sure the table can't be sorted differently.
      for (final column in columns) {
        await tester.tap(find.text(column.title));
        await tester.pumpAndSettle();
        verifyAddressOrder(state.tableController.tableData.value.data);
      }
    });
  });
}
