// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../service/vm_service_wrapper.dart';
import '../../shared/globals.dart';
import '../debugger/debugger_model.dart';

/// Wrapper class for storing Dart VM objects with their relevant VM
/// information.
abstract class VmObject {
  VmObject({required this.ref});

  final ObjRef ref;

  VmServiceWrapper get _service => serviceManager.service!;

  IsolateRef? _isolate;

  late Obj _obj;

  String? get name;

  SourceLocation? get _sourceLocation;

  Script? get script => _sourceScript;
  Script? _sourceScript;

  SourcePosition? get pos => _pos;
  SourcePosition? _pos;

  Future<void> fetchObject() async {
    final isolateRef = serviceManager.isolateManager.selectedIsolate.value!;
    _isolate = await _service.getIsolate(isolateRef.id!);
    _obj = await _service.getObject(_isolate!.id!, ref.id!);
  }

  @mustCallSuper
  Future<void> initialize() async {
    await fetchObject();

    if (_sourceLocation != null) {
      _sourceScript = await _service.getObject(
        _isolate!.id!,
        _sourceLocation!.script!.id!,
      ) as Script;

      final token = _sourceLocation!.tokenPos!;

      _pos = SourcePosition.calculatePosition(
        _sourceScript!,
        token,
      );
    }
  }
}

//TODO(mtaylee): finish class implementation.
class ClassObject extends VmObject {
  ClassObject({required super.ref});

  Class get obj => _obj as Class;

  @override
  String? get name => obj.name;

  InstanceSet? get instances => _instances;
  InstanceSet? _instances;

  @override
  SourceLocation? get _sourceLocation => obj.location;

  @override
  Future<void> initialize() async {
    await super.initialize();
    _instances = await _service.getInstances(_isolate!.id!, ref.id!, 100);
  }
}

//TODO(mtaylee): finish class implementation.
class FuncObject extends VmObject {
  FuncObject({required super.ref});

  Func get obj => _obj as Func;

  @override
  String? get name => obj.name;

  @override
  SourceLocation? get _sourceLocation => obj.location;
}

//TODO(mtaylee): finish class implementation.
class FieldObject extends VmObject {
  FieldObject({required super.ref});

  Field get obj => _obj as Field;

  @override
  String? get name => obj.name;

  @override
  SourceLocation? get _sourceLocation => obj.location;
}

//TODO(mtaylee): finish class implementation.
class LibraryObject extends VmObject {
  LibraryObject({required super.ref});

  Library get obj => _obj as Library;

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => obj.name;
}

//TODO(mtaylee): finish class implementation.
class ScriptObject extends VmObject {
  ScriptObject({required super.ref});

  Script get obj => _obj as Script;

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => null;
}

//TODO(mtaylee): finish class implementation.
class InstanceObject extends VmObject {
  InstanceObject({required super.ref});

  Instance get obj => _obj as Instance;

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => obj.name;
}

class CodeObject extends VmObject {
  CodeObject({required super.ref});

  Code get obj => _obj as Code;

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => obj.name;
}
