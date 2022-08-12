// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/vm_developer/object_viewport.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_class_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_field_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_function_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_object_model.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_script_display.dart';
import 'package:devtools_app/src/scripts/script_manager.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/history_viewport.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' hide Stack;
import '../vm_developer_test_utils.dart';

void main() {
  late TestObjectInspectorViewController testObjectInspectorViewController;

  late FakeServiceManager fakeServiceManager;

  late MockScriptManager scriptManager;

  setUp(() {
    fakeServiceManager = FakeServiceManager();

    scriptManager = MockScriptManager();
    when(scriptManager.sortedScripts).thenReturn(ValueNotifier(<ScriptRef>[]));

    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(ScriptManager, scriptManager);
    setGlobal(IdeTheme, IdeTheme());

    testObjectInspectorViewController = TestObjectInspectorViewController();
  });

  testWidgets('builds object viewport', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(ObjectViewport(controller: testObjectInspectorViewController)),
    );
    expect(viewportTitle(null), 'No object selected.');
    expect(find.text('No object selected.'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(find.byType(HistoryViewport<VmObject>), findsOneWidget);
  });

  group('test for class object:', () {
    late MockClassObject mockClassObject;

    setUp(() {
      mockClassObject = MockClassObject();

      mockVmObject(mockClassObject);
    });

    testWidgets('viewport shows class display', (WidgetTester tester) async {
      testObjectInspectorViewController.fakeObjectHistory
          .setCurrentObject(mockClassObject);
      await tester.pumpWidget(
        wrap(ObjectViewport(controller: testObjectInspectorViewController)),
      );
      expect(viewportTitle(mockClassObject), 'Class FooClass');
      expect(find.text('Class FooClass'), findsOneWidget);
      expect(find.byType(VmClassDisplay), findsOneWidget);
    });
  });

  group('test for field object:', () {
    late MockFieldObject mockFieldObject;

    setUp(() {
      mockFieldObject = MockFieldObject();

      mockVmObject(mockFieldObject);
    });

    testWidgets('viewport shows field display', (WidgetTester tester) async {
      testObjectInspectorViewController.fakeObjectHistory
          .setCurrentObject(mockFieldObject);

      await tester.pumpWidget(
        wrap(ObjectViewport(controller: testObjectInspectorViewController)),
      );

      expect(viewportTitle(mockFieldObject), 'Field fooField');
      expect(find.text('Field fooField'), findsOneWidget);
      expect(find.byType(VmFieldDisplay), findsOneWidget);
    });
  });

  group('test for function object:', () {
    late MockFuncObject mockFuncObject;

    late Func testFunctionCopy;

    setUp(() {
      mockFuncObject = MockFuncObject();

      final funcJson = testFunction.toJson();
      testFunctionCopy = Func.parse(funcJson)!;

      mockVmObject(mockFuncObject);
      when(mockFuncObject.obj).thenReturn(testFunctionCopy);
    });
    testWidgets('viewport shows function display', (WidgetTester tester) async {
      testObjectInspectorViewController.fakeObjectHistory
          .setCurrentObject(mockFuncObject);

      await tester.pumpWidget(
        wrap(ObjectViewport(controller: testObjectInspectorViewController)),
      );

      expect(viewportTitle(mockFuncObject), 'Function fooFunction');
      expect(find.text('Function fooFunction'), findsOneWidget);
      expect(find.byType(VmFuncDisplay), findsOneWidget);
    });
  });

  group('test for script object:', () {
    late MockScriptObject mockScriptObject;

    setUp(() {
      mockScriptObject = MockScriptObject();

      mockVmObject(mockScriptObject);
    });

    testWidgets('viewport shows script display', (WidgetTester tester) async {
      testObjectInspectorViewController.fakeObjectHistory
          .setCurrentObject(mockScriptObject);
      await tester.pumpWidget(
        wrap(ObjectViewport(controller: testObjectInspectorViewController)),
      );
      expect(viewportTitle(mockScriptObject), 'Script fooScript.dart');
      expect(find.text('Script fooScript.dart'), findsOneWidget);
      expect(find.byType(VmScriptDisplay), findsOneWidget);
    });
  });

  testWidgets('test for Library Object', (WidgetTester tester) async {
    final testLibraryObject =
        TestLibraryObject(ref: testLib, testLibrary: testLib);
    testObjectInspectorViewController.fakeObjectHistory
        .setCurrentObject(testLibraryObject);
    await tester.pumpWidget(
      wrap(ObjectViewport(controller: testObjectInspectorViewController)),
    );
    expect(viewportTitle(testLibraryObject), 'Library FooLib');
    expect(find.text('Library FooLib'), findsOneWidget);
    expect(find.byType(VMInfoCard), findsOneWidget);
  });

  group('test for instance object:', () {
    testWidgets('builds display for Instance Object',
        (WidgetTester tester) async {
      final testInstanceObject =
          TestInstanceObject(ref: testInstance, testInstance: testInstance);
      testObjectInspectorViewController.fakeObjectHistory
          .setCurrentObject(testInstanceObject);
      await tester.pumpWidget(
        wrap(ObjectViewport(controller: testObjectInspectorViewController)),
      );
      expect(viewportTitle(testInstanceObject), 'Instance FooInstance');
      expect(find.text('Instance FooInstance'), findsOneWidget);
      expect(find.byType(VMInfoCard), findsOneWidget);
    });
  });

  group('test ObjectHistory', () {
    late ObjectHistory history;

    late MockClassObject obj1;
    late MockClassObject obj2;
    late MockClassObject obj3;

    setUp(() {
      history = ObjectHistory();

      obj1 = MockClassObject();
      obj2 = MockClassObject();
      obj3 = MockClassObject();
    });

    test('initial values', () {
      expect(history.hasNext, false);
      expect(history.hasPrevious, false);
      expect(history.current.value, isNull);
    });

    test('push entries', () {
      history.pushEntry(obj1);

      expect(history.hasNext, false);
      expect(history.hasPrevious, false);
      expect(history.current.value, obj1);

      history.pushEntry(obj2);
      expect(history.hasNext, false);
      expect(history.hasPrevious, true);
      expect(history.current.value, obj2);
    });

    test('push same as current', () {
      history.pushEntry(obj1);
      history.pushEntry(obj1);

      expect(history.hasNext, false);
      expect(history.hasPrevious, false);
      expect(history.current.value, obj1);

      history.pushEntry(obj2);
      history.pushEntry(obj2);

      expect(history.hasNext, false);
      expect(history.hasPrevious, true);
      expect(history.current.value, obj2);

      history.moveBack();

      expect(history.hasNext, isTrue);
      expect(history.hasPrevious, false);
      expect(history.current.value, obj1);
    });

    test('pushEntry removes next entries', () {
      history.pushEntry(obj1);
      history.pushEntry(obj2);

      expect(history.current.value, obj2);
      expect(history.hasNext, isFalse);

      history.moveBack();

      expect(history.current.value, obj1);
      expect(history.hasNext, isTrue);

      history.pushEntry(obj3);

      expect(history.current.value, obj3);
      expect(history.hasNext, isFalse);

      history.moveBack();

      expect(history.current.value, obj1);
      expect(history.hasNext, isTrue);
    });
  });
}
