// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/variables.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/object_tree.dart';
import 'package:devtools_app/src/shared/tree.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('debugger variables', () {
    late DartObjectNode objectNode;

    setUp(() {
      setGlobal(IdeTheme, IdeTheme());
      objectNode = DartObjectNode.text('test node');
    });

    Future<void> pumpExpandableVariable(
      WidgetTester tester,
      DartObjectNode? variable,
    ) async {
      await tester.pumpWidget(
        wrap(
          ExpandableVariable(
            variable: variable,
            debuggerController: MockDebuggerController(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ExpandableVariable), findsOneWidget);
    }

    testWidgets('ExpandableVariable builds without error',
        (WidgetTester tester) async {
      await pumpExpandableVariable(tester, objectNode);
      expect(find.byType(TreeView<DartObjectNode>), findsOneWidget);
      expect(
        find.byKey(ExpandableVariable.emptyExpandableVariableKey),
        findsNothing,
      );
    });

    testWidgets('ExpandableVariable builds for null variable',
        (WidgetTester tester) async {
      await pumpExpandableVariable(tester, null);
      expect(find.byType(TreeView<DartObjectNode>), findsNothing);
      expect(
        find.byKey(ExpandableVariable.emptyExpandableVariableKey),
        findsOneWidget,
      );
    });
  });
}
