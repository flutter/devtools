// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../../shared/primitives/trees.dart';
import '../../../shared/primitives/utils.dart';
import '../vm_developer_common_widgets.dart';
import '../vm_service_private_extensions.dart';

class InboundReferencesTreeNode extends TreeNode<InboundReferencesTreeNode> {
  InboundReferencesTreeNode._({required this.ref});

  static List<InboundReferencesTreeNode> buildTreeRoots(
    InboundReferences inboundReferences,
  ) {
    return [
      for (final ref in inboundReferences.references!)
        InboundReferencesTreeNode._(ref: ref),
    ];
  }

  final InboundReference ref;

  @override
  bool get isExpandable => ref.source != null;

  late final String description = _inboundRefDescription(ref, null);

  /// Wrapper to get the name of an [ObjRef] depending on its type.
  String? _objectName(ObjRef? objectRef) {
    if (objectRef == null) {
      return null;
    }

    return switch (objectRef) {
      ClassRef(:final name) ||
      FuncRef(:final name) ||
      FieldRef(:final name) =>
        name,
      LibraryRef(:final name, :final uri) => name.isNullOrEmpty ? uri : name,
      ScriptRef(:final uri) => fileNameFromUri(uri),
      InstanceRef(:final name, :final classRef) =>
        name ?? 'Instance of ${classRef?.name ?? '<Class>'}',
      _ => (objectRef.vmType ?? objectRef.type)..replaceFirst('@', ''),
    };
  }

  String? _instanceClassName(ObjRef? object) {
    if (object == null) {
      return null;
    }

    return object is InstanceRef ? object.classRef?.name : _objectName(object);
  }

  String _parentListElementDescription(int listIndex, ObjRef? obj) {
    final parentListName = _instanceClassName(obj) ?? '<parentList>';
    return 'element [$listIndex] of $parentListName';
  }

  /// Describes the given InboundReference [inboundRef] and its parentListIndex,
  /// [offset], and parentField where applicable.
  String _inboundRefDescription(InboundReference inboundRef, int? offset) {
    final parentListIndex = inboundRef.parentListIndex;
    if (parentListIndex != null) {
      return 'Referenced by ${_parentListElementDescription(
        parentListIndex,
        inboundRef.source,
      )}';
    }

    final description = StringBuffer('Referenced by ');

    if (offset != null) {
      description.write(
        'offset $offset of ',
      );
    }

    if (inboundRef.parentField is int) {
      assert((inboundRef.source as InstanceRef).kind == InstanceKind.kRecord);
      description.write('\$${inboundRef.parentField} of ');
    } else if (inboundRef.parentField is String) {
      assert((inboundRef.source as InstanceRef).kind == InstanceKind.kRecord);
      description.write('${inboundRef.parentField} of ');
    } else if (inboundRef.parentField is FieldRef) {
      description.write(
        '${_objectName(inboundRef.parentField)} of ',
      );
    }

    description.write(
      _objectDescription(inboundRef.source) ?? '<object>',
    );

    return description.toString();
  }

  // Returns a description of the object containing its name and owner.
  String? _objectDescription(ObjRef? object) {
    if (object == null) return null;
    return switch (object) {
      FieldRef(:final declaredType, :final name, :final owner) =>
        '${declaredType?.name ?? 'Field'} $name of ${_objectName(owner) ?? '<Owner>'}',
      FuncRef() => qualifiedName(object) ?? '<Function Name>',
      _ => _objectName(object),
    };
  }

  @override
  TreeNode<InboundReferencesTreeNode> shallowCopy() {
    throw UnimplementedError();
  }
}
