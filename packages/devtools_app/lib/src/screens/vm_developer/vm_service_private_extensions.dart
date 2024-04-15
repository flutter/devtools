// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: constant_identifier_names

import 'package:flutter/widgets.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../memory/panes/profile/profile_view.dart';

/// NOTE: this file contains extensions to classes provided by
/// `package:vm_service` in order to expose VM internal fields in a controlled
/// fashion. Objects and extensions in this class should not be used in
/// contexts where [PreferencesController.vmDeveloperModeEnabled] is not set to
/// `true`.

const _vmNameKey = '_vmName';

/// An extension on [VM] which allows for access to VM internal fields.
extension VMPrivateViewExtension on VM {
  String get embedder => json!['_embedder'];
  String get profilerMode => json!['_profilerMode'];
  int get currentMemory => json!['_currentMemory'];
  int get currentRSS => json!['_currentRSS'];
  int get maxRSS => json!['_maxRSS'];
  int? get nativeZoneMemoryUsage => json!['_nativeZoneMemoryUsage'];
}

/// An extension on [Isolate] which allows for access to VM internal fields.
extension IsolatePrivateViewExtension on Isolate {
  Map<String, dynamic>? get tagCounters => json!['_tagCounters'];

  int get dartHeapSize => newSpaceUsage + oldSpaceUsage;
  int get dartHeapCapacity => newSpaceCapacity + oldSpaceCapacity;

  int get newSpaceUsage => _newHeap['used'] as int;
  int get oldSpaceUsage => _oldHeap['used'] as int;

  int get newSpaceCapacity => _newHeap['capacity'] as int;
  int get oldSpaceCapacity => _oldHeap['capacity'] as int;

  Map<String, Object?> get _newHeap =>
      (_heaps['new'] as Map).cast<String, Object?>();
  Map<String, Object?> get _oldHeap =>
      (_heaps['old'] as Map).cast<String, Object?>();

  Map<String, Object?> get _heaps =>
      (json!['_heaps'] as Map).cast<String, Object?>();
}

/// An extension on [Class] which allows for access to VM internal fields.
extension ClassPrivateViewExtension on Class {
  /// The internal name of the [Class].
  String get vmName => json![_vmNameKey];
}

/// An extension on [InboundReferences] which allows for access to
/// VM internal fields.
extension InboundReferenceExtension on InboundReferences {
  static const _referencesKey = 'references';
  static const _parentWordOffsetKey = '_parentWordOffset';

  int? parentWordOffset(int inboundReferenceIndex) {
    final references = (json![_referencesKey] as List?)?.cast<Object?>();
    final inboundReference =
        (references?[inboundReferenceIndex] as Map?)?.cast<String, Object?>();
    return inboundReference?[_parentWordOffsetKey] as int?;
  }
}

class HeapStats {
  const HeapStats({
    required this.count,
    required this.size,
    required this.externalSize,
  });

  const HeapStats.empty()
      : count = 0,
        size = 0,
        externalSize = 0;

  HeapStats.parse(List<int> stats)
      : count = stats[0],
        size = stats[1],
        externalSize = stats[2];

  final int count;
  final int size;
  final int externalSize;
}

/// An extension on [ClassHeapStats] which allows for access to VM internal
/// fields.
extension ClassHeapStatsPrivateViewExtension on ClassHeapStats {
  static const _newSpaceKey = '_new';
  static const _oldSpaceKey = '_old';

  HeapStats get newSpace => json!.containsKey(_newSpaceKey)
      ? HeapStats.parse((json![_newSpaceKey] as List).cast<int>())
      : const HeapStats.empty();
  HeapStats get oldSpace => json!.containsKey(_oldSpaceKey)
      ? HeapStats.parse((json![_oldSpaceKey] as List).cast<int>())
      : const HeapStats.empty();
}

class GCStats {
  GCStats({
    required this.heap,
    required this.usage,
    required this.capacity,
    required this.collections,
    required this.averageCollectionTime,
  });

  factory GCStats.parse({
    required String heap,
    required Map<String, dynamic> json,
  }) {
    final collections = json[collectionsKey] as int;
    return GCStats(
      heap: heap,
      usage: json[usedKey],
      capacity: json[capacityKey],
      collections: collections,
      averageCollectionTime: (json[timeKey] as num) * 1000 / collections,
    );
  }

