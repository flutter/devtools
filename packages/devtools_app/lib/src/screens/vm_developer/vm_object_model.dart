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

  String? get name;

  VmServiceWrapper get _service => serviceManager.service!;

  IsolateRef? _isolate;

  Obj? _obj;

  Future<void> fetchObject() async {
    final isolateRef = serviceManager.isolateManager.selectedIsolate.value!;
    _isolate = await _service.getIsolate(isolateRef.id!);
    _obj = await _service.getObject(_isolate!.id!, ref.id!);
  }

  Future<void> initialize();
}

class ClassObject extends VmObject {
  ClassObject({required super.ref});

  Class? get obj => _clazz;
  Class? _clazz;

  @override
  String? get name => obj?.name;

  Script? get script => _script;
  Script? _script;

  SourcePosition? get pos => _pos;
  SourcePosition? _pos;

  InstanceSet? get instances => _instances;
  InstanceSet? _instances;

  @override
  Future<void> initialize() async {
    await fetchObject();

    _clazz = _obj as Class?;

    if (_clazz != null) {
      final token = _clazz!.location!.tokenPos!;
      _script = await _service.getObject(
        _isolate!.id!,
        _clazz!.location!.script!.id!,
      ) as Script;
      _pos = SourcePosition.calculatePosition(
        _script!,
        token,
      );
    }

    _instances = await _service.getInstances(_isolate!.id!, ref.id!, 100);
  }
}

class FuncObject extends VmObject {
  FuncObject({required super.ref});

  Func? get obj => _function;
  Func? _function;

  @override
  String? get name => _function?.name;

  @override
  Future<void> initialize() async {
    await fetchObject();
  }
}

class FieldObject extends VmObject {
  FieldObject({required super.ref});

  Field? get obj => _field;
  Field? _field;

  @override
  String? get name => _field?.name;

  @override
  Future<void> initialize() async {
    await fetchObject();
  }
}

class LibraryObject extends VmObject {
  LibraryObject({required super.ref});

  Library? get obj => _library;
  Library? _library;

  @override
  String? get name => _library?.name;

  @override
  Future<void> initialize() async {
    await fetchObject();
  }
}

class ScriptObject extends VmObject {
  ScriptObject({required super.ref});

  Script? get obj => _script;
  Script? _script;

  @override
  String? get name => null;

  @override
  Future<void> initialize() async {
    await fetchObject();
  }
}

class InstanceObject extends VmObject {
  InstanceObject({required super.ref});

  Instance? get obj => _instance;
  Instance? _instance;

  @override
  String? get name => _instance?.name;

  @override
  Future<void> initialize() async {
    await fetchObject();
  }
}
