// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import 'vm_developer_common_widgets.dart';
import 'vm_object_model.dart';
import 'vm_service_private_extensions.dart';

/// A widget for the object inspector historyViewport, displaying information
/// related to field objects in the Dart VM.
class VmFieldDisplay extends StatelessWidget {
  const VmFieldDisplay({
    required this.field,
  });

  final FieldObject field;

  @override
  Widget build(BuildContext context) => VmObjectDisplayBasicLayout(
        object: field,
        generalDataRows: _fieldDataRows(field),
      );
}

/// Generates a list of key-value pairs (map entries) containing the general
/// information of the field object [field].
List<MapEntry<String, Widget Function(BuildContext)>> _fieldDataRows(
    FieldObject field) {
  return [
    ...vmObjectGeneralDataRows(field),
    selectableTextBuilderMapEntry(
      'Observed types',
      _fieldObservedTypes(field),
    ),
    if (field.obj.staticValue is InstanceRef)
      selectableTextBuilderMapEntry(
        'Static Value',
        '${field.obj.staticValue.name ?? field.obj.staticValue.classRef.name}: '
            '${field.obj.staticValue.valueAsString ?? 'Unknown value'}',
      ),
  ];
}

/// Returns the observed types of a field object, including null.
///
/// The observed types can be a single type (guardClassSingle), various types
/// (guardClassDynamic), or a type that has not been observed yet
/// (guardClassUnknown).
String _fieldObservedTypes(FieldObject field) {
  late String type;

  final kind = field.guardClassKind;

  switch (kind) {
    case GuardClassKind.single:
      type = field.guardClass!.name ?? '<Observed Type>';
      break;
    case GuardClassKind.dynamic:
      type = GuardClassKind.dynamic.toString();
      break;
    case GuardClassKind.unknown:
      type = 'none';
      break;
    case null:
      type = 'Observed types not found';
      break;
  }

  final nullable = field.guardNullable == null
      ? ''
      : ' - null ${field.guardNullable! ? '' : 'not '}observed';

  return '$type$nullable';
}
