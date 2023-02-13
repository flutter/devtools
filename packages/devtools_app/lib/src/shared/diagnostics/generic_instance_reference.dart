// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../memory/adapted_heap_data.dart';
import '../memory/simple_items.dart';
import 'diagnostics_node.dart';

/// A generic [InstanceRef] using either format used by the [InspectorService]
/// or Dart VM.
///
/// Either one or both of [value] and [diagnostic] may be provided. The
/// `valueRef` getter on the [diagnostic] should refer to the same object as
/// [instanceRef] although using the [InspectorInstanceRef] scheme.
/// A [RemoteDiagnosticsNode] is used rather than an [InspectorInstanceRef] as
/// the additional data provided by [RemoteDiagnosticsNode] is helpful to
/// correctly display the object and [RemoteDiagnosticsNode] includes a
/// reference to an [InspectorInstanceRef]. [value] must be a VM service type,
/// Sentinel, or primitive type.
class GenericInstanceRef {
  GenericInstanceRef({
    required this.isolateRef,
    this.value,
    this.diagnostic,
    this.heapSelection,
  });

  final Object? value;

  final HeapObjectSelection? heapSelection;

  InstanceRef? get instanceRef =>
      value is InstanceRef ? value as InstanceRef? : null;

  /// If both [diagnostic] and [instanceRef] are provided, [diagnostic.valueRef]
  /// must reference the same underlying object just using the
  /// [InspectorInstanceRef] scheme.
  final RemoteDiagnosticsNode? diagnostic;

  final IsolateRef? isolateRef;
}

class ObjectReferences extends GenericInstanceRef {
  ObjectReferences({
    required this.refNodeType,
    required super.isolateRef,
    required super.value,
    required super.heapSelection,
  });

  ObjectReferences.withType(ObjectReferences ref, this.refNodeType)
      : super(
          isolateRef: ref.isolateRef,
          value: ref.value,
          heapSelection: ref.heapSelection,
        );

  final RefNodeType refNodeType;
}

enum RefNodeType {
  /// Root item for references.
  refRoot,

  /// Subitem of [refRoot] for static references.
  staticRefRoot,

  /// Subitem of [staticRefRoot] for inbound static references.
  staticInRefs(RefDirection.inbound),

  /// Subitem of [staticRefRoot] for outbound static references.
  staticOutRefs(RefDirection.outbound),

  /// Subitem of [refRoot] for live references.
  liveRefRoot,

  /// Subitem of [liveRefRoot] for inbound live references.
  liveInRefs(RefDirection.inbound),

  /// Subitem of [liveRefRoot] for outbound live references.
  liveOutRefs(RefDirection.outbound),
  ;

  const RefNodeType([this.direction]);

  final RefDirection? direction;
}
