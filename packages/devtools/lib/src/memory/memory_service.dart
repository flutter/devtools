// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service_lib/vm_service_lib.dart';

import '../globals.dart';

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
      print('ERROR: Unknown evaluate type ${result.runtimeType}.');
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
    //source = json['source'],
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
