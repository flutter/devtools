// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import 'vm_developer_common_widgets.dart';
import 'vm_object_model.dart';

/// A widget for the object inspector historyViewport displaying information
/// related to class objects in the Dart VM.
class VmClassDisplay extends StatelessWidget {
  const VmClassDisplay({
    required this.clazz,
  });
  final ClassObject clazz;

  @override
  Widget build(BuildContext context) {
    return Column(
      //mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          flex: 5,
          child: ClassInfoWidget(
            clazz: clazz,
          ),
        ),
        Flexible(
          flex: 4,
          child: ClassInstancesWidget(
            instances: clazz.instances,
          ),
        )
      ],
    );
  }
}

/// Displays general VM information of the Class Object.
class ClassInfoWidget extends StatelessWidget {
  const ClassInfoWidget({
    required this.clazz,
  });

  final ClassObject clazz;

  @override
  Widget build(BuildContext context) {
    return VMInfoCard(
      title: 'General Information',
      rowKeyValues: [
        MapEntry('Object Class', clazz.obj?.type),
        MapEntry(
          'Shallow Size',
          prettyPrintBytes(
            clazz.obj?.size ?? 0,
            includeUnit: true,
            kbFractionDigits: 3,
          ),
        ),
        const MapEntry('Reachable Size', 'TO-DO'),
        const MapEntry('Retained Size', 'TO-DO'),
        const MapEntry('Retaining path', 'TO-DO'),
        const MapEntry('Inbound references', 'TO-DO'),
        MapEntry(
          'Library',
          clazz.obj?.library?.name?.isEmpty ?? false
              ? clazz.script?.uri
              : clazz.obj?.library?.name,
        ),
        MapEntry(
          'Script',
          (_fileName(clazz.script?.uri) ?? '') +
              ':' +
              (clazz.pos?.toString() ?? ''),
        ),
        MapEntry('Superclass', clazz.obj?.superClass?.name),
        MapEntry('SuperType', clazz.obj?.superType?.name),
      ],
    );
  }
}

String? _fileName(String? uri) {
  if (uri == null) return null;
  final splitted = uri.split('/');
  return splitted[splitted.length - 1];
}

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
