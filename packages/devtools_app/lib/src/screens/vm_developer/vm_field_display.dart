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
              ClassInfoWidget(
                field: field,
              ),
              Flexible(
                child: ListView(
                  children: [
                    RetainingPathWidget(
                      retainingPath: clazz.retainingPath,
                      onExpanded: _onExpandRetainingPath,
                    ),
                    InboundReferencesWidget(
                      inboundReferences: clazz.inboundReferences,
                      onExpanded: _onExpandInboundRefs,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (displayClassInstances)
          Flexible(
            child: ClassInstancesWidget(
              instances: clazz.instances,
            ),
          ),
      ],
    );
  }

  void _onExpandRetainingPath(bool expanded) {
    if (clazz.retainingPath.value == null) clazz.requestRetainingPath();
  }

  void _onExpandInboundRefs(bool expanded) {
    if (clazz.inboundReferences.value == null) clazz.requestInboundsRefs();
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
          valueListenable: clazz.fetchingRetainedSize,
          builder: (context, fetching, _) => fetching
              ? const CircularProgressIndicator()
              : RequestableSizeWidget(
                  requestedSize: clazz.retainedSize,
                  requestFunction: clazz.requestRetainedSize,
                ),
        ),
      ),
      MapEntry(
        'Library',
        clazz.obj.library?.name?.isEmpty ?? false
            ? clazz.script?.uri
            : clazz.obj.library?.name,
      ),
      MapEntry(
        'Script',
        '${_fileName(clazz.script?.uri) ?? ''}:${clazz.pos?.toString() ?? ''}',
      ),
      MapEntry('Superclass', clazz.obj.superClass?.name),
      MapEntry('SuperType', clazz.obj.superType?.name),
      MapEntry(
        'Currently allocated instances',
        clazz.instances?.totalCount,
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

  @override
  Size get preferredSize => Size.fromHeight(
        areaPaneHeaderHeight +
            dataRows.length * defaultRowHeight +
            defaultSpacing,
      );
}

// TODO(mtaylee): Finish implementation of widget to display
// all class instances. When done, remove the last row of the ClassInfoWidget.
/// Displays information on the instances of the Class object.
class ClassInstancesWidget extends StatelessWidget {
  const ClassInstancesWidget({
    required this.instances,
  });

  final InstanceSet? instances;

  @override
  Widget build(BuildContext context) {
    return VMInfoCard(
      title: 'Class Instances',
      rowKeyValues: [
        MapEntry('Currently allocated', instances?.totalCount),
        const MapEntry('Strongly reachable', 'TO-DO'),
        const MapEntry('All direct instances', 'TO-DO'),
        const MapEntry('All instances of subclasses', 'TO-DO'),
        const MapEntry('All instances of implementors', 'TO-DO'),
        const MapEntry('Reachable size', 'TO-DO'),
        const MapEntry('Retained size', 'TO-DO'),
      ],
    );
  }
}
