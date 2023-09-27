// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/object_viewport.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_class_display.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_field_display.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_function_display.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_instance_display.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_library_display.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_script_display.dart';
import 'package:devtools_app/src/shared/history_viewport.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../vm_developer_test_utils.dart';

void main() {
  late TestObjectInspectorViewController testObjectInspectorViewController;

  late FakeServiceConnectionManager fakeServiceConnection;

  const windowSize = Size(2560.0, 1338.0);

  setUp(() {
    fakeServiceConnection = FakeServiceConnectionManager();

    setUpMockScriptManager();
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(NotificationService, NotificationService());

    testObjectInspectorViewController = TestObjectInspectorViewController();
  });

  testWidgets('builds object viewport', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(ObjectViewport(controller: testObjectInspectorViewController)),
    );
    expect(ObjectViewport.viewportTitle(null), 'No object selected.');
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

    testWidgetsWithWindowSize(
      'viewport shows class display',
      windowSize,
      (WidgetTester tester) async {
        testObjectInspectorViewController.fakeObjectHistory
            .setCurrentObject(mockClassObject);
        await tester.pumpWidget(
          wrap(ObjectViewport(controller: testObjectInspectorViewController)),
        );
        expect(ObjectViewport.viewportTitle(mockClassObject), 'Class FooClass');
        expect(find.text('Class FooClass'), findsOneWidget);
        expect(find.byType(VmClassDisplay), findsOneWidget);
      },
    );
  });

  group('test for field object:', () {
    late MockFieldObject mockFieldObject;

    setUp(() {
      mockFieldObject = MockFieldObject();

      mockVmObject(mockFieldObject);
    });

    testWidgetsWithWindowSize(
      'viewport shows field display',
      windowSize,
      (WidgetTester tester) async {
        testObjectInspectorViewController.fakeObjectHistory
            .setCurrentObject(mockFieldObject);

        await tester.pumpWidget(
          wrap(ObjectViewport(controller: testObjectInspectorViewController)),
        );

        expect(ObjectViewport.viewportTitle(mockFieldObject), 'Field fooField');
        expect(find.text('Field fooField'), findsOneWidget);
        expect(find.byType(VmFieldDisplay), findsOneWidget);
      },
    );
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
    testWidgetsWithWindowSize(
      'viewport shows function display',
      windowSize,
      (WidgetTester tester) async {
        testObjectInspectorViewController.fakeObjectHistory
            .setCurrentObject(mockFuncObject);

        await tester.pumpWidget(
          wrap(ObjectViewport(controller: testObjectInspectorViewController)),
        );

        expect(
          ObjectViewport.viewportTitle(mockFuncObject),
          'Function fooFunction',
        );
        expect(find.text('Function fooFunction'), findsOneWidget);
        expect(find.byType(VmFuncDisplay), findsOneWidget);
      },
    );
  });

  group('test for script object:', () {
    late MockScriptObject mockScriptObject;

    setUp(() {
      mockScriptObject = MockScriptObject();

      mockVmObject(mockScriptObject);
    });

    testWidgetsWithWindowSize(
      'viewport shows script display',
      windowSize,
      (WidgetTester tester) async {
        testObjectInspectorViewController.fakeObjectHistory
            .setCurrentObject(mockScriptObject);
        await tester.pumpWidget(
          wrap(ObjectViewport(controller: testObjectInspectorViewController)),
        );
        expect(
          ObjectViewport.viewportTitle(mockScriptObject),
          'Script fooScript.dart',
        );
        expect(find.text('Script fooScript.dart'), findsOneWidget);
        expect(find.byType(VmScriptDisplay), findsOneWidget);
      },
    );
  });

  group('test for library object:', () {
    late MockLibraryObject mockLibraryObject;

    setUp(() {
      mockLibraryObject = MockLibraryObject();

      mockVmObject(mockLibraryObject);
    });

    testWidgets('viewport shows library display', (WidgetTester tester) async {
      testObjectInspectorViewController.fakeObjectHistory
          .setCurrentObject(mockLibraryObject);
      await tester.pumpWidget(
        wrap(ObjectViewport(controller: testObjectInspectorViewController)),
      );
      expect(ObjectViewport.viewportTitle(mockLibraryObject), 'Library fooLib');
      expect(find.text('Library fooLib'), findsOneWidget);
      expect(find.byType(VmLibraryDisplay), findsOneWidget);
    });
  });

  group('test for instance object:', () {
    testWidgets(
      'builds display for Instance Object',
      (WidgetTester tester) async {
        final testInstanceObject =
            TestInstanceObject(ref: testInstance, testInstance: testInstance);
        testObjectInspectorViewController.fakeObjectHistory
            .setCurrentObject(testInstanceObject);
        await tester.pumpWidget(
          wrap(ObjectViewport(controller: testObjectInspectorViewController)),
        );
        expect(
          ObjectViewport.viewportTitle(testInstanceObject),
          'Instance of fooSuperClass',
        );
        expect(find.text('Instance of fooSuperClass'), findsOneWidget);
        expect(find.byType(VmInstanceDisplay), findsOneWidget);
      },
    );
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

      when(obj1.obj).thenReturn(Class(id: '1'));
      when(obj2.obj).thenReturn(Class(id: '2'));
      when(obj3.obj).thenReturn(Class(id: '3'));
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