  static const usedKey = 'used';
  static const capacityKey = 'capacity';
  static const collectionsKey = 'collections';
  static const timeKey = 'time';

  final String heap;
  final int usage;
  final int capacity;
  final int collections;
  final double averageCollectionTime;
}

extension AllocationProfilePrivateViewExtension on AllocationProfile {
  static const heapsKey = '_heaps';
  static const newSpaceKey = 'new';
  static const oldSpaceKey = 'old';

  GCStats get newSpaceGCStats => GCStats.parse(
        heap: HeapGeneration.newSpace.toString(),
        json: (_heaps[newSpaceKey] as Map).cast<String, Object?>(),
      );

  GCStats get oldSpaceGCStats => GCStats.parse(
        heap: HeapGeneration.oldSpace.toString(),
        json: (_heaps[oldSpaceKey] as Map).cast<String, Object?>(),
      );

  Map<String, Object?> get _heaps =>
      (json![heapsKey] as Map).cast<String, Object?>();

  GCStats get totalGCStats {
    final newSpace = newSpaceGCStats;
    final oldSpace = oldSpaceGCStats;
    final collections = newSpace.collections + oldSpace.collections;
    final averageCollectionTime =
        ((newSpace.collections * newSpace.averageCollectionTime) +
                (oldSpace.collections * oldSpace.averageCollectionTime)) /
            collections;
    return GCStats(
      heap: HeapGeneration.total.toString(),
      usage: newSpace.usage + oldSpace.usage,
      capacity: newSpace.capacity + oldSpace.capacity,
      collections: collections,
      averageCollectionTime: averageCollectionTime,
    );
  }
}

/// An extension on [ObjRef] which allows for access to VM internal fields.
extension ObjRefPrivateViewExtension on ObjRef {
  static const _icDataType = 'ICData';
  static const _objectPoolType = 'ObjectPool';
  static const _subtypeTestCache = 'SubtypeTestCache';
  static const _weakArrayType = 'WeakArray';

  /// The internal type of the object.
  ///
  /// The type of non-public service objects can be determined using this
  /// value.
  String? get vmType => json!['_vmType'];

  /// `true` if this object is an instance of [ICDataRef].
  bool get isICData => vmType == _icDataType;

  /// Casts the current [ObjRef] into an instance of [ICDataRef].
  ICDataRef get asICData => ICDataRef.fromJson(json!);

  /// `true` if this object is an instance of [ObjectPool].
  bool get isObjectPool => vmType == _objectPoolType;

  /// Casts the current [ObjRef] into an instance of [ObjectPoolRef].
  ObjectPoolRef get asObjectPool => ObjectPoolRef.parse(json!);

  /// `true` if this object is an instance of [SubtypeTestCacheRef].
  bool get isSubtypeTestCache => vmType == _subtypeTestCache;

  /// Casts the current [ObjRef] into an instance of [SubtypeTestCacheRef].
  SubtypeTestCacheRef get asSubtypeTestCache =>
      SubtypeTestCacheRef.fromJson(json!);

  /// `true` if this object is an instance of [WeakArrayRef].
  bool get isWeakArray => vmType == _weakArrayType;

  /// Casts the current [ObjRef] into an instance of [WeakArrayRef].
  WeakArrayRef get asWeakArray => WeakArrayRef.fromJson(json!);
}

/// An extension on [Obj] which allows for access to VM internal fields.
extension ObjPrivateViewExtension on Obj {
  /// Casts the current [Obj] into an instance of [ObjectPool].
  ObjectPool get asObjectPool => ObjectPool.parse(json!);

  /// Casts the current [Obj] into an instance of [ICData].
  ICData get asICData => ICData.fromJson(json!);

  /// Casts the current [Obj] into an instance of [SubtypeTestCache].
  SubtypeTestCache get asSubtypeTestCache => SubtypeTestCache.fromJson(json!);

  /// Casts the current [Obj] into an instance of [WeakArray].
  WeakArray get asWeakArray => WeakArray.fromJson(json!);
}

