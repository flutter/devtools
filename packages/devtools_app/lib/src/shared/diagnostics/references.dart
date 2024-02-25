// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:vm_service/vm_service.dart';

import '../../../devtools_app.dart';
import '../memory/adapted_heap_data.dart';
import '../memory/class_name.dart';
import 'dart_object_node.dart';
import 'generic_instance_reference.dart';
import 'helpers.dart';
import 'primitives/record_fields.dart';

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

HeapObjectSelection_ _refreshStaticSelection(
  HeapObjectSelection_ selection,
  InstanceRef? liveObject,
) {
  if (selection.object != null) return selection;
  if (liveObject == null) return selection.withoutObject();

  final code = liveObject.identityHashCode;
  if (code == null) return selection.withoutObject();

  final index = selection.heap.objectIndexByIdentityHashCode(code);
  if (index == null) return selection.withoutObject();

  return HeapObjectSelection_(
    selection.heap,
    object: selection.heap.objects[index],
  );
}

Future<void> addChildReferences(
  DartObjectNode variable,
) async {
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
        if (ref.instanceRef != null)
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
      return;
    case RefNodeType.staticRefRoot:
      if (ref.heapSelection.object == null) return;
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

      return;
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
      return;
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
      return;
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

      return;
    case RefNodeType.liveInRefs:
      final value = ref.value;
      if (value is! InstanceRef) {
        return;
      }
      final limit = preferences.memory.refLimit.value;
      final refs =
          (await serviceConnection.serviceManager.service!.getInboundReferences(
                ref.isolateRef.id!,
                value.id!,
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

      if (refs.length > limit) {
        variable.addChild(
          DartObjectNode.text(
            '...\nTo get more items, increase "${preferences.memory.refLimitTitle}" in memory settings.',
          ),
        );
      }

      return;
    case RefNodeType.liveOutRefs:
      final isolateRef = ref.isolateRef;

      final instance = await getObject(
        isolateRef: isolateRef,
        value: ref.instanceRef!,
      );

      if (instance is Instance) {
        await _addOutboundLiveReferences(
          variable: variable,
          value: instance,
          isolateRef: isolateRef,
          heapSelection: ref.heapSelection,
        );
      }
      return;
  }
}

Future<void> _addOutboundLiveReferences({
  required DartObjectNode variable,
  required Instance value,
  required IsolateRef isolateRef,
  required HeapObjectSelection_ heapSelection,
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
      variable.addAllChildren(
        _createLiveOutboundReferencesForRecord(
          value,
          isolateRef,
          heapSelection.withoutObject(),
        ),
      );
      break;
    case InstanceKind.kClosure:
      variable.addAllChildren(
        await _createLiveOutboundReferencesForClosure(
          value,
          isolateRef,
          heapSelection.withoutObject(),
        ),
      );
      break;
    default:
      break;
  }

  if (value.fields != null && value.kind != InstanceKind.kRecord) {
    variable.addAllChildren(
      _createLiveOutboundReferencesForFields(
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
  HeapObjectSelection_ heapSelection, {
  String namePrefix = '',
}) {
  if (instance is! ObjRef) {
    throw StateError('Unexpected type: ${instance.runtimeType}.');
  }

  final String name;
  if (instance is InstanceRef) {
    final classRef = instance.classRef!;
    if (HeapClassName.fromClassRef(classRef).isNull) return;
    name = classRef.name ?? '';
  } else if (namePrefix.isNotEmpty) {
    name = '';
  } else {
    name = instance.runtimeType.toString();
  }

  final text = '$namePrefix$name';

  assert(text.isNotEmpty);

  variables.add(
    DartObjectNode.references(
      text,
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
  HeapObjectSelection_ heapSelection,
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
  HeapObjectSelection_ heapSelection,
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

Future<List<DartObjectNode>> _createLiveOutboundReferencesForClosure(
  Instance instance,
  IsolateRef isolateRef,
  HeapObjectSelection_ heapSelection,
) async {
  final variables = <DartObjectNode>[];
  final contextRef = instance.closureContext;
  if (contextRef == null) return [];

  final context = await getObject(isolateRef: isolateRef, value: contextRef);
  if (context is! Context) return [];

  if (context.parent != null) {
    _addLiveReferenceToNode(
      variables,
      isolateRef,
      context.parent,
      RefNodeType.liveOutRefs,
      heapSelection.withoutObject(),
      namePrefix: 'parent',
    );
  }

  final contextVariables = context.variables ?? [];
  for (int i = 0; i < contextVariables.length; i++) {
    _addLiveReferenceToNode(
      variables,
      isolateRef,
      contextVariables[i].value,
      RefNodeType.liveOutRefs,
      heapSelection.withoutObject(),
      namePrefix: '[$i]',
    );
  }

  return variables;
}

List<DartObjectNode> _createLiveOutboundReferencesForRecord(
  Instance instance,
  IsolateRef isolateRef,
  HeapObjectSelection_ heapSelection,
) {
  final variables = <DartObjectNode>[];
  final fields = RecordFields(instance.fields);

  // Always show positional fields before named fields:
  for (var i = 0; i < fields.positional.length; i++) {
    final field = fields.positional[i];
    _addLiveReferenceToNode(
      variables,
      isolateRef,
      field.value,
      RefNodeType.liveOutRefs,
      heapSelection.withoutObject(),
      namePrefix: '[$i]',
    );
  }

  for (final field in fields.named) {
    _addLiveReferenceToNode(
      variables,
      isolateRef,
      field.value,
      RefNodeType.liveOutRefs,
      heapSelection.withoutObject(),
      namePrefix: '${field.name}:',
    );
  }

  return variables;
}

List<DartObjectNode> _createLiveOutboundReferencesForFields(
  Instance instance,
  IsolateRef isolateRef,
  HeapObjectSelection_ heapSelection,
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
