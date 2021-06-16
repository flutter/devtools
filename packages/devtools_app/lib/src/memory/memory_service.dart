// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:vm_service/vm_service.dart';

import '../config_specific/logger/logger.dart';
import '../globals.dart';

// TODO(terry): This file prints out fatal errors.  Unable to use ga.error
// TODO(terry): because of dart:js usage.  Look at abstracting errors to a log
// TODO(terry): and fatal errors are eventually sent to analytics.

String get _isolateId => serviceManager.isolateManager.selectedIsolate.value.id;

Future<InstanceRef> evaluate(String objectRef, String expression) async {
  final dynamic result =
      await serviceManager.service.evaluate(_isolateId, objectRef, expression);
  switch (result.runtimeType) {
    case InstanceRef:
      return InstanceRef.parse(result.json);
      break;
    case ErrorRef:
      return null;
    default:
      log(
        'Memory evaluate: Unknown type ${result.runtimeType}.',
        LogLevel.error,
      );
  }

  return null;
}

Future<InboundReferences> getInboundReferences(
    String objectRef, int maxInstances) async {
  // TODO(terry): Expose a stream to reduce stalls querying 1000s of instances.
  final Response response = await serviceManager.service
      .getInboundReferences(_isolateId, objectRef, maxInstances);

  if (response.type == 'Sentinel') return null;

  return InboundReferences(response.json);
}

class InboundReferences extends Response {
  InboundReferences(Map<String, dynamic> json) {
    elements = json['references']
        .map<InboundReference>((rmap) => InboundReference.parse(rmap))
        .toList();
  }

  Iterable<InboundReference> elements;
}

class InboundReference extends Response {
  InboundReference._fromJson(Map<String, dynamic> json) {
    //source = json['source']
    parentField = createServiceObject(json['parentField'], ['FieldRef']);
    parentListIndex = json['parentListIndex'];
    parentWordOffset = json['_parentWordOffset'];
  }

  static InboundReference parse(Map<String, dynamic> json) {
    return json == null ? null : InboundReference._fromJson(json);
  }

  dynamic parentField;

  int parentListIndex;

  int parentWordOffset;

  bool get isFieldRef => parentField.runtimeType == FieldRef;

  FieldRef get fieldRef => isFieldRef ? parentField as FieldRef : null;

  bool get isClassRef => parentField.runtimeType == ClassRef;

  ClassRef get classRef => isFieldRef ? parentField as ClassRef : null;

  bool get isFuncRef => parentField.runtimeType == FuncRef;

  FuncRef get funcRef => isFuncRef ? parentField as FuncRef : null;

  bool get isNullVal => parentField.runtimeType == NullVal;

  bool get isNullValRef => parentField.runtimeType == NullValRef;

  NullVal get nullVal => isInstanceRef ? parentField as NullVal : null;

  bool get isInstance => parentField.runtimeType == Instance;

  Instance get instance => isInstance ? parentField as Instance : null;

  bool get isInstanceRef => parentField.runtimeType == InstanceRef;

  InstanceRef get instanceRef =>
      isInstanceRef ? parentField as InstanceRef : null;

  bool get isLibrary => parentField.runtimeType == Library;

  bool get isLibraryRef => parentField.runtimeType == LibraryRef;

  Library get library => isLibrary ? parentField as Library : null;

  bool get isObj => parentField.runtimeType == Obj;

  bool get isObjRef => parentField.runtimeType == ObjRef;

  Obj get obj => isObj ? parentField as Obj : null;

  bool get isSentinel => parentField.runtimeType == Sentinel;
}

typedef BuildInboundEntry = void Function(
  String referenceName,
  /* Field that owns reference to allocated memory */
  String owningAllocator,
  /* Parent class that allocated memory. */
  bool owningAllocatorIsAbstract,
  /* is owning class abstract */
);

ClassHeapDetailStats _searchClass(
  List<ClassHeapDetailStats> allClasses,
  String className,
) =>
    allClasses.firstWhere((dynamic stat) => stat.classRef.name == className,
        orElse: () => null);