/// A reference to a [WeakArray], which is an array consisting of weak
/// persistent handles.
///
/// References to an object from a [WeakArray] are ignored by the GC and will
/// not prevent referenced objects from being collected when all other
/// references to the object disappear.
class WeakArrayRef implements ObjRef {
  WeakArrayRef({
    required this.id,
    required this.json,
    required this.length,
  });

  factory WeakArrayRef.fromJson(Map<String, dynamic> json) => WeakArrayRef(
        id: json['id'],
        json: json,
        length: json['length'],
      );

  @override
  bool? fixedId;

  @override
  String? id;

  @override
  Map<String, dynamic>? json;

  final int length;

  @override
  Map<String, dynamic> toJson() => json!;

  @override
  String get type => 'WeakArray';
}

/// A populated representation of a [WeakArray], which is an array consisting
/// of weak persistent handles.
///
/// References to an object from a [WeakArray] are ignored by the GC and will
/// not prevent referenced objects from being collected when all other
/// references to the object disappear.
class WeakArray extends WeakArrayRef implements Obj {
  WeakArray({
    required super.id,
    required super.json,
    required super.length,
    required this.elements,
    required this.size,
    required this.classRef,
  });

  factory WeakArray.fromJson(Map<String, dynamic> json) => WeakArray(
        id: json['id'],
        json: json,
        length: json['length'],
        size: json['size'],
        elements: (createServiceObject(json['elements'], []) as List)
            .cast<Response?>(),
        classRef: createServiceObject(json['class'], [])! as ClassRef,
      );

  final List<Response?> elements;

  @override
  Map<String, dynamic> toJson() => json!;

  @override
  String get type => 'WeakArray';

  @override
  ClassRef? classRef;

  @override
  int? size;
}

/// A partially-populated representation of the Dart VM's subtype test cache.
class SubtypeTestCacheRef implements ObjRef {
  SubtypeTestCacheRef({
    required this.id,
    required this.json,
  });

  factory SubtypeTestCacheRef.fromJson(Map<String, dynamic> json) =>
      SubtypeTestCacheRef(
        id: json['id'],
        json: json,
      );

  @override
  bool? fixedId;

  @override
  String? id;

  @override
  Map<String, dynamic>? json;

  @override
  Map<String, dynamic> toJson() => json!;

  @override
  String get type => 'SubtypeTestCache';
}

/// A fully-populated representation of the Dart VM's subtype test cache.
class SubtypeTestCache extends SubtypeTestCacheRef implements Obj {
  SubtypeTestCache({
    required super.id,
    required super.json,
    required this.size,
    required this.classRef,
    required this.cache,
  });

  factory SubtypeTestCache.fromJson(Map<String, dynamic> json) =>
      SubtypeTestCache(
        id: json['id'],
        size: json['size'],
        cache: createServiceObject(json['_cache'], [])! as InstanceRef,
        classRef: createServiceObject(json['class'], [])! as ClassRef,
        json: json,
      );

  /// An array of objects which make up the cache.
  final InstanceRef cache;

  @override
  ClassRef? classRef;

  @override
  int? size;
}

/// A partially-populated representation of the Dart VM's Inline Cache (IC).
///
/// For more information:
///  - [Slava's Dart VM intro](https://mrale.ph/dartvm/)
///  - [Dart VM implementation](https://github.com/dart-lang/sdk/blob/2d064faf748d6c7700f08d223fb76c84c4335c5f/runtime/vm/raw_object.h#L2103)
class ICDataRef implements ObjRef {
  ICDataRef({
    required this.id,
    required this.json,
    required this.owner,
    required this.selector,
  });

  factory ICDataRef.fromJson(Map<String, dynamic> json) => ICDataRef(
        id: json['id'],
        owner: createServiceObject(json['_owner'], []) as ObjRef,
        selector: json['_selector'],
        json: json,
      );

  final ObjRef owner;
  final String selector;

  @override
  bool? fixedId;

  @override
  String? id;

  @override
  Map<String, dynamic>? json;

  @override
  Map<String, dynamic> toJson() => json!;

  @override
  String get type => 'ICData';
}

