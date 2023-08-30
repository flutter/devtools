// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../service/vm_service_wrapper.dart';
import '../../../shared/diagnostics/primitives/source_location.dart';
import '../../../shared/globals.dart';
import '../../../shared/primitives/utils.dart';
import '../vm_service_private_extensions.dart';
import 'inbound_references_tree.dart';
import 'vm_code_display.dart';

/// Wrapper class for storing Dart VM objects with their relevant VM
/// information.
abstract class VmObject {
  VmObject({required this.ref, this.scriptRef});

  final ObjRef ref;

  /// The script node selected on the FileExplorer of the ProgramExplorer
  /// corresponding to this VM object.
  final ScriptRef? scriptRef;

  VmServiceWrapper get _service => serviceConnection.serviceManager.service!;

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

  ValueListenable<List<InboundReferencesTreeNode>> get inboundReferencesTree =>
      _inboundReferencesTree;
  final _inboundReferencesTree =
      ListValueNotifier<InboundReferencesTreeNode>([]);

  @mustCallSuper
  Future<void> initialize() async {
    _isolate =
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value!;

    _obj = ref is Obj
        ? ref as Obj
        : await _service.getObject(_isolate!.id!, ref.id!);

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

  /// Retrieves the root set of inbound references to the current object.
  Future<void> requestInboundsRefs() async {
    final inboundRefs = await _service.getInboundReferences(
      _isolate!.id!,
      ref.id!,
      100,
    );
    _inboundReferencesTree.addAll(
      InboundReferencesTreeNode.buildTreeRoots(inboundRefs),
    );
  }

  /// Expands an [InboundReferencesTreeNode] by retrieving the inbound
  /// references for the `source` that references the current node.
  Future<void> expandInboundRef(InboundReferencesTreeNode node) async {
    final isolate =
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value!;
    final service = serviceConnection.serviceManager.service!;
    final inboundRefs = await service.getInboundReferences(
      isolate.id!,
      node.ref.source!.id!,
      100,
    );
    node.addAllChildren(
      InboundReferencesTreeNode.buildTreeRoots(inboundRefs),
    );
    _inboundReferencesTree.notifyListeners();
  }
}

/// A class of [VmObject] for VM objects that simply provide a list of elements
/// to be displayed.
///
/// All instances of [VmListObject] will be displaying using the
/// [VmSimpleListDisplay] view.
///
/// Implementers of this interface must have a non-null return value for one of
/// `elementsAsList` or `elementsAsInstance`.
abstract class VmListObject extends VmObject {
  VmListObject({required super.ref});

  List<Response?>? get elementsAsList;

  InstanceRef? get elementsAsInstance;
}

/// Stores a 'Class' VM object and provides an interface for obtaining the
/// Dart VM information related to this object.
class ClassObject extends VmObject {
  ClassObject({required super.ref, super.scriptRef});

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
  FuncObject({required super.ref, super.scriptRef});

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
  FieldObject({required super.ref, super.scriptRef});

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

    guardClass =
        guardClassKind == GuardClassKind.single ? await obj.guardClass : null;
  }
}

/// Stores a 'Library' VM object and provides an interface for obtaining the
/// Dart VM information related to this object.
class LibraryObject extends VmObject {
  LibraryObject({required super.ref, super.scriptRef});

  @override
  Library get obj => _obj as Library;

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => obj.name;

  String? get vmName => obj.vmName;
}

/// Stores a 'Script' VM object and provides an interface for obtaining the
/// Dart VM information related to this object.
class ScriptObject extends VmObject {
  ScriptObject({required super.ref, super.scriptRef});

  @override
  Script get obj => _obj as Script;

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => fileNameFromUri(obj.uri ?? scriptRef?.uri);

  DateTime get loadTime => DateTime.fromMillisecondsSinceEpoch(obj.loadTime);
}

class InstanceObject extends VmObject {
  InstanceObject({required super.ref, super.scriptRef});

  @override
  Instance get obj => _obj as Instance;

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => obj.name;
}

class CodeObject extends VmObject {
  CodeObject({required super.ref, super.scriptRef});

  @override
  Code get obj => _obj as Code;

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => obj.name;

  /// A collection of CPU profiler information for individual [Instruction]s.
  ///
  /// Returns null if the CPU profiler is disabled.
  CpuProfilerTicksTable? get ticksTable => _table;
  CpuProfilerTicksTable? _table;

  @override
  Future<void> initialize() async {
    await super.initialize();

    final service = serviceConnection.serviceManager.service!;
    final isolateId = serviceConnection
        .serviceManager.isolateManager.selectedIsolate.value!.id!;

    // Attempt to retrieve the CPU profile data for this code object.
    try {
      final samples = await service.getCpuSamples(isolateId, 0, maxJsInt);
      final codes = samples.codes;

      final match = codes.firstWhereOrNull(
        (profileCode) => profileCode.code == ref,
      );

      if (match == null) {
        throw StateError('Unable to find matching ProfileCode');
      }

      _table = CpuProfilerTicksTable.parse(
        sampleCount: samples.sampleCount!,
        ticks: match.ticks!,
      );
    } on RPCError {
      // This can happen when the profiler is disabled, so we just can't show
      // CPU profiling ticks for the code disassembly.
    }
  }
}

/// Stores an 'ObjectPool' VM object and provides an interface for obtaining
/// then Dart VM information related to this object.
class ObjectPoolObject extends VmObject {
  ObjectPoolObject({required super.ref, super.scriptRef});

  @override
  ObjectPool get obj => _obj.asObjectPool;

  @override
  String? get name => null;

  @override
  SourceLocation? get _sourceLocation => null;
}

/// Stores an 'ICData' VM object and provides an interface for obtaining the
/// Dart VM information related to this object.
class ICDataObject extends VmObject {
  ICDataObject({required super.ref});

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => '(${obj.selector})';

  @override
  ICData get obj => _obj.asICData;
}

/// Stores a 'SubtypeTestCache' VM object and provides an interface for
/// obtaining the Dart VM information related to this object.
class SubtypeTestCacheObject extends VmListObject {
  SubtypeTestCacheObject({required super.ref});

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => null;

  @override
  SubtypeTestCache get obj => _obj.asSubtypeTestCache;

  @override
  InstanceRef get elementsAsInstance => obj.cache;

  @override
  List<Response?>? get elementsAsList => null;
}

/// Stores a 'WeakArray' VM object and provides an interface for
/// obtaining the Dart VM information related to this object.
class WeakArrayObject extends VmListObject {
  WeakArrayObject({required super.ref});

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => null;

  @override
  WeakArray get obj => _obj.asWeakArray;

  @override
  InstanceRef? get elementsAsInstance => null;

  @override
  List<Response?>? get elementsAsList => obj.asWeakArray.elements;
}

/// Catch-all for VM internal types that don't have a particularly interesting
/// set of properties but are reachable through the service protocol.
class UnknownObject extends VmObject {
  UnknownObject({required super.ref, super.scriptRef});

  @override
  SourceLocation? get _sourceLocation => null;

  @override
  String? get name => obj.classRef!.name;

  @override
  Obj get obj => _obj;
}
