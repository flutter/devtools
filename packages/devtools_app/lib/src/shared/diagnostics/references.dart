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
      // TODO: add references
      break;
    case InstanceKind.kClosure:
      // TODO: add references
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
