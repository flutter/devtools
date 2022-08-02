// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

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
        Flexible(
          child: VmObjectDisplayBasicLayout(
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
  }
}

// TODO(mtaylee): Delete 'Currently allocated instances' row when
// ClassInstancesWidget implementation is completed.
/// Generates a list of key-value pairs (map entries) containing the general
/// information of the class object [clazz].
List<MapEntry<String, Object?>> _classDataRows(ClassObject clazz) {
  return [
    ...vmObjectGeneralDataRows(clazz),
    MapEntry('Superclass', clazz.obj.superClass?.name),
    MapEntry('SuperType', clazz.obj.superType?.name),
    MapEntry(
      'Currently allocated instances',
      clazz.instances?.totalCount,
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
