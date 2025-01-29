// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_common_widgets.dart';
import '../vm_service_private_extensions.dart';
import 'object_inspector_view_controller.dart';
import 'vm_object_model.dart';

/// A widget for the object inspector historyViewport, displaying information
/// related to field objects in the Dart VM.
class VmFieldDisplay extends StatelessWidget {
  const VmFieldDisplay({
    super.key,
    required this.controller,
    required this.field,
  });

  final ObjectInspectorViewController controller;
  final FieldObject field;

  @override
  Widget build(BuildContext context) {
    return ObjectInspectorCodeView(
      codeViewController: controller.codeViewController,
      script: field.scriptRef!,
      object: field.obj,
      child: VmObjectDisplayBasicLayout(
        controller: controller,
        object: field,
        generalDataRows: _fieldDataRows(field),
      ),
    );
  }

  /// Generates a list of key-value pairs (map entries) containing the general
  /// information of the field object [field].
  List<MapEntry<String, WidgetBuilder>> _fieldDataRows(FieldObject field) {
    final staticValue = field.obj.staticValue;
    return [
      ...vmObjectGeneralDataRows(controller, field),
      selectableTextBuilderMapEntry(
        'Observed types',
        _fieldObservedTypes(field),
      ),
      if (staticValue is InstanceRef)
        serviceObjectLinkBuilderMapEntry(
          controller: controller,
          key: 'Static Value',
          object: staticValue,
        ),
    ];
  }

  /// Returns the observed types of a field object, including null.
  ///
  /// The observed types can be a single type (guardClassSingle), various types
  /// (guardClassDynamic), or a type that has not been observed yet
  /// (guardClassUnknown).
  String _fieldObservedTypes(FieldObject field) {
    String type;

    final kind = field.guardClassKind;

    switch (kind) {
      case GuardClassKind.single:
        type = field.guardClass!.name ?? '<Observed Type>';
        break;
      case GuardClassKind.dynamic:
        type = GuardClassKind.dynamic.jsonValue();
        break;
      case GuardClassKind.unknown:
        type = 'none';
        break;
      default:
        type = 'Observed types not found';
    }

    final nullable =
        field.guardNullable == null ? '' : _nullMessage(field.guardNullable!);

    return '$type$nullable';
  }

  String _nullMessage(bool isNullable) =>
      ' - null ${isNullable ? '' : 'not '}observed';
}