/// A fully-populated representation of the Dart VM's Inline Cache (IC).
///
/// For more information:
///  - [Slava's Dart VM intro](https://mrale.ph/dartvm/)
///  - [Dart VM implementation](https://github.com/dart-lang/sdk/blob/2d064faf748d6c7700f08d223fb76c84c4335c5f/runtime/vm/raw_object.h#L2103)
class ICData extends ICDataRef implements Obj {
  ICData({
    required super.id,
    required super.json,
    required super.owner,
    required super.selector,
    required this.classRef,
    required this.size,
    required this.argumentsDescriptor,
    required this.entries,
  }) : super();

  factory ICData.fromJson(Map<String, dynamic> json) => ICData(
        id: json['id'],
        owner: createServiceObject(json['_owner'], []) as ObjRef,
        selector: json['_selector'],
        classRef: createServiceObject(json['class'], []) as ClassRef,
        size: json['size'],
        argumentsDescriptor:
            createServiceObject(json['_argumentsDescriptor'], [])!
                as InstanceRef,
        entries: createServiceObject(json['_entries'], [])! as InstanceRef,
        json: json,
      );

  @override
  ClassRef? classRef;

  @override
  int? size;

  final InstanceRef argumentsDescriptor;
  final InstanceRef entries;
}

/// A single assembly instruction from a [Func]'s generated code disassembly.
class Instruction {
  Instruction.parse(List data)
      : address = data[0],
        unknown = data[1],
        instruction = data[2] {
    if (data[3] == null) {
      object = null;
      return;
    }
    final rawObject = data[3] as Map<String, dynamic>;
    object = (rawObject['type'] as List).contains('Instance')
        ? InstanceRef.parse(rawObject)
        : createServiceObject(data[3], const <String>[]) as Response?;
  }

  /// The instruction's address in memory.
  final String address;

  /// The instruction's address in memory with leading zeros removed.
  String get unpaddedAddress =>
      address.substring(address.indexOf(RegExp(r'[^0]')));

  /// TODO(bkonyi): figure out what this value is for.
  final String unknown;

  /// The [String] representation of the assembly instruction.
  final String instruction;

  /// The Dart object this instruction is acting upon directly.
  late final Response? object;

  List toJson() => [
        address,
        unknown,
        instruction,
        object?.json,
      ];
}

/// The full disassembly of generated [Code] for a function.
class Disassembly {
  Disassembly.parse(List disassembly) {
    for (int i = 0; i < disassembly.length; i += 4) {
      instructions.add(
        Instruction.parse(disassembly.getRange(i, i + 4).toList()),
      );
    }
  }

  /// The list of [Instructions] that make up the generated code.
  final instructions = <Instruction>[];

  List toJson() => [
        for (final i in instructions) ...i.toJson(),
      ];
}

/// An extension on [Func] which allows for access to VM internal fields.
extension FunctionPrivateViewExtension on Func {
  static const _unoptimizedCodeKey = '_unoptimizedCode';
  static const _kindKey = '_kind';
  static const _deoptimizationsKey = '_deoptimizations';
  static const _optimizableKey = '_optimizable';
  static const _inlinableKey = '_inlinable';
  static const _intrinsicKey = '_intrinsic';
  static const _recognizedKey = '_recognized';
  static const _nativeKey = '_native';
  static const _icDataArrayKey = '_icDataArray';

  /// The unoptimized [CodeRef] associated with the [Func].
  CodeRef? get unoptimizedCode => CodeRef.parse(json![_unoptimizedCodeKey]);
  set unoptimizedCode(CodeRef? code) => json![_unoptimizedCodeKey] = code?.json;

  String? get kind => json![_kindKey];
  int? get deoptimizations => json![_deoptimizationsKey];
  bool? get optimizable => json![_optimizableKey];
  bool? get inlinable => json![_inlinableKey];
  bool? get intrinsic => json![_intrinsicKey];
  bool? get recognized => json![_recognizedKey];
  bool? get native => json![_nativeKey];
  String? get vmName => json!['_vmName'];

