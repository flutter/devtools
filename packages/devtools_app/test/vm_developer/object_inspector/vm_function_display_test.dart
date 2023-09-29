// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_function_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  late MockFuncObject mockFuncObject;

  const windowSize = Size(4000.0, 4000.0);

  late Func testFunctionCopy;

  setUp(() {
    setUpMockScriptManager();
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(NotificationService, NotificationService());

    mockFuncObject = MockFuncObject();

    final funcJson = testFunction.toJson();
    testFunctionCopy = Func.parse(funcJson)!;

    testFunctionCopy.size = 256;
    testFunctionCopy.isStatic = true;
    testFunctionCopy.isConst = true;

    mockVmObject(mockFuncObject);
    when(mockFuncObject.obj).thenReturn(testFunctionCopy);
    when(mockFuncObject.kind).thenReturn(FunctionKind.ImplicitClosureFunction);
    when(mockFuncObject.deoptimizations).thenReturn(3);
    when(mockFuncObject.isOptimizable).thenReturn(true);
    when(mockFuncObject.isInlinable).thenReturn(true);
    when(mockFuncObject.hasIntrinsic).thenReturn(false);
    when(mockFuncObject.isRecognized).thenReturn(false);
    when(mockFuncObject.isNative).thenReturn(null);
    when(mockFuncObject.vmName).thenReturn('fooDartFunction');
    when(mockFuncObject.icDataArray).thenReturn(
      Instance(
        id: 'ic-data-array-id',
        length: 0,
        elements: [],
      ),
    );
  });

  group('function display test', () {
    testWidgetsWithWindowSize(
      'basic layout',
      windowSize,
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            VmFuncDisplay(
              function: mockFuncObject,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );

        expect(find.byType(VmObjectDisplayBasicLayout), findsOneWidget);
        expect(find.byType(VMInfoCard), findsNWidgets(2));
        expect(find.text('General Information'), findsOneWidget);
        expect(find.text('Function'), findsOneWidget);
        expect(find.text('256 B'), findsOneWidget);
        expect(find.text('Owner:'), findsOneWidget);
        expect(find.text('fooLib', findRichText: true), findsOneWidget);
        expect(
          find.text('fooScript.dart:10:4', findRichText: true),
          findsOneWidget,
        );

        expect(find.text('Function Details'), findsOneWidget);
        expect(find.text('Kind:'), findsOneWidget);
        expect(
          find.text('static const implicit closure function'),
          findsOneWidget,
        );
        expect(find.text('Deoptimizations:'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Optimizable:'), findsOneWidget);
        expect(find.text('Inlinable:'), findsOneWidget);
        expect(find.text('Intrinsic:'), findsOneWidget);
        expect(find.text('Recognized:'), findsOneWidget);
        expect(find.text('Native:'), findsOneWidget);
        expect(find.text('Yes'), findsNWidgets(2));
        expect(find.text('No'), findsNWidgets(2));
        expect(find.text('--'), findsOneWidget);
        expect(find.text('VM Name:'), findsOneWidget);
        expect(find.text('fooDartFunction'), findsOneWidget);

        expect(find.byType(RequestableSizeWidget), findsNWidgets(2));
        expect(find.byType(RetainingPathWidget), findsOneWidget);
        expect(find.byType(InboundReferencesTree), findsOneWidget);
        expect(find.byType(CallSiteDataArrayWidget), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'unrecognized function kind',
      windowSize,
      (WidgetTester tester) async {
        when(mockFuncObject.kind).thenReturn(null);

        await tester.pumpWidget(
          wrap(
            VmFuncDisplay(
              function: mockFuncObject,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );

        expect(find.text('Unrecognized function kind: null'), findsOneWidget);
      },
    );
  });
}
