import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/eval_on_dart_library.dart';
import '../../../../shared/globals.dart';

class DraftPane extends StatefulWidget {
  const DraftPane({Key? key}) : super(key: key);

  @override
  State<DraftPane> createState() => _DraftPaneState();
}

class _DraftPaneState extends State<DraftPane> {
  ClassHeapStats? _classHeapStats;
  String _isolateId = '';

  ObjRef? _instance;

  String? _result;

  var _code;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('hello!!'),
        MaterialButton(
            child: const Text('Try It'),
            onPressed: () async {
              setState(() {
                _isolateId =
                    serviceManager.isolateManager!.mainIsolate!.value!.id!;
              });

              final profile =
                  await serviceManager.service!.getAllocationProfile(
                _isolateId,
                gc: true,
              );

              for (var item in profile.members!) {
                if (item.classRef!.name == 'MyClass') {
                  final isolateRef =
                      serviceManager.isolateManager!.mainIsolate!.value!;
                  final instances = await serviceManager.service!.getInstances(
                    _isolateId,
                    item.classRef!.id!,
                    20,
                  );

                  setState(() {
                    _classHeapStats = item;
                    _instance = instances.instances!.first!;
                    _code = _instance!.json!['identityHashCode'];
                  });

                  final response = await serviceManager.service!
                      .evaluate(_isolateId, _instance!.id!, 'hello()');

                  setState(() {
                    _result = response.json!['valueAsString'];
                  });

                  return;
                }
              }
            }),
        Text('${_classHeapStats?.type}-${_classHeapStats?.classRef?.id}'),
        Text('${_instance?.id}'),
        Text('$_result'),
        Text('$_code'),
      ],
    );
  }
}