  Future<Instance?> get icDataArray async {
    final icDataArray =
        (json![_icDataArrayKey] as Map?)?.cast<String, Object?>();
    final icDataArrayId = icDataArray?['id'] as String?;
    if (icDataArrayId != null) {
      final service = serviceConnection.serviceManager.service!;
      final isolate =
          serviceConnection.serviceManager.isolateManager.selectedIsolate.value;

      return await service.getObject(isolate!.id!, icDataArrayId) as Instance;
    } else {
      return null;
    }
  }
}

/// The function kinds recognized by the Dart VM.
enum FunctionKind {
  RegularFunction,
  ClosureFunction,
  ImplicitClosureFunction,
  GetterFunction,
  SetterFunction,
  Constructor,
  ImplicitGetter,
  ImplicitSetter,
  ImplicitStaticGetter,
  FieldInitializer,
  IrregexpFunction,
  MethodExtractor,
  NoSuchMethodDispatcher,
  InvokeFieldDispatcher,
  Collected,
  Native,
  FfiTrampoline,
  Stub,
  Tag,
  DynamicInvocationForwarder;

  String kind() {
    return toString().split('.').last;
  }

  /// Returns the [kind] string converted from camel case to title case by
  /// adding a space whenever a lowercase letter is followed by an uppercase
  /// letter.
  ///
  /// For example, calling [kindDescription] on
  /// [FunctionKind.ImplicitClosureFunction] would return
  /// 'Implicit Closure Function';
  String kindDescription() {
    final description = StringBuffer();
    final camelCase = RegExp(r'(?<=[a-z])[A-Z]');

    description.write(
      kind().replaceAllMapped(
        camelCase,
        (Match m) => ' ${m.group(0)!}',
      ),
    );

    return description.toString();
  }
}

extension CodeRefPrivateViewExtension on CodeRef {
  static const _functionKey = 'function';

  /// Returns the function from which this code object was generated.
  FuncRef? get function {
    final functionJson = json![_functionKey] as Map<String, dynamic>?;
    return FuncRef.parse(functionJson);
  }
}

/// An extension on [Code] which allows for access to VM internal fields.
extension CodePrivateViewExtension on Code {
  static const _disassemblyKey = '_disassembly';
  static const _kindKey = 'kind';
  static const _objectPoolKey = '_objectPool';

  /// Returns the disassembly of the [Code], which is the generated assembly
  /// instructions for the code's function.
  Disassembly get disassembly => Disassembly.parse(json![_disassemblyKey]);
  set disassembly(Disassembly disassembly) =>
      json![_disassemblyKey] = disassembly.toJson();

  /// The kind of code object represented by this instance.
  ///
  /// Can be one of:
  ///   - Dart
  ///   - Stub
  String get kind => json![_kindKey];

  ObjectPoolRef get objectPool => ObjectPoolRef.parse(json![_objectPoolKey]);

  bool get hasInliningData => json!.containsKey(InliningData.kInlinedFunctions);
  InliningData get inliningData => InliningData.fromJson(json!);
}

extension AddressExtension on num {
  String get asAddress =>
      '0x${toInt().toRadixString(16).toUpperCase().padLeft(8, '0')}';
}

class InliningData {
  const InliningData._({required this.entries});

  factory InliningData.fromJson(Map<String, dynamic> json) {
    final startAddress = int.parse(json[kStartAddressKey], radix: 16);
    final intervals = (json[kInlinedIntervals] as List).cast<List>();
    final functions = (json[kInlinedFunctions] as List)
        .cast<Map<String, dynamic>>()
        .map<FuncRef>((e) => FuncRef.parse(e)!)
        .toList();

    final entries = <InliningEntry>[];

    // Inlining data format: [startAddress, endAddress, 0, inline functions...]
    for (final interval in intervals) {
      assert(interval.length >= 2);
      final range = Range(
        startAddress + interval[0],
        startAddress + interval[1],
      );
      // We start at i = 3 as `interval[2]` is always present and set to 0,
      // likely serving as a sentinel. `functions[0]` is not inlined for every
      // range, so we'll ignore this value.
      final inlinedFunctions = <FuncRef>[
        for (int i = 3; i < interval.length; ++i) functions[interval[i]],
      ];
      entries.add(
        InliningEntry(
          addressRange: range,
          functions: inlinedFunctions,
        ),
      );
    }

    return InliningData._(entries: entries);
  }

