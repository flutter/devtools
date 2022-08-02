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

// TODO(mtaylee): Finish implementation of ClassInstancesWidget. When done,
// remove this constant, and add the ClassInstancesWidget to
// the class display layout.
const displayClassInstances = false;

/// A widget for the object inspector historyViewport displaying information
/// related to class objects in the Dart VM.
class VmClassDisplay extends StatelessWidget {
  const VmClassDisplay({
    required this.clazz,
  });

  final ClassObject clazz;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              ClassInfoWidget(
                classDataRows: _classDataRows(clazz),
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
class ClassInfoWidget extends StatelessWidget implements PreferredSizeWidget {
  const ClassInfoWidget({
    required this.classDataRows,
  });

  final List<MapEntry<String, Widget>> classDataRows;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: preferredSize,
      child: VMInfoCard(
        title: 'General Information',
        rowKeyValues: classDataRows,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        areaPaneHeaderHeight +
            classDataRows.length * defaultRowHeight +
            defaultSpacing,
      );
}

List<MapEntry<String, Widget>> _classDataRows(ClassObject clazz) {
  return [
    selectableTextMapEntry('Object Class', clazz.obj.type),
    selectableTextMapEntry(
      'Shallow Size',
      prettyPrintBytes(
        clazz.obj.size ?? 0,
        includeUnit: true,
        kbFractionDigits: 1,
        maxBytes: 512,
      ),
    ),
    MapEntry(
      'Reachable Size',
      ValueListenableBuilder<bool>(
        valueListenable: clazz.fetchingReachableSize,
        builder: (context, fetching, _) => fetching
            ? const CircularProgressIndicator()
            : RequestableSizeWidget(
                requestedSize: clazz.reachableSize,
                requestFunction: clazz.requestReachableSize,
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
    selectableTextMapEntry(
      'Library',
      clazz.obj.library?.name?.isEmpty ?? false
          ? clazz.script?.uri
          : clazz.obj.library?.name,
    ),
    selectableTextMapEntry(
      'Script',
      '${fileNameFromUri(clazz.script?.uri) ?? ''}:${clazz.pos?.toString() ?? ''}',
    ),
    selectableTextMapEntry('Superclass', clazz.obj.superClass?.name),
    selectableTextMapEntry('SuperType', clazz.obj.superType?.name),
    selectableTextMapEntry(
      'Currently allocated instances',
      clazz.instances?.totalCount?.toString(),
    ),
  ];
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
        selectableTextMapEntry(
          'Currently allocated',
          instances?.totalCount?.toString(),
        ),
        selectableTextMapEntry('Strongly reachable', 'TO-DO'),
        selectableTextMapEntry('All direct instances', 'TO-DO'),
        selectableTextMapEntry('All instances of subclasses', 'TO-DO'),
        selectableTextMapEntry('All instances of implementors', 'TO-DO'),
        selectableTextMapEntry('Reachable size', 'TO-DO'),
        selectableTextMapEntry('Retained size', 'TO-DO'),
      ],
    );
  }
}
