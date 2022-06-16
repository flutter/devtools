import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import 'vm_class_screen_controller.dart';
import 'vm_developer_common_widgets.dart';

/// A screen on the object inspector historyViewport displaying information related to class objects in the Dart VM.
class VmClassScreen extends StatelessWidget {
  const VmClassScreen({
    required this.controller,
  });

  final ClassScreenController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.refreshing,
      builder: (context, refreshing, _) {
        return Flexible(
          child: Row(
            children: [
              Flexible(
                child: Column(
                  children: [
                    Flexible(
                      flex: 10,
                      child: ClassInfoWidget(
                        controller: controller,
                      ),
                    ),
                    Flexible(
                      flex: 8,
                      child: ClassInstancesWidget(
                        instances: controller.instances,
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Displays general VM information of the Class Object.
class ClassInfoWidget extends StatelessWidget {
  const ClassInfoWidget({
    required this.controller,
  });
  final ClassScreenController controller;

  @override
  Widget build(BuildContext context) {
    final clazz = controller.clazz;
    return VMInfoCard(
      title: 'General Information',
      rowKeyValues: [
        MapEntry('Object Class', clazz?.type),
        MapEntry(
          'Shallow Size',
          prettyPrintBytes(
            clazz?.size ?? 0,
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
          clazz?.library?.name == ''
              ? controller.scriptUri!
              : clazz?.library?.name,
        ),
        MapEntry(
          'Script',
          (_fileName(controller.scriptUri) ?? '') +
              ':' +
              (controller.pos?.toString() ?? ''),
        ),
        MapEntry('Superclass', clazz?.superClass?.name),
        MapEntry('SuperType', clazz?.superType?.name),
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