  @visibleForTesting
  static const kInlinedIntervals = '_inlinedIntervals';
  @visibleForTesting
  static const kInlinedFunctions = '_inlinedFunctions';
  @visibleForTesting
  static const kStartAddressKey = '_startAddress';

  final List<InliningEntry> entries;
}

class InliningEntry {
  const InliningEntry({
    required this.addressRange,
    required this.functions,
  });

  final Range addressRange;
  final List<FuncRef> functions;
}

class ObjectPoolRef extends ObjRef {
  ObjectPoolRef({
    required Map<String, dynamic> json,
    required super.id,
    required this.length,
  }) {
    super.json = json;
  }

  static const _idKey = 'id';
  static const _lengthKey = 'length';

  static ObjectPoolRef parse(Map<String, dynamic> json) => ObjectPoolRef(
        id: json[_idKey],
        length: json[_lengthKey],
        json: json,
      );

  final int length;
}

class ObjectPool extends ObjectPoolRef implements Obj {
  ObjectPool({
    required super.json,
    required super.id,
    required this.entries,
    required super.length,
  });

  static const _entriesKey = '_entries';

  static ObjectPool parse(Map<String, dynamic> json) {
    return ObjectPool(
      json: json,
      id: json[ObjectPoolRef._idKey],
      entries: (json[_entriesKey] as List)
          .map((e) => ObjectPoolEntry.parse(e))
          .toList(),
      length: json[ObjectPoolRef._lengthKey],
    );
  }

  @override
  String get type => 'ObjectPool';

  @override
  ClassRef? classRef;

  @override
  int? size;

  List<ObjectPoolEntry> entries;
}

enum ObjectPoolEntryKind {
  object,
  immediate,
  nativeFunction;

  static const _kObject = 'Object';
  static const _kImm = 'Immediate';
  static const _kNativeFunction = 'NativeFunction';

  static ObjectPoolEntryKind fromString(String type) {
    switch (type) {
      case _kObject:
        return object;
      case _kImm:
        return immediate;
      case _kNativeFunction:
        return nativeFunction;
      default:
        throw UnsupportedError('Unsupported ObjectPoolType: $type');
    }
  }

  @override
  String toString() {
    switch (this) {
      case object:
        return _kObject;
      case immediate:
        return _kImm;
      case nativeFunction:
        return 'Native Function';
    }
  }
}

class ObjectPoolEntry {
  const ObjectPoolEntry({
    required this.offset,
    required this.kind,
    required this.value,
  });

  static const _offsetKey = 'offset';
  static const _kindKey = 'kind';
  static const _valueKey = 'value';

  static ObjectPoolEntry parse(Map<String, dynamic> json) => ObjectPoolEntry(
        offset: json[_offsetKey],
        kind: ObjectPoolEntryKind.fromString(json[_kindKey]),
        value: createServiceObject(json[_valueKey], [])!,
      );

  final int offset;

  final ObjectPoolEntryKind kind;

  final Object value;
}

/// An extension on [Field] which allows for access to VM internal fields.
extension FieldPrivateViewExtension on Field {
  static const _guardClassKey = '_guardClass';

  bool? get guardNullable => json!['_guardNullable'];

  Future<Class?> get guardClass async {
    if (_guardClassIsClass()) {
      final service = serviceConnection.serviceManager.service!;
      final isolate =
          serviceConnection.serviceManager.isolateManager.selectedIsolate.value;

      return await service.getObject(
        isolate!.id!,
        guardClassData['id'] as String,
      ) as Class;
    }

    return null;
  }

  GuardClassKind? guardClassKind() {
    if (_guardClassIsClass()) {
      return GuardClassKind.single;
    } else if (json![_guardClassKey] == GuardClassKind.dynamic.jsonValue()) {
      return GuardClassKind.dynamic;
    } else if (json![_guardClassKey] == GuardClassKind.unknown.jsonValue()) {
      return GuardClassKind.unknown;
    }

    return null;
  }

  bool _guardClassIsClass() {
    String? guardClassType;

    if (json![_guardClassKey] is Map) {
      guardClassType = guardClassData['type'] as String?;
    }

    return guardClassType == '@Class' || guardClassType == 'Class';
  }

