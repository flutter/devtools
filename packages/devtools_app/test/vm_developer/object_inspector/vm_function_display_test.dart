// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_function_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_service_private_extensions.dart';
import 'package:devtools_app/src/shared/globals.dart';
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
    setGlobal(IdeTheme, IdeTheme());

    mockFuncObject = MockFuncObject();

    final funcJson = testFunction.toJson();
    testFunctionCopy = Func.parse(funcJson)!;

    testFunctionCopy.size = 256;
    testFunctionCopy.isStatic = true;
    testFunctionCopy.isConst = true;

    mockVmObject(mockFuncObject);
    when(mockFuncObject.name).thenReturn(testFunctionCopy.name);
    when(mockFuncObject.ref).thenReturn(testFunctionCopy);
    when(mockFuncObject.obj).thenReturn(testFunctionCopy);
    when(mockFuncObject.kind).thenReturn(FunctionKind.ImplicitClosureFunction);
    when(mockFuncObject.deoptimizations).thenReturn(3);
    when(mockFuncObject.isOptimizable).thenReturn(true);
    when(mockFuncObject.isInlinable).thenReturn(true);
    when(mockFuncObject.hasIntrinsic).thenReturn(false);
    when(mockFuncObject.isRecognized).thenReturn(false);
    when(mockFuncObject.isNative).thenReturn(null);
    when(mockFuncObject.vmName).thenReturn('DartVM');
    when(mockFuncObject.icDataArray).thenReturn(null);
  });

  group('function display test', () {
    testWidgetsWithWindowSize('basic layout', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(VmFuncDisplay(function: mockFuncObject)));

      expect(find.byType(VmObjectDisplayBasicLayout), findsOneWidget);
      expect(find.byType(VMInfoCard), findsNWidgets(2));
      expect(find.text('General Information'), findsOneWidget);
      expect(find.text('Function'), findsOneWidget);
      expect(find.text('256 B'), findsOneWidget);
      expect(find.text('Owner:'), findsOneWidget);
      expect(find.text('fooLib'), findsOneWidget);
      expect(find.text('fooScript.dart:10:4'), findsOneWidget);

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
      expect(find.text('DartVM'), findsOneWidget);

      expect(find.byType(RequestableSizeWidget), findsNWidgets(2));

      expect(find.byType(RetainingPathWidget), findsOneWidget);

      expect(find.byType(InboundReferencesWidget), findsOneWidget);
    });

    testWidgetsWithWindowSize('unrecognized function kind', windowSize,
        (WidgetTester tester) async {
      when(mockFuncObject.kind).thenReturn(null);

      await tester.pumpWidget(wrap(VmFuncDisplay(function: mockFuncObject)));

      expect(find.text('Unrecognized function kind: null'), findsOneWidget);
    });
  });
}
