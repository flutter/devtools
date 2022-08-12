// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import '../../service/vm_service_wrapper.dart';
import '../../shared/globals.dart';
import '../debugger/debugger_model.dart';
import '../debugger/program_explorer_model.dart';
import 'vm_service_private_extensions.dart';

/// Wrapper class for storing Dart VM objects with their relevant VM
/// information.
abstract class VmObject {
  VmObject({required this.ref, this.scriptRef, this.outlineNode});

  final ObjRef ref;

  /// The script node selected on the FileExplorer of the ProgramExplorer
  /// corresponding to this VM object.
  final ScriptRef? scriptRef;

  /// The outline node selected on the ProgramExplorer
  /// corresponding to this VM object.
  final VMServiceObjectNode? outlineNode;

  VmServiceWrapper get _service => serviceManager.service!;

  IsolateRef? _isolate;

  Obj get obj;
  late Obj _obj;

  String? get name;

  SourceLocation? get _sourceLocation;

  Script? get script => _sourceScript;
  Script? _sourceScript;

  SourcePosition? get pos => _pos;
  SourcePosition? _pos;

  ValueListenable<bool> get fetchingReachableSize => _fetchingReachableSize;
  final _fetchingReachableSize = ValueNotifier<bool>(false);

  InstanceRef? get reachableSize => _reachableSize;
  InstanceRef? _reachableSize;

  ValueListenable<bool> get fetchingRetainedSize => _fetchingRetainedSize;
  final _fetchingRetainedSize = ValueNotifier<bool>(false);

  InstanceRef? get retainedSize => _retainedSize;
  InstanceRef? _retainedSize;

  ValueListenable<RetainingPath?> get retainingPath => _retainingPath;
  final _retainingPath = ValueNotifier<RetainingPath?>(null);

  ValueListenable<InboundReferences?> get inboundReferences =>
      _inboundReferences;
  final _inboundReferences = ValueNotifier<InboundReferences?>(null);

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
        scriptRef?.id ?? _sourceLocation!.script!.id!,
      ) as Script;

      final token = _sourceLocation!.tokenPos!;

      _pos = SourcePosition.calculatePosition(
        _sourceScript!,
        token,
      );
    }
  }

  Future<void> requestReachableSize() async {
    _fetchingReachableSize.value = true;
    _reachableSize = await _service.getReachableSize(_isolate!.id!, ref.id!);
    _fetchingReachableSize.value = false;
  }

  Future<void> requestRetainedSize() async {
    _fetchingRetainedSize.value = true;
    _retainedSize = await _service.getRetainedSize(_isolate!.id!, ref.id!);
    _fetchingRetainedSize.value = false;
  }

  Future<void> requestRetainingPath() async {
    _retainingPath.value =
        await _service.getRetainingPath(_isolate!.id!, ref.id!, 100);
  }

  Future<void> requestInboundsRefs() async {
    _inboundReferences.value =
        await _service.getInboundReferences(_isolate!.id!, ref.id!, 100);
  }
}

/// Stores a 'Class' VM object and provides an interface for obtaining the
/// Dart VM information related to this object.
class ClassObject extends VmObject {
  ClassObject({required super.ref, super.scriptRef, super.outlineNode});

  @override
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

/// Stores a function (Func type) VM object and provides an interface for
/// obtaining the Dart VM information related to this object.
class FuncObject extends VmObject {
  FuncObject({required super.ref, super.scriptRef, super.outlineNode});

  @override
  Func get obj => _obj as Func;

  @override
  String? get name => obj.name;

  @override
  SourceLocation? get _sourceLocation => obj.location;

  FunctionKind? get kind {
    final funcKind = obj.kind;
    return funcKind == null
        ? null
        : FunctionKind.values
            .firstWhereOrNull((element) => element.kind() == funcKind);
  }

  int? get deoptimizations => obj.deoptimizations;

  bool? get isOptimizable => obj.optimizable;

  bool? get isInlinable => obj.inlinable;

  bool? get hasIntrinsic => obj.intrinsic;

  bool? get isRecognized => obj.recognized;

  bool? get isNative => obj.native;

  String? get vmName => obj.vmName;

  late final Instance? icDataArray;

  @override
  Future<void> initialize() async {
    await super.initialize();

    icDataArray = await obj.icDataArray;
  }
}

/// Stores a 'Field' VM object and provides an interface for obtaining the
/// Dart VM information related to this object.
class FieldObject extends VmObject {
  FieldObject({required super.ref, super.scriptRef, super.outlineNode});

  @override
  Field get obj => _obj as Field;

  @override
  String? get name => obj.name;

  @override
  SourceLocation? get _sourceLocation => obj.location;

  bool? get guardNullable => obj.guardNullable;

  late final Class? guardClass;

  late final GuardClassKind? guardClassKind;

  @override
  Future<void> initialize() async {
    await super.initialize();

    guardClassKind = obj.guardClassKind();

    if (guardClassKind == GuardClassKind.single) {
      guardClass = await obj.guardClass;
    } else {
      guardClass = null;
    }
  }
}

//TODO(mtaylee): finish class implementation.
class LibraryObject extends VmObject {
  LibraryObject({required super.ref, super.scriptRef, super.outlineNode});

  @override
  Library get obj => _obj as Library;

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => obj.name;
}

/// Stores a 'Script' VM object and provides an interface for obtaining the
/// Dart VM information related to this object.
class ScriptObject extends VmObject {
  ScriptObject({required super.ref, super.scriptRef, super.outlineNode});

  @override
  Script get obj => _obj as Script;

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => fileNameFromUri(obj.uri ?? scriptRef?.uri);

  DateTime get loadTime => DateTime.fromMillisecondsSinceEpoch(obj.loadTime);
}

//TODO(mtaylee): finish class implementation.
class InstanceObject extends VmObject {
  InstanceObject({required super.ref, super.scriptRef, super.outlineNode});

  @override
  Instance get obj => _obj as Instance;

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => obj.name;
}

class CodeObject extends VmObject {
  CodeObject({required super.ref, super.scriptRef, super.outlineNode});

  @override
  Code get obj => _obj as Code;

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => obj.name;
}
