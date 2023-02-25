// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
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

HeapObjectSelection _refreshStaticSelection(
  HeapObjectSelection selection,
  InstanceRef? liveObject,
) {
  if (selection.object != null) return selection;
  if (liveObject == null) return selection.withoutObject();

  final code = liveObject.identityHashCode;
  if (code == null) return selection.withoutObject();

  final index = selection.heap.objectIndexByIdentityHashCode(code);
  if (index == null) return selection.withoutObject();

  return HeapObjectSelection(
    selection.heap,
    object: selection.heap.objects[index],
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
      final selection =
          _refreshStaticSelection(ref.heapSelection, ref.instanceRef);

      variable.addAllChildren([
        DartObjectNode.references(
          'live (objects currently alive in the application)',
          ObjectReferences.copyWith(
            ref,
            refNodeType: RefNodeType.liveRefRoot,
            heapSelection: selection,
          ),
        ),
        if (selection.object != null)
          DartObjectNode.references(
            'static (objects alive at the time of snapshot ${selection.heap.snapshotName})',
            ObjectReferences.copyWith(
              ref,
              refNodeType: RefNodeType.staticRefRoot,
              heapSelection: selection,
            ),
          ),
      ]);
      break;
    case RefNodeType.staticRefRoot:
      if (ref.heapSelection.object == null) break;
      variable.addAllChildren([
        DartObjectNode.references(
          'inbound',
          ObjectReferences.copyWith(ref, refNodeType: RefNodeType.staticInRefs),
        ),
        DartObjectNode.references(
          'outbound',
          ObjectReferences.copyWith(
            ref,
            refNodeType: RefNodeType.staticOutRefs,
          ),
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
          ObjectReferences.copyWith(ref, refNodeType: RefNodeType.liveInRefs),
        ),
        DartObjectNode.references(
          'outbound',
          ObjectReferences.copyWith(ref, refNodeType: RefNodeType.liveOutRefs),
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
      final children = <DartObjectNode>[];

      for (var i = 0; i < refsToShow; i++) {
        final item = refs[i];

        _addLiveReferenceToNode(
          children,
          ref.isolateRef,
          item.source,
          RefNodeType.liveInRefs,
          ref.heapSelection.withoutObject(),
        );
      }

      variable.addAllChildren(children);

      if (refs.length > limit)
        variable.addChild(
          DartObjectNode.text(
            '...\nTo get more items, increase "${preferences.memory.refLimitTitle}" in memory settings.',
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
        _createLiveOutboundReferencesForMap(
          value,
          isolateRef,
          heapSelection.withoutObject(),
        ),
      );
      break;
    case InstanceKind.kList:
      variable.addAllChildren(
        _createLiveOutboundReferencesForList(
          value,
          isolateRef,
          heapSelection.withoutObject(),
        ),
      );
      break;
    case InstanceKind.kRecord:
      // TODO: add references
      break;
    case InstanceKind.kClosure:
      break;
    default:
      break;
  }

  if (value.fields != null && value.kind != InstanceKind.kRecord) {
    variable.addAllChildren(
      _createLiveReferencesForFields(
        value,
        isolateRef,
        heapSelection.withoutObject(),
      ),
    );
  }
}

void _addLiveReferenceToNode(
  List<DartObjectNode> variables,
  IsolateRef isolateRef,
  Object? instance,
  RefNodeType refNodeType,
  HeapObjectSelection heapSelection, {
  String namePrefix = '',
}) {
  if (instance is! InstanceRef) return;
  final classRef = instance.classRef!;
  if (HeapClassName.fromClassRef(classRef).isNull) return;

  variables.add(
    DartObjectNode.references(
      '$namePrefix${classRef.name}',
      ObjectReferences(
        refNodeType: refNodeType,
        isolateRef: isolateRef,
        value: instance,
        heapSelection: heapSelection,
      ),
      isRerootable: true,
    ),
  );
}

List<DartObjectNode> _createLiveOutboundReferencesForMap(
  Instance instance,
  IsolateRef isolateRef,
  HeapObjectSelection heapSelection,
) {
  final variables = <DartObjectNode>[];
  final associations = instance.associations ?? [];

  for (var i = 0; i < associations.length; i++) {
    final association = associations[i];

    _addLiveReferenceToNode(
      variables,
      isolateRef,
      association.key,
      RefNodeType.liveOutRefs,
      heapSelection.withoutObject(),
      namePrefix: '[$i, key]',
    );
    _addLiveReferenceToNode(
      variables,
      isolateRef,
      association.value,
      RefNodeType.liveOutRefs,
      heapSelection.withoutObject(),
      namePrefix:
          '[$i, val]', // `val`, not `value`, to align keys and values visually
    );
    continue;
  }
  return variables;
}

List<DartObjectNode> _createLiveOutboundReferencesForList(
  Instance instance,
  IsolateRef isolateRef,
  HeapObjectSelection heapSelection,
) {
  final variables = <DartObjectNode>[];
  final elements = instance.elements ?? [];
  for (int i = 0; i < elements.length; i++) {
    final index = instance.offset == null ? i : i + instance.offset!;
    _addLiveReferenceToNode(
      variables,
      isolateRef,
      elements[i],
      RefNodeType.liveOutRefs,
      heapSelection.withoutObject(),
      namePrefix: '[$index]',
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
    _addLiveReferenceToNode(
      variables,
      isolateRef,
      field.value,
      RefNodeType.liveOutRefs,
      heapSelection.withoutObject(),
      namePrefix: '${field.decl?.name}:',
    );
  }
  return variables;
}
