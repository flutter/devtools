// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:vm_service/vm_service.dart';

import '../feature_flags.dart';
import '../globals.dart';
import '../memory/adapted_heap_data.dart';
import '../memory/class_name.dart';
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
        isolateRef: ref.isolateRef!,
        heapSelection: ref.heapSelection!,
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
      if (ref.heapSelection.object == null) break;
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
      final children = ref.heapSelection
          .references(ref.refNodeType.direction!)
          .where((s) => !s.object!.heapClass.isNull)
          .map(
            (s) => DartObjectNode.references(
              s.object!.heapClass.className,
              ObjectReferences(
                refNodeType: RefNodeType.staticInRefs,
                heapSelection: s,
                isolateRef: ref.isolateRef,
                value: null,
              ),
              isRerootable: true,
            ),
          )
          .toList();
      variable.addAllChildren(children);
      break;
    case RefNodeType.staticOutRefs:
      final children = ref.heapSelection
          .references(ref.refNodeType.direction!)
          .where((s) => !s.object!.heapClass.isNull)
          .map(
            (s) => DartObjectNode.references(
              '${s.object!.heapClass.className}, ${prettyPrintRetainedSize(
                s.object!.retainedSize,
              )}',
              ObjectReferences(
                refNodeType: RefNodeType.staticOutRefs,
                heapSelection: s,
                isolateRef: ref.isolateRef,
                value: null,
              ),
              isRerootable: true,
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
      final limit = preferences.memory.refLimit.value;
      final refs = (await serviceManager.service!.getInboundReferences(
            ref.isolateRef.id!,
            ref.instanceRef!.id!,
            limit + 1,
          ))
              .references ??
          [];

      final refsToShow = min(limit, refs.length);

      for (var i = 0; i < refsToShow; i++) {
        final item = refs[i];
        variable.addChild(DartObjectNode.text(jsonEncode(item.toJson())));
      }

      if (refs.length > limit)
        variable.addChild(
          DartObjectNode.text(
            '...\nConfigure number of items in memory screen settings',
          ),
        );

      break;
    case RefNodeType.liveOutRefs:
      final isolateRef = ref.isolateRef;

      final instance = await getObject(
        isolateRef: isolateRef,
        value: ref.instanceRef!,
        variable: variable,
      );

      // ?????

      if (instance is Instance) {
        await _addOutboundLiveReferences(
          variable: variable,
          value: instance,
          isolateRef: isolateRef,
          heapSelection: ref.heapSelection,
        );
      }
      break;
  }
}

Future<void> _addOutboundLiveReferences({
  required DartObjectNode variable,
  required Instance value,
  required IsolateRef isolateRef,
  required HeapObjectSelection heapSelection,
}) async {
  switch (value.kind) {
    case InstanceKind.kMap:
      variable.addAllChildren(
        _createLiveReferencesForMap(
          value,
          isolateRef,
          HeapObjectSelection.withoutObject(heapSelection),
        ),
      );
      break;
    case InstanceKind.kList:
      variable.addAllChildren(
        _createLiveReferencesForList(
          value,
          isolateRef,
          HeapObjectSelection.withoutObject(heapSelection),
        ),
      );
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
      _createLiveReferencesForFields(
        value,
        isolateRef,
        HeapObjectSelection.withoutObject(heapSelection),
      ),
    );
  }
}

void _addLiveReference(
  List<DartObjectNode> variables,
  IsolateRef isolateRef,
  Object? instance,
  String namePrefix,
  HeapObjectSelection heapSelection,
) {
  if (instance is! InstanceRef) return;
  final classRef = instance.classRef!;
  if (HeapClassName.fromClassRef(classRef).isNull) return;

  variables.add(
    DartObjectNode.references(
      '$namePrefix${classRef.name}',
      ObjectReferences(
        refNodeType: RefNodeType.liveOutRefs,
        isolateRef: isolateRef,
        value: instance,
        heapSelection: heapSelection,
      ),
      isRerootable: true,
    ),
  );
}

List<DartObjectNode> _createLiveReferencesForMap(
  Instance instance,
  IsolateRef isolateRef,
  HeapObjectSelection heapSelection,
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
      HeapObjectSelection.withoutObject(heapSelection),
    );
    _addLiveReference(
      variables,
      isolateRef,
      association.value,
      '[$i, val]', // `val`, not `value`, to align keys and values visually
      HeapObjectSelection.withoutObject(heapSelection),
    );
    continue;
  }
  return variables;
}

List<DartObjectNode> _createLiveReferencesForList(
  Instance instance,
  IsolateRef isolateRef,
  HeapObjectSelection heapSelection,
) {
  final variables = <DartObjectNode>[];
  final elements = instance.elements ?? [];
  for (int i = 0; i < elements.length; i++) {
    final index = instance.offset == null ? i : i + instance.offset!;
    _addLiveReference(
      variables,
      isolateRef,
      elements[i],
      '[$index]',
      HeapObjectSelection.withoutObject(heapSelection),
    );
  }
  return variables;
}

List<DartObjectNode> _createLiveReferencesForFields(
  Instance instance,
  IsolateRef isolateRef,
  HeapObjectSelection heapSelection,
) {
  final variables = <DartObjectNode>[];

  for (var field in instance.fields!) {
    _addLiveReference(
      variables,
      isolateRef,
      field.value,
      '${field.decl?.name}:',
      HeapObjectSelection.withoutObject(heapSelection),
    );
  }
  return variables;
}