  Map<String, Object?> get guardClassData =>
      (json![_guardClassKey] as Map).cast<String, Object?>();
}

/// The kinds of Guard Class that determine whether a Field object has
/// a unique observed type [single], various observed types [dynamic],
/// or if the field type has not been observed yet [unknown].
enum GuardClassKind {
  single,
  dynamic,
  unknown;

  String jsonValue() {
    switch (this) {
      case GuardClassKind.dynamic:
        return 'various';
      case GuardClassKind.single:
      case GuardClassKind.unknown:
        return toString().split('.').last;
    }
  }
}

/// An extension on [Script] which allows for access to VM internal fields.
extension ScriptPrivateViewExtension on Script {
  static const _loadTimeKey = '_loadTime';
  int get loadTime => json![_loadTimeKey]!;
}

/// An extension on [Library] which allows for access to VM internal fields.
extension LibraryPrivateExtension on Library {
  String? get vmName => json![_vmNameKey];
}

typedef ObjectStoreEntry = MapEntry<String, ObjRef>;

/// A collection of VM objects stored in an isolate's object store.
///
/// The object store is used to provide easy and cheap access to important
/// VM objects within the VM. Examples of objects stored in the object store
/// include:
///
///   - Code stubs (e.g., allocation paths, async/await machinery)
///   - References to core classes (e.g., `Null`, `Object`, `Never`)
///   - Common type arguments (e.g., `<String, dynamic>`)
///   - References to frequently accessed fields / functions (e.g.,
///     `_objectEquals()`, `_Enum._name`)
///   - Cached, per-isolate data (e.g., library URI mappings)
///
/// The object store is considered one of the GC roots by the VM's garbage
/// collector, meaning that objects in the store will be considered live, even
/// if they're not referenced anywhere else in the program.
class ObjectStore {
  const ObjectStore({
    required this.fields,
  });

  static ObjectStore? parse(Map<String, dynamic>? json) {
    if (json?['type'] != '_ObjectStore') {
      return null;
    }
    final rawFields = json!['fields']! as Map<String, dynamic>;
    return ObjectStore(
      fields: rawFields.map((key, value) {
        return ObjectStoreEntry(
          key,
          createServiceObject(value, ['InstanceRef']) as ObjRef,
        );
      }),
    );
  }

  final Map<String, ObjRef> fields;
}

/// A `ProfileCode` contains profiling information about a Dart or native
/// code object.
///
/// See [CpuSamples].
class ProfileCode {
  ProfileCode({
    this.kind,
    this.inclusiveTicks,
    this.exclusiveTicks,
    this.code,
    this.ticks,
  });

  ProfileCode._fromJson(Map<String, dynamic> json) {
    kind = json['kind'] ?? '';
    inclusiveTicks = json['inclusiveTicks'] ?? -1;
    exclusiveTicks = json['exclusiveTicks'] ?? -1;
    code = createServiceObject(json['code'], const ['@Code']) as CodeRef?;
    ticks = json['ticks'];
  }
  static ProfileCode? parse(Map<String, dynamic>? json) =>
      json == null ? null : ProfileCode._fromJson(json);

  /// The kind of function this object represents.
  String? kind;

  /// The number of times function appeared on the stack during sampling events.
  int? inclusiveTicks;

  /// The number of times function appeared on the top of the stack during
  /// sampling events.
  int? exclusiveTicks;

  /// The function captured during profiling.
  CodeRef? code;

  List? ticks;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{};
    json.addAll({
      'kind': kind ?? '',
      'inclusiveTicks': inclusiveTicks ?? -1,
      'exclusiveTicks': exclusiveTicks ?? -1,
      'code': code?.toJson(),
      'ticks': ticks,
    });
    return json;
  }

  @override
  String toString() => '[ProfileCode ' //
      'kind: $kind, inclusiveTicks: $inclusiveTicks, exclusiveTicks: $exclusiveTicks, ' //
      'code: $code]';
}

extension CpuSamplePrivateView on CpuSample {
  static final _expando = Expando<List<int>>();

  List<int> get codeStack => _expando[this] ?? [];
  void setCodeStack(List<int> stack) => _expando[this] = stack;
}

