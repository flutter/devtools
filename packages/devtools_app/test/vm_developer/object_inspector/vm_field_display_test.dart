// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_field_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_service_private_extensions.dart';
import 'package:devtools_app/src/shared/globals.dart';
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
    setGlobal(IdeTheme, IdeTheme());

    mockFieldObject = MockFieldObject();

    final fieldJson = testField.toJson();
    testFieldCopy = Field.parse(fieldJson)!;

    final instanceJson = testInstance.toJson();
    fieldStaticValue = Instance.parse(instanceJson)!;

    fieldStaticValue.name = 'FooNumberType';
    fieldStaticValue.valueAsString = '100';

    testFieldCopy.size = 256;
    testFieldCopy.staticValue = fieldStaticValue;

    when(mockFieldObject.outlineNode).thenReturn(null);
    when(mockFieldObject.scriptRef).thenReturn(null);
    when(mockFieldObject.name).thenReturn(testFieldCopy.name);
    when(mockFieldObject.ref).thenReturn(testFieldCopy);
    when(mockFieldObject.obj).thenReturn(testFieldCopy);
    when(mockFieldObject.script).thenReturn(testScript);
    when(mockFieldObject.pos).thenReturn(testPos);

    when(mockFieldObject.guardClass).thenReturn(null);
    when(mockFieldObject.guardNullable).thenReturn(null);
    when(mockFieldObject.guardClassKind).thenReturn(null);

    when(mockFieldObject.fetchingReachableSize)
        .thenReturn(ValueNotifier<bool>(false));
    when(mockFieldObject.reachableSize).thenReturn(testRequestableSize);
    when(mockFieldObject.fetchingRetainedSize)
        .thenReturn(ValueNotifier<bool>(false));
    when(mockFieldObject.retainedSize).thenReturn(testRequestableSize);
    when(mockFieldObject.retainingPath).thenReturn(
      ValueNotifier<RetainingPath?>(testRetainingPath),
    );
    when(mockFieldObject.inboundReferences).thenReturn(
      ValueNotifier<InboundReferences?>(testInboundRefs),
    );
  });

  group('field data display tests', () {
    testWidgetsWithWindowSize('basic layout', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(VmFieldDisplay(field: mockFieldObject)));

      expect(find.byType(VmObjectDisplayBasicLayout), findsOneWidget);
      expect(find.text('General Information'), findsOneWidget);
      expect(find.text('Field'), findsOneWidget);
      expect(find.text('256 B'), findsOneWidget);
      expect(find.text('Owner:'), findsOneWidget);
      expect(find.text('fooLib'), findsOneWidget);
      expect(find.text('fooScript.dart:10:4'), findsOneWidget);
      expect(find.text('Observed types not found'), findsOneWidget);
      expect(find.text('Static Value:'), findsOneWidget);
      expect(find.text('FooNumberType: 100'), findsOneWidget);

      expect(find.byType(RequestableSizeWidget), findsNWidgets(2));

      expect(find.byType(RetainingPathWidget), findsOneWidget);

      expect(find.byType(InboundReferencesWidget), findsOneWidget);
    });

    testWidgetsWithWindowSize('observed type single - nullable', windowSize,
        (WidgetTester tester) async {
      when(mockFieldObject.guardClass).thenReturn(testClass);
      when(mockFieldObject.guardNullable).thenReturn(true);
      when(mockFieldObject.guardClassKind)
          .thenReturn(FieldPrivateViewExtension.guardClassSingle);

      await tester.pumpWidget(wrap(VmFieldDisplay(field: mockFieldObject)));
      expect(find.text('FooClass - null observed'), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'observed type dynamic - non-nullable', windowSize,
        (WidgetTester tester) async {
      when(mockFieldObject.guardClass).thenReturn(null);
      when(mockFieldObject.guardNullable).thenReturn(false);
      when(mockFieldObject.guardClassKind)
          .thenReturn(FieldPrivateViewExtension.guardClassDynamic);

      await tester.pumpWidget(wrap(VmFieldDisplay(field: mockFieldObject)));
      expect(find.text('various - null not observed'), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'observed type unknown - null unknown', windowSize,
        (WidgetTester tester) async {
      when(mockFieldObject.guardClass).thenReturn(null);
      when(mockFieldObject.guardNullable).thenReturn(null);
      when(mockFieldObject.guardClassKind)
          .thenReturn(FieldPrivateViewExtension.guardClassUnknown);

      await tester.pumpWidget(wrap(VmFieldDisplay(field: mockFieldObject)));
      expect(
        find.text('none'),
        findsOneWidget,
      );
    });

    testWidgetsWithWindowSize('static value is not InstanceRef', windowSize,
        (WidgetTester tester) async {
      testFieldCopy.staticValue = testClass;

      await tester.pumpWidget(wrap(VmFieldDisplay(field: mockFieldObject)));

      expect(find.text('Static Value:'), findsNothing);
    });
  });
}
