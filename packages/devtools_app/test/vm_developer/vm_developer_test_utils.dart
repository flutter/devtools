import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector_view_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/object_viewport.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_object_model.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

final testLib = Library(
  name: 'fooLib',
  uri: 'fooLib.dart',
  debuggable: null,
  dependencies: <LibraryDependency>[],
  scripts: null,
  variables: null,
  functions: null,
  classes: null,
  id: '1234',
);

final testClass = Class(
  name: 'fooClass',
  library: testLib,
  isAbstract: false,
  isConst: false,
  traceAllocations: false,
  interfaces: null,
  fields: null,
  functions: null,
  subclasses: null,
  superClass: testSuperClass,
  superType: testSuperType,
  id: '1234',
);

final testScript = Script(uri: 'fooScript.dart', library: testLib, id: '1234');

final testFunction = Func(
  name: 'FooFunction',
  owner: testLib,
  isStatic: false,
  isConst: false,
  implicit: false,
  signature: null,
  id: '1234',
);

final testField = Field(
  name: 'fooField',
  owner: null,
  declaredType: null,
  isConst: null,
  isFinal: null,
  isStatic: null,
  id: '1234',
);

final testInstance = Instance(
  kind: null,
  identityHashCode: null,
  classRef: null,
  id: '1234',
  name: 'fooInstance',
);

final testSuperClass =
    ClassRef(name: 'fooSuperClass', library: testLib, id: '1234');

final testSuperType = InstanceRef(
  kind: '',
  identityHashCode: null,
  classRef: null,
  id: '1234',
  name: 'fooSuperType',
);

const testPos = SourcePosition(line: 10, column: 4);

final testInstances = InstanceSet(instances: null, totalCount: 3);

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
