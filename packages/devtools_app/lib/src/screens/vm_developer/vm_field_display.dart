// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/table.dart';
import '../../shared/theme.dart';
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              FieldInfoWidget(
                fieldDataRows: _fieldDataRows(field),
              ),
              Flexible(
                child: ListView(
                  children: [
                    RetainingPathWidget(
                      retainingPath: field.retainingPath,
                      onExpanded: _onExpandRetainingPath,
                    ),
                    InboundReferencesWidget(
                      inboundReferences: field.inboundReferences,
                      onExpanded: _onExpandInboundRefs,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onExpandRetainingPath(bool expanded) {
    if (field.retainingPath.value == null) field.requestRetainingPath();
  }

  void _onExpandInboundRefs(bool expanded) {
    if (field.inboundReferences.value == null) field.requestInboundsRefs();
  }
}

/// Displays general VM information of the Class Object.
class FieldInfoWidget extends StatelessWidget implements PreferredSizeWidget {
  const FieldInfoWidget({
    required this.fieldDataRows,
  });

  final List<MapEntry<String, Object?>> fieldDataRows;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: preferredSize,
      child: VMInfoCard(
        title: 'General Information',
        rowKeyValues: fieldDataRows,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        areaPaneHeaderHeight +
            fieldDataRows.length * defaultRowHeight +
            defaultSpacing,
      );
}

/// Generates a list of key-value pairs (map entries) that will be displayed
/// in the data rows of the FieldInfoWidget.
List<MapEntry<String, Object?>> _fieldDataRows(FieldObject field) {
  return [
    MapEntry('Object Class', field.obj.type),
    MapEntry(
      'Shallow Size',
      prettyPrintBytes(
        field.obj.size ?? 0,
        includeUnit: true,
        kbFractionDigits: 1,
        maxBytes: 512,
      ),
    ),
    MapEntry(
      'Reachable Size',
      ValueListenableBuilder<bool>(
        valueListenable: field.fetchingReachableSize,
        builder: (context, fetching, _) => fetching
            ? const CircularProgressIndicator()
            : RequestableSizeWidget(
                requestedSize: field.reachableSize,
                requestFunction: field.requestReachableSize,
              ),
      ),
    ),
    MapEntry(
      'Retained Size',
      ValueListenableBuilder<bool>(
        valueListenable: field.fetchingRetainedSize,
        builder: (context, fetching, _) => fetching
            ? const CircularProgressIndicator()
            : RequestableSizeWidget(
                requestedSize: field.retainedSize,
                requestFunction: field.requestRetainedSize,
              ),
      ),
    ),
    MapEntry(
      'Owner',
      _fieldOwner(field.obj.owner),
    ),
    MapEntry(
      'Script',
      '${fileNameFromUri(field.script?.uri) ?? ''}:${field.pos?.toString() ?? ''}',
    ),
    MapEntry(
      'Observed types',
      _fieldObservedTypes(field),
    ),
    if (field.obj.staticValue is InstanceRef)
      MapEntry(
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

  if (field.guardClassKind == FieldPrivateViewExtension.guardClassSingle) {
    type = field.guardClass!.name ?? '<Observed Type>';
  } else if (field.guardClassKind ==
      FieldPrivateViewExtension.guardClassUnknown) {
    type = 'none';
  } else if (field.guardClassKind ==
      FieldPrivateViewExtension.guardClassDynamic) {
    type = FieldPrivateViewExtension.guardClassDynamic;
  } else {
    type = 'Observed types not found';
  }

  final String nullable = field.guardNullable == null
      ? ''
      : ' - null ${field.guardNullable! ? '' : 'not '}observed';

  return '$type$nullable';
}

String? _fieldOwner(ObjRef? owner) {
  if (owner == null) {
    return null;
  } else if (owner is ClassRef || owner is LibraryRef) {
    return (owner as dynamic).name;
  } else {
    throw Exception('Unexpected owner type: ${owner.type}');
  }
}
