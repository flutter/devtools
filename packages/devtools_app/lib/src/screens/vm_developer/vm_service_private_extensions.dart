// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../shared/globals.dart';
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
  Map<String, dynamic> get tagCounters => json!['_tagCounters'];

  int get dartHeapSize => newSpaceUsage + oldSpaceUsage;
  int get dartHeapCapacity => newSpaceCapacity + oldSpaceCapacity;

  int get newSpaceUsage => json!['_heaps']['new']['used'];
  int get oldSpaceUsage => json!['_heaps']['old']['used'];

  int get newSpaceCapacity => json!['_heaps']['new']['capacity'];
  int get oldSpaceCapacity => json!['_heaps']['old']['capacity'];
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
    return json![_referencesKey]?[inboundReferenceIndex]?[_parentWordOffsetKey];
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
      ? HeapStats.parse(json![_newSpaceKey].cast<int>())
      : const HeapStats.empty();
  HeapStats get oldSpace => json!.containsKey(_oldSpaceKey)
      ? HeapStats.parse(json![_oldSpaceKey].cast<int>())
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

  GCStats.parse({required this.heap, required Map<String, dynamic> json})
      : usage = json[usedKey],
        capacity = json[capacityKey],
        collections = json[collectionsKey] {
    averageCollectionTime = json[timeKey] * 1000 / collections;
  }

  static const usedKey = 'used';
  static const capacityKey = 'capacity';
  static const collectionsKey = 'collections';
  static const timeKey = 'time';

  final String heap;
  final int usage;
  final int capacity;
  final int collections;
  late final double averageCollectionTime;
}

extension AllocationProfilePrivateViewExtension on AllocationProfile {
  static const heapsKey = '_heaps';
  static const newSpaceKey = 'new';
  static const oldSpaceKey = 'old';

  GCStats get newSpaceGCStats => GCStats.parse(
        heap: HeapGeneration.newSpace.toString(),
        json: json![heapsKey][newSpaceKey],
      );

  GCStats get oldSpaceGCStats => GCStats.parse(
        heap: HeapGeneration.oldSpace.toString(),
        json: json![heapsKey][oldSpaceKey],
      );

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

  /// The internal type of the object.
  ///
  /// The type of non-public service objects can be determined using this
  /// value.
  String? get vmType => json!['_vmType'];

  /// `true` if this object is an instance of [ICDataRef].
  bool get isICData => vmType == _icDataType;

  /// Casts the current [ObjRef] into an instance of [ICDataRef].
  ICDataRef get asICData => ICDataRef.parse(json!)!;
}

/// An extension on [Obj] which allows for access to VM internal fields.
extension ObjPrivateViewExtension on Obj {
  /// Casts the current [Obj] into an instance of [ICData].
  ICData get asICData => ICData.parse(json!)!;
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

  static ICDataRef? parse(Map<String, dynamic> json) => ICDataRef(
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

  static ICData? parse(Map<String, dynamic> json) => ICData(
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
    object = rawObject['type'].contains('Instance')
        ? InstanceRef.parse(rawObject)
        : createServiceObject(data[3], const <String>[]) as ObjRef;
  }

  /// The instruction's address in memory.
  final String address;

  /// TODO(bkonyi): figure out what this value is for.
  final String unknown;

  /// The [String] representation of the assembly instruction.
  final String instruction;

  /// The Dart object this instruction is acting upon directly.
  late final ObjRef? object;

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
    final String? icDataArrayId = json![_icDataArrayKey]?['id'];
    if (icDataArrayId != null) {
      final service = serviceManager.service!;
      final isolate = serviceManager.isolateManager.selectedIsolate.value;

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
    final functionJson = json![_functionKey] as Map<String, dynamic>;
    return FuncRef.parse(functionJson);
  }
}

/// An extension on [Code] which allows for access to VM internal fields.
extension CodePrivateViewExtension on Code {
  static const _disassemblyKey = '_disassembly';

