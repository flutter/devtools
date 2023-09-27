// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/debugger/program_explorer_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/inbound_references_tree.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/object_inspector_view_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/object_viewport.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_object_model.dart';
import 'package:devtools_app/src/shared/diagnostics/primitives/source_location.dart';
import 'package:devtools_app/src/shared/primitives/listenable.dart';
import 'package:devtools_app/src/shared/primitives/utils.dart';
import 'package:devtools_app/src/shared/scripts/script_manager.dart';
import 'package:devtools_app_shared/utils.dart';
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
  declaredType: testType,
  id: '1234',
);

final testInstance = Instance(
  id: '1234',
  name: 'fooInstance',
  classRef: testSuperClass,
);

final testRecordInstance = Instance(
  id: '1234',
  kind: InstanceKind.kRecord,
  name: 'fooRecord',
);

final testSuperClass =
    ClassRef(name: 'fooSuperClass', library: testLib, id: '1234');

final testType = InstanceRef(
  kind: '',
  id: '1234',
  name: 'fooType',
  classRef: testClass,
);

final testSuperType = InstanceRef(
  kind: '',
  id: '1234',
  name: 'fooSuperType',
  classRef: testSuperClass,
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
  ),
  RetainingObject(
    value: testRecordInstance,
    parentField: 1,
  ),
  RetainingObject(
    value: testRecordInstance,
    parentField: 'fooParentField',
  ),
  RetainingObject(
    value: testInstance,
    parentMapKey: testField,
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
    source: testRecordInstance,
    parentField: 'fooParentField',
  ),
  InboundReference(
    source: testRecordInstance,
    parentField: 1,
  ),
  InboundReference(
    source: testInstance,
    parentListIndex: 1,
  ),
];

final testLoadTime = DateTime(2022, 8, 10, 6, 30);

class TestInboundReferences extends InboundReferences {
  TestInboundReferences({required super.references});

  @override
  Map<String, Object?>? get json => <String, Object?>{};
}

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

class TestInstanceObject extends InstanceObject {
  TestInstanceObject({required super.ref, required this.testInstance});

  Instance testInstance;

  @override
  Instance get obj => testInstance;

  @override
  String? get name => 'FooInstance';
}

void setUpMockScriptManager() {
  final mockScriptManager = MockScriptManager();
  when(mockScriptManager.sortedScripts).thenReturn(
    FixedValueListenable<List<ScriptRef>>([testScript]),
  );
  when(mockScriptManager.getScriptCached(any)).thenReturn(testScript);
  setGlobal(ScriptManager, mockScriptManager);
}

void mockVmObject(VmObject object) {
  when(object.scriptRef).thenReturn(testScript);
  when(object.script).thenReturn(testScript);
  when(object.pos).thenReturn(testPos);
  when(object.fetchingReachableSize).thenReturn(ValueNotifier<bool>(false));
  when(object.reachableSize).thenReturn(testRequestableSize);
  when(object.fetchingRetainedSize).thenReturn(ValueNotifier<bool>(false));
  when(object.retainedSize).thenReturn(null);
  when(object.retainingPath).thenReturn(
    ValueNotifier<RetainingPath?>(testRetainingPath),
  );
  when(object.inboundReferencesTree).thenReturn(
    ListValueNotifier<InboundReferencesTreeNode>(
      InboundReferencesTreeNode.buildTreeRoots(testInboundRefs),
    ),
  );

  if (object is ClassObject) {
    when(object.name).thenReturn(testClass.name);
    when(object.ref).thenReturn(testClass);
    when(object.obj).thenReturn(testClass);
    when(object.instances).thenReturn(testInstances);
  }

  if (object is FieldObject) {
    when(object.name).thenReturn(testField.name);
    when(object.ref).thenReturn(testField);
    when(object.obj).thenReturn(testField);
    when(object.guardClass).thenReturn(null);
    when(object.guardNullable).thenReturn(null);
    when(object.guardClassKind).thenReturn(null);
  }

  if (object is FuncObject) {
    when(object.name).thenReturn(testFunction.name);
    when(object.ref).thenReturn(testFunction);
    when(object.obj).thenReturn(testFunction);
    when(object.kind).thenReturn(null);
    when(object.deoptimizations).thenReturn(null);
    when(object.isOptimizable).thenReturn(null);
    when(object.isInlinable).thenReturn(null);
    when(object.hasIntrinsic).thenReturn(null);
    when(object.isRecognized).thenReturn(null);
    when(object.isNative).thenReturn(null);
    when(object.vmName).thenReturn(null);
    when(object.icDataArray).thenReturn(null);
  }

  if (object is ScriptObject) {
    when(object.name).thenReturn(fileNameFromUri(testScript.uri));
    when(object.ref).thenReturn(testScript);
    when(object.obj).thenReturn(testScript);
    when(object.loadTime).thenReturn(testLoadTime);
  }

  if (object is LibraryObject) {
    when(object.name).thenReturn(testLib.name);
    when(object.ref).thenReturn(testLib);
    when(object.obj).thenReturn(testLib);
    when(object.vmName).thenReturn(null);
  }
}
