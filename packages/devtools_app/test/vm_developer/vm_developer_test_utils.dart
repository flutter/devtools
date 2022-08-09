// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/screens/debugger/program_explorer_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector_view_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/object_viewport.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_object_model.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

final testLib = Library(
  name: 'fooLib',
  uri: 'fooLib.dart',
  dependencies: <LibraryDependency>[],
  id: '1234',
);

final testClass = Class(
  name: 'FooClass',
  library: testLib,
  isAbstract: false,
  isConst: false,
  traceAllocations: false,
  superClass: testSuperClass,
  superType: testSuperType,
  id: '1234',
);

final testScript = Script(uri: 'fooScript.dart', library: testLib, id: '1234');

final testFunction = Func(
  name: 'fooFunction',
  owner: testLib,
  isStatic: false,
  isConst: false,
  implicit: false,
  id: '1234',
);

final testField = Field(
  name: 'fooField',
  owner: testLib,
  id: '1234',
);

final testInstance = Instance(
  id: '1234',
  name: 'fooInstance',
);

final testSuperClass =
    ClassRef(name: 'fooSuperClass', library: testLib, id: '1234');

final testSuperType = InstanceRef(
  kind: '',
  id: '1234',
  name: 'fooSuperType',
);

const testPos = SourcePosition(line: 10, column: 4);

final testInstances = InstanceSet(totalCount: 3);

final testRequestableSize = InstanceRef(
  kind: '',
  id: '1234',
  name: 'requestedSize',
  valueAsString: '128',
);

final testParentField = Field(
  name: 'fooParentField',
  id: '1234',
);

final testRetainingPath = RetainingPath(
  length: 1,
  gcRootType: 'class table',
  elements: testRetainingObjects,
);

final testRetainingObjects = [
  RetainingObject(
    value: testClass,
  ),
  RetainingObject(
    value: testInstance,
    parentListIndex: 1,
    parentField: 'fooParentField',
  ),
  RetainingObject(
    value: testInstance,
    parentMapKey: testField,
    parentField: 'fooParentField',
  ),
  RetainingObject(
    value: testField,
    parentField: 'fooParentField',
  ),
];

final testInboundRefs = TestInboundReferences(
  references: testInboundRefList,
);

final testInboundRefList = [
  InboundReference(
    source: testFunction,
  ),
  InboundReference(
    source: testField,
    parentField: testParentField,
  ),
  InboundReference(
    source: testInstance,
    parentListIndex: 1,
    parentField: testParentField,
  ),
];

class TestInboundReferences extends InboundReferences {
  TestInboundReferences({required super.references});

  @override
  Map<String, dynamic>? get json => <String, dynamic>{};
}

class TestProgramExplorerController extends ProgramExplorerController {}

class TestObjectInspectorViewController extends ObjectInspectorViewController {
  @override
  ObjectHistory get objectHistory => fakeObjectHistory;

  @override
  ProgramExplorerController get programExplorerController =>
      mockProgramExplorerController;

  final fakeObjectHistory = FakeObjectHistory();

  final mockProgramExplorerController =
      createMockProgramExplorerControllerWithDefaults();
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

class TestFieldObject extends FieldObject {
  TestFieldObject({required super.ref, required this.testField});

  Field testField;

  @override
  Field get obj => testField;

  @override
  String? get name => 'FooField';
}

class TestLibraryObject extends LibraryObject {
  TestLibraryObject({required super.ref, required this.testLibrary});

  Library testLibrary;

  @override
  Library get obj => testLibrary;

  @override
  String? get name => 'FooLib';
}

class TestInstanceObject extends InstanceObject {
  TestInstanceObject({required super.ref, required this.testInstance});

  Instance testInstance;

  @override
  Instance get obj => testInstance;

  @override
  String? get name => 'FooInstance';
}

void mockVmObject(VmObject object) {
  when(object.outlineNode).thenReturn(null);
  when(object.scriptRef).thenReturn(null);
  when(object.script).thenReturn(testScript);
  when(object.pos).thenReturn(testPos);
  when(object.fetchingReachableSize).thenReturn(ValueNotifier<bool>(false));
  when(object.reachableSize).thenReturn(testRequestableSize);
  when(object.fetchingRetainedSize).thenReturn(ValueNotifier<bool>(false));
  when(object.retainedSize).thenReturn(null);
  when(object.retainingPath).thenReturn(
    ValueNotifier<RetainingPath?>(testRetainingPath),
  );
  when(object.inboundReferences).thenReturn(
    ValueNotifier<InboundReferences?>(testInboundRefs),
  );
}
