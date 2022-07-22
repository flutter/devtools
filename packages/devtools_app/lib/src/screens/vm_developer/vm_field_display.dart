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

/// A widget for the object inspector historyViewport displaying information
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
                field: field,
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
  FieldInfoWidget({
    required this.field,
  });

  final FieldObject field;
  late final List<MapEntry<String, Object?>> dataRows;

  @override
  Widget build(BuildContext context) {
    dataRows = [
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
        ownerName(field.obj.owner),
      ),
      MapEntry(
        'Script',
        '${_fileName(field.script?.uri) ?? ''}:${field.pos?.toString() ?? ''}',
      ),
      MapEntry(
        'Observed types',
        _observedTypes(field),
      ),
      if (field.obj.staticValue != null && field.obj.staticValue is! Sentinel)
        MapEntry(
          'Static Value',
          (field.obj.staticValue as InstanceRef).name,
        ),
    ];

    return SizedBox.fromSize(
      size: preferredSize,
      child: VMInfoCard(
        title: 'General Information',
        rowKeyValues: dataRows,
      ),
    );
  }

  String? _fileName(String? uri) {
    if (uri == null) return null;
    final splitted = uri.split('/');
    return splitted[splitted.length - 1];
  }

  String _observedTypes(FieldObject field) {
    late String type;

    if (field.guardClassKind == FieldPrivateViewExtension.guardClassSingle) {
      type = field.guardClass!.name ?? '<Observed Type Name>';
    } else if (field.guardClassKind ==
        FieldPrivateViewExtension.guardClassUnknown) {
      type = 'none';
    } else if (field.guardClassKind ==
        FieldPrivateViewExtension.guardClassDynamic) {
      type = FieldPrivateViewExtension.guardClassDynamic;
    } else {
      type = 'Observed types not found';
    }

    return '$type - null ${field.guardNullable == true ? '' : 'not'} observed';
  }

  @override
  Size get preferredSize => Size.fromHeight(
        areaPaneHeaderHeight +
            dataRows.length * defaultRowHeight +
            defaultSpacing,
      );
}
