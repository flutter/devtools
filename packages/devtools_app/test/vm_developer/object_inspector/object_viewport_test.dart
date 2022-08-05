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

  late MockFuncObject mockFuncObject;

  late Func testFunctionCopy;

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

    // MockClassObject setUp

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

    // MockFieldObject setUp

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

    // MockFuncObject setUp

    mockFuncObject = MockFuncObject();

    final funcJson = testFunction.toJson();
    testFunctionCopy = Func.parse(funcJson)!;

    when(mockFuncObject.outlineNode).thenReturn(null);
    when(mockFuncObject.scriptRef).thenReturn(null);
    when(mockFuncObject.name).thenReturn(testFunctionCopy.name);
    when(mockFuncObject.ref).thenReturn(testFunctionCopy);
    when(mockFuncObject.obj).thenReturn(testFunctionCopy);
    when(mockFuncObject.script).thenReturn(null);
    when(mockFuncObject.pos).thenReturn(null);
    when(mockFuncObject.kind).thenReturn(null);
    when(mockFuncObject.deoptimizations).thenReturn(null);
    when(mockFuncObject.isOptimizable).thenReturn(null);
    when(mockFuncObject.isInlinable).thenReturn(null);
    when(mockFuncObject.hasIntrinsic).thenReturn(null);
    when(mockFuncObject.isRecognized).thenReturn(null);
    when(mockFuncObject.isNative).thenReturn(null);
    when(mockFuncObject.vmName).thenReturn(null);
    when(mockFuncObject.icDataArray).thenReturn(null);
    when(mockFuncObject.fetchingReachableSize)
        .thenReturn(ValueNotifier<bool>(false));
    when(mockFuncObject.reachableSize).thenReturn(testRequestableSize);
    when(mockFuncObject.fetchingRetainedSize)
        .thenReturn(ValueNotifier<bool>(false));
    when(mockFuncObject.retainedSize).thenReturn(testRequestableSize);
    when(mockFuncObject.retainingPath).thenReturn(
      ValueNotifier<RetainingPath?>(testRetainingPath),
    );
    when(mockFuncObject.inboundReferences).thenReturn(
      ValueNotifier<InboundReferences?>(testInboundRefs),
    );
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

  testWidgets('test for scriptObject', (WidgetTester tester) async {
    final fakeScript = Script(uri: 'foo.dart', library: testLib, id: '1234');
    final fakeScriptRef = ScriptRef(uri: 'foo.dart', id: '1234');
    final testScriptObject =
        TestScriptObject(ref: fakeScriptRef, testScript: fakeScript);
    testObjectInspectorViewController.fakeObjectHistory
        .setCurrentObject(testScriptObject);
    await tester.pumpWidget(
      wrap(ObjectViewport(controller: testObjectInspectorViewController)),
    );
    expect(viewportTitle(testScriptObject), 'Script @ foo.dart');
    expect(find.text('Script @ foo.dart'), findsOneWidget);
    expect(find.byType(VMInfoCard), findsOneWidget);
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
    testObjectInspectorViewController.fakeObjectHistory
        .setCurrentObject(mockFuncObject);

    await tester.pumpWidget(
      wrap(ObjectViewport(controller: testObjectInspectorViewController)),
    );

    expect(viewportTitle(mockFuncObject), 'Function fooFunction');
    expect(find.text('Function fooFunction'), findsOneWidget);
    expect(find.byType(VmFuncDisplay), findsOneWidget);
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
