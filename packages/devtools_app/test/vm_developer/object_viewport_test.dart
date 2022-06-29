// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector_view_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/object_viewport.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_class_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app/src/shared/history_viewport.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

void main() {
  late TestObjectInspectorViewController testObjectInspectorViewController;

  final mockClassObject = MockClassObject();
  final mockClass = MockClass();

  final fakelib = LibraryRef(name: 'FooLib', uri: 'fooLib.dart', id: '1234');

  final fakeClassRef = ClassRef(name: 'FooClass', library: fakelib, id: '1234');
  final fakeSuperClass =
      ClassRef(name: 'FooSuperClass', library: fakelib, id: '1234');
  final fakeSuperType = InstanceRef(
    kind: '',
    identityHashCode: null,
    classRef: null,
    id: '1234',
    name: 'FooSuperType',
  );
  final fakeScript = Script(uri: 'FooClass.dart', library: fakelib, id: '1234');
  const fakePos = SourcePosition(line: 10, column: 4);
  final fakeInstances = InstanceSet(instances: null, totalCount: 3);

  when(mockClassObject.name).thenReturn('FooClass');
  when(mockClassObject.ref).thenReturn(fakeClassRef);
  when(mockClassObject.obj).thenReturn(mockClass);
  when(mockClassObject.script).thenReturn(fakeScript);
  when(mockClassObject.instances).thenReturn(fakeInstances);
  when(mockClassObject.pos).thenReturn(fakePos);

  when(mockClass.type).thenReturn('Class');
  when(mockClass.size).thenReturn(1024);
  when(mockClass.library).thenReturn(fakelib);
  when(mockClass.superType).thenReturn(fakeSuperType);
  when(mockClass.superClass).thenReturn(fakeSuperClass);

  const windowSize = Size(4000.0, 4000.0);
  const smallWindowSize = Size(1100.0, 1100.0);

  setUp(() {
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
    expect(find.bySubtype<HistoryViewport<VmObject>>(), findsOneWidget);
  });

  testWidgets('test for class Object', (WidgetTester tester) async {
    testObjectInspectorViewController.fakeObjectHistory
        .setCurrentObject(mockClassObject);
    await tester.pumpWidget(
      wrap(ObjectViewport(controller: testObjectInspectorViewController)),
    );
    expect(viewportTitle(mockClassObject), 'Class FooClass');
    expect(find.text('Class FooClass'), findsOneWidget);
    expect(find.bySubtype<VmClassDisplay>(), findsOneWidget);
  });

  testWidgets('test for scriptObject', (WidgetTester tester) async {
    final fakeScript = Script(uri: 'foo.dart', library: fakelib, id: '1234');
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
    expect(find.bySubtype<VMInfoCard>(), findsOneWidget);
  });

  testWidgets('test for other vm Objects', (WidgetTester tester) async {
    final fakeFunction = Func(
      name: 'FooFunction',
      owner: fakelib,
      isStatic: false,
      isConst: false,
      implicit: false,
      signature: null,
      id: '1234',
    );
    final fakeFunctionRef = FuncRef(
      name: 'FooFunction',
      owner: fakelib,
      isStatic: false,
      isConst: false,
      implicit: false,
      id: '1234',
    );
    final testFuncObject =
        TestFuncObject(ref: fakeFunctionRef, testFunc: fakeFunction);
    testObjectInspectorViewController.fakeObjectHistory
        .setCurrentObject(testFuncObject);
    await tester.pumpWidget(
      wrap(ObjectViewport(controller: testObjectInspectorViewController)),
    );
    expect(viewportTitle(testFuncObject), 'Function FooFunction');
    expect(find.text('Function FooFunction'), findsOneWidget);
    expect(find.bySubtype<VMInfoCard>(), findsOneWidget);
  });

  group('ScriptsHistory', () {
    //TODO
  });
}

class TestObjectInspectorViewController extends ObjectInspectorViewController {
  @override
  ObjectHistory get objectHistory => fakeObjectHistory;

  final fakeObjectHistory = FakeObjectHistory();
}

class FakeObjectHistory extends ObjectHistory {
  VmObject? _current;

  @override
  ValueListenable<VmObject?> get current => ValueNotifier<VmObject?>(_current);

  void setCurrentObject(VmObject object) {
    _current = object;
  }
}

class TestScriptObject extends ScriptObject {
  TestScriptObject({required super.ref, required this.testScript});

  Script testScript;

  @override
  Script get obj => testScript;
}

class TestFuncObject extends FuncObject {
  TestFuncObject({required super.ref, required this.testFunc});

  Func testFunc;

  @override
  Func get obj => testFunc;

  @override
  String? get name => 'FooFunction';
}
