// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service/vm_service.dart';

import '../feature_flags.dart';
import '../primitives/utils.dart';
import 'dart_object_node.dart';
import 'generic_instance_reference.dart';
import 'helpers.dart';
import 'variable_factory.dart';

void addReferencesRoot(DartObjectNode variable, GenericInstanceRef ref) {
  variable.addChild(
    DartObjectNode.references(
      'references',
      ObjectReferences(
        refNodeType: RefNodeType.refRoot,
        value: ref.value,
        isolateRef: ref.isolateRef,
        heapSelection: ref.heapSelection,
      ),
    ),
    index: 0,
  );
}

Future<void> addChildReferences(
  DartObjectNode variable,
) async {
  assert(FeatureFlags.evalAndBrowse);
  final ref = variable.ref!;
  if (ref is! ObjectReferences) {
    throw StateError('Wrong type: ${ref.runtimeType}');
  }

  final refNodeType = ref.refNodeType;

  switch (refNodeType) {
    case RefNodeType.refRoot:
      variable.addAllChildren([
        DartObjectNode.references(
          'live',
          ObjectReferences.withType(ref, RefNodeType.liveRefRoot),
        ),
        DartObjectNode.references(
          'static',
          ObjectReferences.withType(ref, RefNodeType.staticRefRoot),
        ),
      ]);
      break;
    case RefNodeType.staticRefRoot:
      variable.addAllChildren([
        DartObjectNode.references(
          'inbound',
          ObjectReferences.withType(ref, RefNodeType.staticInRefs),
        ),
        DartObjectNode.references(
          'outbound',
          ObjectReferences.withType(ref, RefNodeType.staticOutRefs),
        ),
      ]);

      break;
    case RefNodeType.staticInRefs:
      final children = ref.heapSelection!
          .references(ref.refNodeType.direction!)
          .map(
            (s) => DartObjectNode.references(
              s.object.heapClass.className,
              ObjectReferences(
                refNodeType: RefNodeType.staticInRefs,
                heapSelection: s,
              ),
            ),
          )
          .toList();
      variable.addAllChildren(children);
      break;
    case RefNodeType.staticOutRefs:
      final children = ref.heapSelection!
          .references(ref.refNodeType.direction!)
          .map(
            (s) => DartObjectNode.references(
              '${s.object.heapClass.className}, ${prettyPrintRetainedSize(
                s.object.retainedSize,
              )}',
              ObjectReferences(
                refNodeType: RefNodeType.staticOutRefs,
                heapSelection: s,
              ),
            ),
          )
          .toList();
      variable.addAllChildren(children);
      break;
    case RefNodeType.liveRefRoot:
      variable.addAllChildren([
        DartObjectNode.references(
          'inbound',
          ObjectReferences.withType(ref, RefNodeType.liveInRefs),
        ),
        DartObjectNode.references(
          'outbound',
          ObjectReferences.withType(ref, RefNodeType.liveOutRefs),
        ),
      ]);

      break;
    case RefNodeType.liveInRefs:
      variable.addChild(
        DartObjectNode.references(
          // Temporary placeholder
          '<live inbound refs>',
          ObjectReferences.withType(ref, RefNodeType.liveInRefs),
        ),
      );
      break;
    case RefNodeType.liveOutRefs:
      final isolateRef = variable.ref!.isolateRef;
      final instance = await getObject(
        isolateRef: isolateRef,
        value: ref.instanceRef!,
        variable: variable,
      );

      if (instance is Instance) {
        await _addOutboundLiveReferences(
          variable: variable,
          value: instance,
          isolateRef: isolateRef,
        );
      }
      break;
  }
}

