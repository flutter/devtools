// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_common_widgets.dart';
import 'object_inspector_view_controller.dart';
import 'vm_object_model.dart';

// TODO(mtaylee): Finish implementation of ClassInstancesWidget. When done,
// remove this constant, and add the ClassInstancesWidget to
// the class display layout.
const displayClassInstances = false;

/// A widget for the object inspector historyViewport displaying information
/// related to class objects in the Dart VM.
class VmClassDisplay extends StatelessWidget {
  const VmClassDisplay({
    super.key,
    required this.controller,
    required this.clazz,
  });

  final ObjectInspectorViewController controller;
  final ClassObject clazz;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        Flexible(
          child: VmObjectDisplayBasicLayout(
            controller: controller,
            object: clazz,
            generalDataRows: _classDataRows(clazz),
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
    if (clazz.scriptRef != null) {
      return ObjectInspectorCodeView(
        codeViewController: controller.codeViewController,
        script: clazz.scriptRef!,
        object: clazz.ref,
        child: child,
      );
    }
    return child;
  }

  // TODO(mtaylee): Delete 'Currently allocated instances' row when
  // ClassInstancesWidget implementation is completed.
  /// Generates a list of key-value pairs (map entries) containing the general
  /// information of the class object [clazz].
  List<MapEntry<String, WidgetBuilder>> _classDataRows(
    ClassObject clazz,
  ) {
    final superClass = clazz.obj.superClass;
    return [
      ...vmObjectGeneralDataRows(
        controller,
        clazz,
      ),
      if (superClass != null)
        serviceObjectLinkBuilderMapEntry(
          controller: controller,
          key: 'Superclass',
          object: superClass,
        ),
      selectableTextBuilderMapEntry('SuperType', clazz.obj.superType?.name),
      selectableTextBuilderMapEntry(
        'Currently allocated instances',
        clazz.instances?.totalCount?.toString(),
      ),
    ];
  }
}

// TODO(mtaylee): Finish implementation of widget to display
// all class instances. When done, remove the last row of the ClassInfoWidget.
/// Displays information on the instances of the Class object.
class ClassInstancesWidget extends StatelessWidget {
  const ClassInstancesWidget({
    super.key,
    required this.instances,
  });

  final InstanceSet? instances;

  @override
  Widget build(BuildContext context) {
    return VMInfoCard(
      title: 'Class Instances',
      rowKeyValues: [
        selectableTextBuilderMapEntry(
          'Currently allocated',
          instances?.totalCount?.toString(),
        ),
        selectableTextBuilderMapEntry('Strongly reachable', 'TO-DO'),
        selectableTextBuilderMapEntry('All direct instances', 'TO-DO'),
        selectableTextBuilderMapEntry('All instances of subclasses', 'TO-DO'),
        selectableTextBuilderMapEntry('All instances of implementors', 'TO-DO'),
        selectableTextBuilderMapEntry('Reachable size', 'TO-DO'),
        selectableTextBuilderMapEntry('Retained size', 'TO-DO'),
      ],
    );
  }
}