// Compute the inboundRefs, who allocated the class/which field owns the ref.
void computeInboundRefs(
  List<ClassHeapDetailStats> allClasses,
  InboundReferences refs,
  BuildInboundEntry buildCallback,
) {
  final Iterable<InboundReference> elements = refs?.elements ?? [];
  for (InboundReference element in elements) {
    // Could be a reference to an evaluate so this isn't known.

    // Looks like an object created from an evaluate, ignore it.
    if (element.parentField == null && element.json == null) continue;

    // TODO(terry): Verify looks like internal class (maybe to C code).
    if (element.parentField.owner != null &&
        element.parentField.owner.name.contains('&')) continue;

    String referenceName;
    String owningAllocator; // Class or library that allocated.
    bool owningAllocatorIsAbstract;

    switch (element.parentField.runtimeType.toString()) {
      case 'ClassRef':
        final ClassRef classRef = element.classRef;
        owningAllocator = classRef.name;
        // TODO(terry): Quick way to detect if class is probably abstract-
        // TODO(terry): Does it exist in the class list table?
        owningAllocatorIsAbstract =
            _searchClass(allClasses, owningAllocator) == null;
        break;
      case 'FieldRef':
        final FieldRef fieldRef = element.fieldRef;
        referenceName = fieldRef.name;
        switch (fieldRef.owner.runtimeType.toString()) {
          case 'ClassRef':
            final ClassRef classRef = ClassRef.parse(fieldRef.owner.json);
            owningAllocator = classRef.name;
            // TODO(terry): Quick way to detect if class is probably abstract-
            // TODO(terry): Does it exist in the class list table?
            owningAllocatorIsAbstract =
                _searchClass(allClasses, owningAllocator) == null;
            break;
          case 'Library':
          case 'LibraryRef':
            final Library library = Library.parse(fieldRef.owner.json);
            owningAllocator = 'Library ${library?.name ?? ""}';
            break;
        }
        break;
      case 'FuncRef':
        _hoverInstanceAllocationsUnhandledTypeError(
          element.parentField.runtimeType,
        );
        // TODO(terry): TBD
        // final FuncRef funcRef = element.funcRef;
        break;
      case 'Instance':
        _hoverInstanceAllocationsUnhandledTypeError(
          element.parentField.runtimeType,
        );
        // TODO(terry): TBD
        // final Instance instance = element.instance;
        break;
      case 'InstanceRef':
        _hoverInstanceAllocationsUnhandledTypeError(
          element.parentField.runtimeType,
        );
        // TODO(terry): TBD
        // final InstanceRef instanceRef = element.instanceRef;
        break;
      case 'Library':
      case 'LibraryRef':
        _hoverInstanceAllocationsUnhandledTypeError(
          element.parentField.runtimeType,
        );
        // TODO(terry): TBD
        // final Library library = element.library;
        break;
      case 'NullVal':
      case 'NullValRef':
        _hoverInstanceAllocationsUnhandledTypeError(
          element.parentField.runtimeType,
        );
        // TODO(terry): TBD
        // final NullVal nullValue = element.nullVal;
        break;
      case 'Obj':
      case 'ObjRef':
        _hoverInstanceAllocationsUnhandledTypeError(
          element.parentField.runtimeType,
        );
        // TODO(terry): TBD
        // final Obj obj = element.obj;
        break;
      default:
        _hoverInstanceAllocationsUnhandledTypeError(
          element.parentField.runtimeType,
        );
    }

    // call the build UI callback.
    if (buildCallback != null) {
      buildCallback(
        referenceName,
        owningAllocator,
        owningAllocatorIsAbstract,
      );
    }
  }
}

void _hoverInstanceAllocationsUnhandledTypeError(Type runtimeType) {
  log('hoverInstanceAllocations: Unhandled $runtimeType', LogLevel.error);
}
