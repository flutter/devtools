// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_field_display.dart';
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
  late MockFieldObject mockFieldObject;

  const windowSize = Size(4000.0, 4000.0);

  late Field testFieldCopy;

  late InstanceRef fieldStaticValue;

  setUp(() {
    setUpMockScriptManager();
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(NotificationService, NotificationService());

    mockFieldObject = MockFieldObject();

    final fieldJson = testField.toJson();
    testFieldCopy = Field.parse(fieldJson)!;

    final instanceJson = testInstance.toJson();
    fieldStaticValue = Instance.parse(instanceJson)!;

    fieldStaticValue.name = 'FooNumberType';
    fieldStaticValue.valueAsString = '100';

    testFieldCopy.size = 256;
    testFieldCopy.staticValue = fieldStaticValue;

    mockVmObject(mockFieldObject);
    when(mockFieldObject.obj).thenReturn(testFieldCopy);
    when(mockFieldObject.scriptRef).thenReturn(testScript);
  });

  group('field data display tests', () {
    testWidgetsWithWindowSize(
      'basic layout',
      windowSize,
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            VmFieldDisplay(
              field: mockFieldObject,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );

        expect(find.byType(VmObjectDisplayBasicLayout), findsOneWidget);
        expect(find.byType(VMInfoCard), findsOneWidget);
        expect(find.text('General Information'), findsOneWidget);
        expect(find.text('Field'), findsOneWidget);
        expect(find.text('256 B'), findsOneWidget);
        expect(find.text('Owner:'), findsOneWidget);
        expect(find.text('fooLib', findRichText: true), findsOneWidget);
        expect(
          find.text('fooScript.dart:10:4', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('Observed types not found'), findsOneWidget);
        expect(find.text('Static Value:'), findsOneWidget);
        expect(find.text('100', findRichText: true), findsOneWidget);

        expect(find.byType(RequestableSizeWidget), findsNWidgets(2));

        expect(find.byType(RetainingPathWidget), findsOneWidget);

        expect(find.byType(InboundReferencesTree), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'observed type single - nullable',
      windowSize,
      (WidgetTester tester) async {
        when(mockFieldObject.guardClass).thenReturn(testClass);
        when(mockFieldObject.guardNullable).thenReturn(true);
        when(mockFieldObject.guardClassKind).thenReturn(GuardClassKind.single);

        await tester.pumpWidget(
          wrap(
            VmFieldDisplay(
              field: mockFieldObject,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );
        expect(find.text('FooClass - null observed'), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'observed type dynamic - non-nullable',
      windowSize,
      (WidgetTester tester) async {
        when(mockFieldObject.guardClass).thenReturn(null);
        when(mockFieldObject.guardNullable).thenReturn(false);
        when(mockFieldObject.guardClassKind).thenReturn(GuardClassKind.dynamic);

        await tester.pumpWidget(
          wrap(
            VmFieldDisplay(
              field: mockFieldObject,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );
        expect(find.text('various - null not observed'), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'observed type unknown - null unknown',
      windowSize,
      (WidgetTester tester) async {
        when(mockFieldObject.guardClass).thenReturn(null);
        when(mockFieldObject.guardNullable).thenReturn(null);
        when(mockFieldObject.guardClassKind).thenReturn(GuardClassKind.unknown);

        await tester.pumpWidget(
          wrap(
            VmFieldDisplay(
              field: mockFieldObject,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );
        expect(
          find.text('none'),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'static value is not InstanceRef',
      windowSize,
      (WidgetTester tester) async {
        testFieldCopy.staticValue = testClass;

        await tester.pumpWidget(
          wrap(
            VmFieldDisplay(
              field: mockFieldObject,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );

        expect(find.text('Static Value:'), findsNothing);
      },
    );
  });
}
