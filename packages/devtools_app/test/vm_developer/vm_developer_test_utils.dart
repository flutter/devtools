import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector_view_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/object_viewport.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_object_model.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

final fakeLibRef =
    TestLibraryRef(name: 'fooLib', uri: 'fooLib.dart', id: '1234');

final fakeLib = Library(
  name: 'fooLib',
  uri: 'fooLib.dart',
  debuggable: null,
  dependencies: null,
  scripts: null,
  variables: null,
  functions: null,
  classes: null,
  id: '1234',
);

final fakeClassRef =
    TestClassRef(name: 'fooClass', library: fakeLibRef, id: '1234');

final fakeClass = Class(
  name: 'fooClass',
  library: fakeLibRef,
  isAbstract: false,
  isConst: false,
  traceAllocations: false,
  interfaces: null,
  fields: null,
  functions: null,
  subclasses: null,
  superClass: fakeSuperClass,
  superType: fakeSuperType,
  id: '1234',
);

final fakeScript =
    Script(uri: 'fooScript.dart', library: fakeLibRef, id: '1234');

final fakeFunctionRef = TestFuncRef(
  name: 'FooFunction',
  owner: fakeLibRef,
  isStatic: false,
  isConst: false,
  implicit: false,
  id: '1234',
);

final fakeFunction = Func(
  name: 'FooFunction',
  owner: fakeLibRef,
  isStatic: false,
  isConst: false,
  implicit: false,
  signature: null,
  id: '1234',
);

final fakeFieldRef = TestFieldRef(
  name: 'fooField',
  owner: null,
  declaredType: null,
  isConst: null,
  isFinal: null,
  isStatic: null,
  id: '1234',
);

final fakeField = Field(
  name: 'fooField',
  owner: null,
  declaredType: null,
  isConst: null,
  isFinal: null,
  isStatic: null,
  id: '1234',
);

final fakeInstanceRef = TestInstanceRef(
  kind: null,
  identityHashCode: null,
  classRef: null,
  id: '1234',
);

final fakeInstance = Instance(
  kind: null,
  identityHashCode: null,
  classRef: null,
  id: '1234',
  name: 'fooInstance',
);

final fakeSuperClass =
    ClassRef(name: 'fooSuperClass', library: fakeLibRef, id: '1234');

final fakeSuperType = InstanceRef(
  kind: '',
  identityHashCode: null,
  classRef: null,
  id: '1234',
  name: 'fooSuperType',
);

const fakePos = SourcePosition(line: 10, column: 4);

final fakeInstances = InstanceSet(instances: null, totalCount: 3);

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

class TestClassRef extends ClassRef {
  TestClassRef({
    required super.name,
    required super.library,
    required super.id,
  });

  @override
  String get type => 'Class';
}

class TestFuncObject extends FuncObject {
  TestFuncObject({required super.ref, required this.testFunc});

  Func testFunc;

  @override
  Func get obj => testFunc;

  @override
  String? get name => 'FooFunction';
}

class TestFuncRef extends FuncRef {
  TestFuncRef({
    required super.name,
    required super.owner,
    required super.isStatic,
    required super.isConst,
    required super.implicit,
    required super.id,
  });

  @override
  String get type => 'Function';
}

class TestFieldObject extends FieldObject {
  TestFieldObject({required super.ref, required this.testField});

  Field testField;

  @override
  Field get obj => testField;

  @override
  String? get name => 'FooField';
}

class TestFieldRef extends FieldRef {
  TestFieldRef({
    required super.name,
    required super.owner,
    required super.declaredType,
    required super.isConst,
    required super.isFinal,
    required super.isStatic,
    required super.id,
  });

  @override
  String get type => 'Field';
}

class TestLibraryObject extends LibraryObject {
  TestLibraryObject({required super.ref, required this.testLibrary});

  Library testLibrary;

  @override
  Library get obj => testLibrary;

  @override
  String? get name => 'FooLib';
}

class TestLibraryRef extends LibraryRef {
  TestLibraryRef({required super.name, required super.uri, required super.id});

  @override
  String get type => 'Library';
}

class TestInstanceObject extends InstanceObject {
  TestInstanceObject({required super.ref, required this.testInstance});

  Instance testInstance;

  @override
  Instance get obj => testInstance;

  @override
  String? get name => 'FooInstance';
}

class TestInstanceRef extends InstanceRef {
  TestInstanceRef(
      {required super.kind,
      required super.identityHashCode,
      required super.classRef,
      required super.id});

  @override
  String get type => 'Instance';
}