  /// Returns the disassembly of the [Code], which is the generated assembly
  /// instructions for the code's function.
  Disassembly get disassembly => Disassembly.parse(json![_disassemblyKey]);
  set disassembly(Disassembly disassembly) =>
      json![_disassemblyKey] = disassembly.toJson();
}

/// An extension on [Field] which allows for access to VM internal fields.
extension FieldPrivateViewExtension on Field {
  static const _guardClassKey = '_guardClass';

  bool? get guardNullable => json!['_guardNullable'];

  Future<Class?> get guardClass async {
    if (_guardClassIsClass()) {
      final service = serviceManager.service!;
      final isolate = serviceManager.isolateManager.selectedIsolate.value;

      return await service.getObject(isolate!.id!, json![_guardClassKey]['id'])
          as Class;
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
      guardClassType = json![_guardClassKey]['type'];
    }

    return guardClassType == '@Class' || guardClassType == 'Class';
  }
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
    var _codes = _expando[this];
    if (_codes == null) {
      _codes = json![_kCodesKey]
          .cast<Map<String, dynamic>>()
          .map<ProfileCode>((e) => ProfileCode.parse(e)!)
          .toList();
      _expando[this] = _codes;
    }
    return _codes!;
  }
}

extension ProfileDataRanges on SourceReport {
  ProfileReport asProfileReport(Script script) =>
      ProfileReport._fromJson(script, json!);
}

class ProfileReportMetaData {
  const ProfileReportMetaData._({required this.sampleCount});
  final int sampleCount;
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
  ProfileReportRange._fromJson(Script script, Map<String, dynamic> json)
      : metadata = ProfileReportMetaData._(
          sampleCount: json[_kProfileKey][_kMetadataKey][_kSampleCountKey],
        ),
        inclusiveTicks = json[_kProfileKey][_kInclusiveTicksKey].cast<int>(),
        exclusiveTicks = json[_kProfileKey][_kExclusiveTicksKey].cast<int>(),
        lines = json[_kProfileKey][_kPositionsKey]
            .map<int>(
              // It's possible to get a synthetic token position which will
              // either be a negative value or a String (e.g., 'ParallelMove'
              // or 'NoSource'). We'll just use -1 as a placeholder since we
              // won't display anything for these tokens anyway.
              (e) => e is int
                  ? script.getLineNumberFromTokenPos(e) ?? _kNoSourcePosition
                  : _kNoSourcePosition,
            )
            .toList() {
    for (int i = 0; i < lines.length; ++i) {
      final line = lines[i];
      entries[line] = ProfileReportEntry(
        sampleCount: metadata.sampleCount,
        line: line,
        inclusive: inclusiveTicks[i],
        exclusive: exclusiveTicks[i],
      );
    }
  }

  static const _kProfileKey = 'profile';
  static const _kMetadataKey = 'metadata';
  static const _kSampleCountKey = 'sampleCount';
  static const _kInclusiveTicksKey = 'inclusiveTicks';
  static const _kExclusiveTicksKey = 'exclusiveTicks';
  static const _kPositionsKey = 'positions';
  static const _kNoSourcePosition = -1;

  final ProfileReportMetaData metadata;
  final entries = <int, ProfileReportEntry>{};
  List<int> inclusiveTicks;
  List<int> exclusiveTicks;
  List<int> lines;
}

/// A representation of the `_Profile` [SourceReport], which contains profiling
/// information for a given [Script].
class ProfileReport {
  ProfileReport._fromJson(Script script, Map<String, dynamic> json)
      : _profileRanges = (json['ranges'] as List)
            .cast<Map<String, dynamic>>()
            .where((e) => e.containsKey('profile'))
            .map<ProfileReportRange>(
              (e) => ProfileReportRange._fromJson(script, e),
            )
            .toList();

  List<ProfileReportRange> get profileRanges => _profileRanges;
  final List<ProfileReportRange> _profileRanges;
}
