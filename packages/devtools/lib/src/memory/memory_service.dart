// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service_lib/vm_service_lib.dart';

import '../globals.dart';
import 'memory_protocol.dart';

// TODO(terry): This file prints out fatal errors.  Unable to use ga.error
// TODO(terry): because of dart:js usage.  Look at abstracting errors to a log
// TODO(terry): and fatal errors are eventually sent to analytics.

String get _isolateId => serviceManager.isolateManager.selectedIsolate.id;

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
      print('ERROR Memory evaluate: Unknown type ${result.runtimeType}.');
  }

  return null;
}

Future<InboundReferences> getInboundReferences(
    String objectRef, int maxInstances) async {
  // TODO(terry): Expose as a stream to reduce stall when querying for 1000s
  // TODO(terry): of instances.
  final Map params = {
    'targetId': objectRef,
    'limit': maxInstances,
  };
  final Response response = await serviceManager.service.callMethod(
    '_getInboundReferences',
    isolateId: _isolateId,
    args: params,
  );

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
    // For vm_service_lib 3.21.1, use ['ObjRef']?
    parentField = createServiceObject(json['parentField']);
    parentListIndex = json['parentListIndex'];
    parentWordOffset = json['_parentWordOffset'];
  }

  static InboundReference parse(Map<String, dynamic> json) {
    return json == null ? null : new InboundReference._fromJson(json);
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

typedef BuildHoverCard = void Function(
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
  BuildHoverCard buildCallback,
) {
  for (InboundReference element in refs.elements) {
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
        print(
          'Error(hoverInstanceAllocations): '
          'Unhandled ${element.parentField.runtimeType}',
        );
        // TODO(terry): TBD
        // final FuncRef funcRef = element.funcRef;
        break;
      case 'Instance':
        print(
          'Error(hoverInstanceAllocations): '
          ' Unhandled ${element.parentField.runtimeType}',
        );
        // TODO(terry): TBD
        // final Instance instance = element.instance;
        break;
      case 'InstanceRef':
        print(
          'Error(hoverInstanceAllocations): '
          'Unhandled ${element.parentField.runtimeType}',
        );
        // TODO(terry): TBD
        // final InstanceRef instanceRef = element.instanceRef;
        break;
      case 'Library':
      case 'LibraryRef':
        print(
          'Error(hoverInstanceAllocations): '
          'Unhandled ${element.parentField.runtimeType}',
        );
        // TODO(terry): TBD
        // final Library library = element.library;
        break;
      case 'NullVal':
      case 'NullValRef':
        print(
          'Error(hoverInstanceAllocations): '
          'Unhandled ${element.parentField.runtimeType}',
        );
        // TODO(terry): TBD
        // final NullVal nullValue = element.nullVal;
        break;
      case 'Obj':
      case 'ObjRef':
        print(
          'Error(hoverInstanceAllocations): '
          'Unhandled ${element.parentField.runtimeType}',
        );
        // TODO(terry): TBD
        // final Obj obj = element.obj;
        break;
      default:
        print(
          'Error(hoverInstanceAllocations): '
          'Unhandled inbound ${element.parentField.runtimeType}',
        );
    }

    // call the build UI callback.
    if (buildCallback != null)
      buildCallback(
        referenceName,
        owningAllocator,
        owningAllocatorIsAbstract,
      );
  }
}
