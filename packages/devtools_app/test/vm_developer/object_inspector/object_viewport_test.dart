// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/vm_developer/object_viewport.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_class_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_field_display.dart';
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

  late MockClassObject mockClassObject;

  late MockFieldObject mockFieldObject;

  late FakeServiceManager fakeServiceManager;

  late MockScriptManager scriptManager;

  const windowSize = Size(4000.0, 4000.0);

  setUp(() {
    fakeServiceManager = FakeServiceManager();

    scriptManager = MockScriptManager();
    when(scriptManager.sortedScripts).thenReturn(ValueNotifier(<ScriptRef>[]));

    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(ScriptManager, scriptManager);
    setGlobal(IdeTheme, IdeTheme());

    testObjectInspectorViewController = TestObjectInspectorViewController();

    mockClassObject = MockClassObject();

    when(mockClassObject.outlineNode).thenReturn(null);
    when(mockClassObject.scriptRef).thenReturn(null);
    when(mockClassObject.name).thenReturn('FooClass');
    when(mockClassObject.ref).thenReturn(testClass);
    when(mockClassObject.obj).thenReturn(testClass);
    when(mockClassObject.script).thenReturn(null);
    when(mockClassObject.instances).thenReturn(null);
    when(mockClassObject.pos).thenReturn(null);
    when(mockClassObject.fetchingReachableSize)
        .thenReturn(ValueNotifier<bool>(false));
    when(mockClassObject.reachableSize).thenReturn(null);
    when(mockClassObject.fetchingRetainedSize)
        .thenReturn(ValueNotifier<bool>(false));
    when(mockClassObject.retainedSize).thenReturn(null);
    when(mockClassObject.retainingPath)
        .thenReturn(ValueNotifier<RetainingPath?>(null));
    when(mockClassObject.inboundReferences)
        .thenReturn(ValueNotifier<InboundReferences?>(null));

    mockFieldObject = MockFieldObject();

    when(mockFieldObject.outlineNode).thenReturn(null);
    when(mockFieldObject.scriptRef).thenReturn(null);
    when(mockFieldObject.name).thenReturn(testField.name);
    when(mockFieldObject.ref).thenReturn(testField);
    when(mockFieldObject.obj).thenReturn(testField);
    when(mockFieldObject.script).thenReturn(null);
    when(mockFieldObject.pos).thenReturn(null);
    when(mockFieldObject.guardClass).thenReturn(null);
    when(mockFieldObject.guardNullable).thenReturn(null);
    when(mockFieldObject.guardClassKind).thenReturn(null);
    when(mockFieldObject.fetchingReachableSize)
        .thenReturn(ValueNotifier<bool>(false));
    when(mockFieldObject.reachableSize).thenReturn(null);
    when(mockFieldObject.fetchingRetainedSize)
        .thenReturn(ValueNotifier<bool>(false));
    when(mockFieldObject.retainedSize).thenReturn(null);
    when(mockFieldObject.retainingPath)
        .thenReturn(ValueNotifier<RetainingPath?>(null));
    when(mockFieldObject.inboundReferences)
        .thenReturn(ValueNotifier<InboundReferences?>(null));
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

  testWidgetsWithWindowSize('test for class Object', windowSize,
      (WidgetTester tester) async {
    testObjectInspectorViewController.fakeObjectHistory
        .setCurrentObject(mockClassObject);
    await tester.pumpWidget(
      wrap(ObjectViewport(controller: testObjectInspectorViewController)),
    );
    expect(viewportTitle(mockClassObject), 'Class FooClass');
    expect(find.text('Class FooClass'), findsOneWidget);
    expect(find.byType(VmClassDisplay), findsOneWidget);
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

  testWidgets('test for Field Object', (WidgetTester tester) async {
    testObjectInspectorViewController.fakeObjectHistory
        .setCurrentObject(mockFieldObject);

    await tester.pumpWidget(
      wrap(ObjectViewport(controller: testObjectInspectorViewController)),
    );

    expect(viewportTitle(mockFieldObject), 'Field fooField');
    expect(find.text('Field fooField'), findsOneWidget);
    expect(find.byType(VmFieldDisplay), findsOneWidget);
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

  testWidgets('test for Instance Object', (WidgetTester tester) async {
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

  testWidgets('test for Func Object', (WidgetTester tester) async {
    final testFuncObject =
        TestFuncObject(ref: testFunction, testFunc: testFunction);
    testObjectInspectorViewController.fakeObjectHistory
        .setCurrentObject(testFuncObject);
    await tester.pumpWidget(
      wrap(ObjectViewport(controller: testObjectInspectorViewController)),
    );
    expect(viewportTitle(testFuncObject), 'Function FooFunction');
    expect(find.text('Function FooFunction'), findsOneWidget);
    expect(find.byType(VMInfoCard), findsOneWidget);
  });

  group('ObjectHistory', () {
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