Future<void> _addOutboundLiveReferences({
  required DartObjectNode variable,
  required Instance value,
  required IsolateRef? isolateRef,
}) async {
  switch (value.kind) {
    case InstanceKind.kMap:
      variable.addAllChildren(
        _createLiveReferencesForMap(
          value,
          isolateRef,
        ),
      );
      break;
    case InstanceKind.kList:
      variable.addAllChildren(_createLiveReferencesForList(value, isolateRef));
      break;
    case InstanceKind.kRecord:
      variable.addAllChildren(
        createVariablesForRecords(value, isolateRef),
      );
      break;
    case InstanceKind.kUint8ClampedList:
    case InstanceKind.kUint8List:
    case InstanceKind.kUint16List:
    case InstanceKind.kUint32List:
    case InstanceKind.kUint64List:
    case InstanceKind.kInt8List:
    case InstanceKind.kInt16List:
    case InstanceKind.kInt32List:
    case InstanceKind.kInt64List:
    case InstanceKind.kFloat32List:
    case InstanceKind.kFloat64List:
    case InstanceKind.kInt32x4List:
    case InstanceKind.kFloat32x4List:
    case InstanceKind.kFloat64x2List:
      variable.addAllChildren(
        createVariablesForBytes(value, isolateRef),
      );
      break;
    case InstanceKind.kRegExp:
      variable.addAllChildren(
        createVariablesForRegExp(value, isolateRef),
      );
      break;
    case InstanceKind.kClosure:
      variable.addAllChildren(
        createVariablesForClosure(value, isolateRef),
      );
      break;
    case InstanceKind.kReceivePort:
      variable.addAllChildren(
        createVariablesForReceivePort(value, isolateRef),
      );
      break;
    case InstanceKind.kType:
      variable.addAllChildren(
        createVariablesForType(value, isolateRef),
      );
      break;
    case InstanceKind.kTypeParameter:
      variable.addAllChildren(
        createVariablesForTypeParameters(value, isolateRef),
      );
      break;
    case InstanceKind.kFunctionType:
      variable.addAllChildren(
        createVariablesForFunctionType(value, isolateRef),
      );
      break;
    case InstanceKind.kWeakProperty:
      variable.addAllChildren(
        createVariablesForWeakProperty(value, isolateRef),
      );
      break;
    case InstanceKind.kStackTrace:
      variable.addAllChildren(
        createVariablesForStackTrace(value, isolateRef),
      );
      break;
    default:
      break;
  }
  if (value.fields != null && value.kind != InstanceKind.kRecord) {
    variable.addAllChildren(
      _createLiveReferencesForFields(value, isolateRef),
    );
  }
}

void _addLiveReference(
  List<DartObjectNode> variables,
  IsolateRef? isolateRef,
  Object? instance,
  String namePrefix,
) {
  if (instance is! InstanceRef) return;
  if (isPrimativeInstanceKind(instance.kind)) return;

  variables.add(
    DartObjectNode.references(
      '$namePrefix${instance.classRef!.name}',
      ObjectReferences(
        refNodeType: RefNodeType.liveOutRefs,
        isolateRef: isolateRef,
        value: instance,
      ),
    ),
  );
}

List<DartObjectNode> _createLiveReferencesForMap(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final variables = <DartObjectNode>[];
  final associations = instance.associations ?? [];

  for (var i = 0; i < associations.length; i++) {
    final association = associations[i];

    _addLiveReference(
      variables,
      isolateRef,
      association.key,
      '[$i, key]',
    );
    _addLiveReference(
      variables,
      isolateRef,
      association.value,
      '[$i, val]', // `val`, not `value`, to align keys and values visually
    );
    continue;
  }
  return variables;
}

List<DartObjectNode> _createLiveReferencesForList(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final variables = <DartObjectNode>[];
  final elements = instance.elements ?? [];
  for (int i = 0; i < elements.length; i++) {
    final index = instance.offset == null ? i : i + instance.offset!;
    _addLiveReference(variables, isolateRef, elements[i], '[$index]');
  }
  return variables;
}

List<DartObjectNode> _createLiveReferencesForFields(
  Instance instance,
  IsolateRef? isolateRef,
) {
  final variables = <DartObjectNode>[];

  for (var field in instance.fields!) {
    _addLiveReference(
      variables,
      isolateRef,
      field.value,
      '${field.decl?.name}:',
    );
  }
  return variables;
}