extension CpuSamplesPrivateView on CpuSamples {
  // Used to attach the codes list to a CpuSamples instance.
  static final _expando = Expando<List<ProfileCode>>();

  static const _kCodesKey = '_codes';

  bool get hasCodes {
    return _expando[this] != null || json!.containsKey(_kCodesKey);
  }

  List<ProfileCode> get codes {
    return _expando[this] ??= (json![_kCodesKey] as List)
        .cast<Map<String, dynamic>>()
        .map<ProfileCode>((e) => ProfileCode.parse(e)!)
        .toList();
  }
}

extension ProfileDataRanges on SourceReport {
  ProfileReport asProfileReport(Script script) =>
      ProfileReport._fromJson(script, json!);
}

/// Profiling information for a given line in a [Script].
class ProfileReportEntry {
  const ProfileReportEntry({
    required this.sampleCount,
    required this.line,
    required this.inclusive,
    required this.exclusive,
  });

  final int sampleCount;
  final int line;
  final int inclusive;
  final int exclusive;

  double get inclusivePercentage => inclusive * 100 / sampleCount;
  double get exclusivePercentage => exclusive * 100 / sampleCount;
}

/// Profiling information for a range of token positions in a [Script].
class ProfileReportRange {
  ProfileReportRange._fromJson(Script script, _ProfileReportRangeJson json) {
    final inclusiveTicks = json.inclusiveTicks;
    final exclusiveTicks = json.exclusiveTicks;
    final lines = json.positions
        .map<int>(
          // It's possible to get a synthetic token position which will either
          // be a negative value or a String (e.g., 'ParallelMove' or
          // 'NoSource'). We'll just use -1 as a placeholder since we won't
          // display anything for these tokens anyway.
          (e) => e is int
              ? script.getLineNumberFromTokenPos(e) ?? _kNoSourcePosition
              : _kNoSourcePosition,
        )
        .toList();
    for (int i = 0; i < lines.length; ++i) {
      final line = lines[i];
      // In a `Map<int, ProfileReportEntry>`, we're mapping an `int` to a
      // `ProfileReportEntry`. No bug.
      // ignore: avoid-collection-methods-with-unrelated-types
      entries[line] = ProfileReportEntry(
        sampleCount: json.sampleCount,
        line: line,
        inclusive: inclusiveTicks[i],
        exclusive: exclusiveTicks[i],
      );
    }
  }

  static const _kNoSourcePosition = -1;

  final entries = <int, ProfileReportEntry>{};
}

/// An extension type for the unstructured data in the 'ranges' data of the
/// profiling information used in [ProfileReport].
extension type _ProfileReportRangeJson(Map<String, dynamic> json) {
  Map<String, Object?> get _profile => json[_kProfileKey];
  Map<String, Object?> get metadata =>
      (_profile[_kMetadataKey] as Map).cast<String, Object?>();
  int get sampleCount => metadata[_kSampleCountKey] as int;
  List<int> get inclusiveTicks =>
      (_profile[_kInclusiveTicksKey] as List).cast<int>();
  List<int> get exclusiveTicks =>
      (_profile[_kExclusiveTicksKey] as List).cast<int>();
  List<Object?> get positions => _profile[_kPositionsKey] as List;

  static const _kProfileKey = 'profile';
  static const _kMetadataKey = 'metadata';
  static const _kSampleCountKey = 'sampleCount';
  static const _kInclusiveTicksKey = 'inclusiveTicks';
  static const _kExclusiveTicksKey = 'exclusiveTicks';
  static const _kPositionsKey = 'positions';
}

/// A representation of the `_Profile` [SourceReport], which contains profiling
/// information for a given [Script].
class ProfileReport {
  ProfileReport._fromJson(Script script, Map<String, dynamic> json)
      : _profileRanges = (json['ranges'] as List)
            .cast<Map<String, dynamic>>()
            .where((e) => e.containsKey('profile'))
            .map<ProfileReportRange>(
              (e) => ProfileReportRange._fromJson(
                script,
                _ProfileReportRangeJson(e),
              ),
            )
            .toList();

  List<ProfileReportRange> get profileRanges => _profileRanges;
  final List<ProfileReportRange> _profileRanges;
}
