// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../shared/globals.dart';

/// NOTE: this file contains extensions to classes provided by
/// `package:vm_service` in order to expose VM internal fields in a controlled
/// fashion. Objects and extensions in this class should not be used in
/// contexts where [PreferencesController.vmDeveloperModeEnabled] is not set to
/// `true`.

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
  String get vmName => json!['_vmName'];
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

/// An extension on [ObjRef] which allows for access to VM internal fields.
extension ObjRefPrivateViewExtension on ObjRef {
  static const _icDataType = 'ICData';

  /// The internal type of the object.
  ///
  /// The type of non-public service objects can be determined using this
  /// value.
  String? get vmType => json!['_vmType'];

  /// `true` if this object is an instance of [ICData].
  bool get isICData => vmType == _icDataType;

  /// Casts the current [ObjRef] into an instance of [ICData].
  ICData get asICData => ICData.parse(json!);
}

/// A representation of the Dart VM's Inline Cache (IC).
///
/// For more information:
///  - [Slava's Dart VM intro](https://mrale.ph/dartvm/)
///  - [Dart VM implementation](https://github.com/dart-lang/sdk/blob/2d064faf748d6c7700f08d223fb76c84c4335c5f/runtime/vm/raw_object.h#L2103)
class ICData {
  ICData.parse(Map<String, dynamic> json) : selector = json['_selector'];

  final String selector;
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
    if (rawObject['type'].contains('Instance')) {
      object = InstanceRef.parse(rawObject);
    } else {
      object = createServiceObject(data[3], const <String>[]) as ObjRef;
    }
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

    if (guardClassType == '@Class' || guardClassType == 'Class') {
      return true;
    } else {
      return false;
    }
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
