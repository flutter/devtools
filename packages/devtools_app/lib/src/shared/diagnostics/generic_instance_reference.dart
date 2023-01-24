// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

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
    this.expandType = ExpandType.members,
    required this.isolateRef,
    this.value,
    this.diagnostic,
  });

  final ExpandType expandType;

  final Object? value;

  InstanceRef? get instanceRef =>
      value is InstanceRef ? value as InstanceRef? : null;

  /// If both [diagnostic] and [instanceRef] are provided, [diagnostic.valueRef]
  /// must reference the same underlying object just using the
  /// [InspectorInstanceRef] scheme.
  final RemoteDiagnosticsNode? diagnostic;

  final IsolateRef? isolateRef;
}

enum ExpandType {
  members,
  refRoot,

  staticRefRoot,
  staticInboundRoot,
  staticOutboundRoot,

  liveRefRoot,
  liveInboundRoot,
  liveOutboundRoot,
}
