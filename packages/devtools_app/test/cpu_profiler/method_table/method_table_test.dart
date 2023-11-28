// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_transformer.dart';
import 'package:devtools_app/src/screens/profiler/panes/method_table/method_table.dart';
import 'package:devtools_app/src/screens/profiler/panes/method_table/method_table_controller.dart';
import 'package:devtools_app/src/screens/profiler/panes/method_table/method_table_model.dart';
import 'package:devtools_app/src/shared/table/table.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_infra/matchers/_golden_matcher_io.dart';
import '../../test_infra/test_data/cpu_profiler/simple_profile_2.dart';
import '../../test_infra/utils/test_utils.dart';

void main() {
  late MethodTableController methodTableController;

  setUp(() async {
    setCharacterWidthForTables();
    setGlobal(
      ServiceConnectionManager,
      createMockServiceConnectionWithDefaults(),
    );
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(OfflineModeController, OfflineModeController());
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
    final data = CpuProfileData.parse(simpleCpuProfile2);
    await CpuProfileTransformer().processData(data, processId: 'test');
    methodTableController = MethodTableController(
      dataNotifier: FixedValueListenable<CpuProfileData>(data),
    )..createMethodTableGraph(data);
  });

  const windowSize = Size(2000.0, 1000.0);

  Future<void> pumpMethodTable(WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        CpuMethodTable(
          methodTableController: methodTableController,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CpuMethodTable), findsOneWidget);
  }

  group('$CpuMethodTable', () {
    testWidgetsWithWindowSize(
      'loads methods with no selection',
      windowSize,
      (WidgetTester tester) async {
        await pumpMethodTable(tester);
        expect(
          find.byType(SearchableFlatTable<MethodTableGraphNode>),
          findsOneWidget,
        );
        expect(find.text('Method'), findsOneWidget);
        expect(find.text('Total %'), findsOneWidget);
        expect(find.text('Self %'), findsOneWidget);
        expect(find.text('Caller %'), findsNothing);
        expect(find.text('Callee %'), findsNothing);
        expect(
          find.text('Select a method to view its call graph.'),
          findsOneWidget,
        );
        await expectLater(
          find.byType(CpuMethodTable),
          matchesDevToolsGolden(
            '../../test_infra/goldens/cpu_profiler/method_table_no_selection.png',
          ),
        );
      },
    );

    testWidgetsWithWindowSize(
      'loads methods with selection',
      windowSize,
      (WidgetTester tester) async {
        final interestingNode = methodTableController.methods.value.first;
        expect(interestingNode.name, 'A');
        expect(interestingNode.predecessors, isNotEmpty);
        expect(interestingNode.successors, isNotEmpty);

        methodTableController.selectedNode.value = interestingNode;
        await pumpMethodTable(tester);
        expect(
          find.byType(SearchableFlatTable<MethodTableGraphNode>),
          findsOneWidget,
        );
        expect(find.byType(FlatTable<MethodTableGraphNode>), findsNWidgets(2));
        expect(find.text('Method'), findsNWidgets(3));
        expect(find.text('Total %'), findsOneWidget);
        expect(find.text('Self %'), findsOneWidget);
        expect(find.text('Caller %'), findsOneWidget);
        expect(find.text('Callee %'), findsOneWidget);
        expect(
          find.text('Select a method to view its call graph.'),
          findsNothing,
        );
        await expectLater(
          find.byType(CpuMethodTable),
          matchesDevToolsGolden(
            '../../test_infra/goldens/cpu_profiler/method_table_with_selection.png',
          ),
        );

        methodTableController.selectedNode.value =
            methodTableController.methods.value.last;
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(CpuMethodTable),
          matchesDevToolsGolden(
            '../../test_infra/goldens/cpu_profiler/method_table_with_selection_2.png',
          ),
        );
      },
    );
  });
}
