// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../../shared/globals.dart';
import '../../../../../shared/memory/adapted_heap_data.dart';
import '../../../../../shared/memory/class_name.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import '../../../shared/primitives/instance_set_view.dart';

class HeapClassSampler extends ClassSampler {
  HeapClassSampler(this.objects, this.heap);

  final SingleClassStats objects;
  final AdaptedHeapData heap;

  IsolateRef get _mainIsolateRef =>
      serviceManager.isolateManager.mainIsolate.value!;

  Future<List<ObjRef>> _instances() async {
    final isolateId = _mainIsolateRef.id!;

    // TODO(polina-c): It would be great to find out how to avoid full scan of classes.
    final theClass = (await serviceManager.service!.getClassList(isolateId))
        .classes!
        .firstWhere((ref) => objects.heapClass.matches(ref));

    final instances = await serviceManager.service!.getInstances(
      isolateId,
      theClass.id!,
      1,
    );

    return instances.instances ?? [];
  }

  @override
  Future<void> oneVariableToConsole() async {
    final instances = await _instances();

    final instanceRef = instances.firstWhereOrNull(
      (objRef) =>
          objRef is InstanceRef &&
          objects.objects.objectsByCodes.containsKey(objRef.identityHashCode),
    ) as InstanceRef?;

    if (instanceRef == null) {
      serviceManager.consoleService
          .appendStdio('the instance cannot be selected');
      return;
    }

    final heapObject =
        objects.objects.objectsByCodes[instanceRef.identityHashCode!]!;

    final heapSelection = HeapObjectSelection(heap, heapObject);

    // drop to console
    serviceManager.consoleService.appendInstanceRef(
      value: instanceRef,
      diagnostic: null,
      isolateRef: _mainIsolateRef,
      forceScrollIntoView: true,
      heapSelection: heapSelection,
    );

    // TODO (polina-c): remove the commented code
    // before opening the flag.
    // // eval object
    // final response1 = await serviceManager.service!
    //     .evaluate(_mainIsolateRef.id!, instance.id!, 'toString()');
    // print('!!!! eval without scope: ' + response1.json!['valueAsString']);

    // // eval object
    // final response2 = await serviceManager.service!.evaluate(
    //   _mainIsolateRef.id!,
    //   instance.id!,
    //   'identityHashCode(this)',
    //   scope: {'this': instance.id!},
    // );
    // print('!!!! eval with scope: ' + response2.json!['valueAsString']);
  }

  @override
  Future<void> instanceGraphToConsole() async {
    serviceManager.consoleService.appendInstanceGraph(
      HeapObjectGraph(
        heap,
        objects.objects.objectsByCodes.keys.first,
        objects.heapClass,
      ),
    );
  }

  @override
  bool get isEvalEnabled =>
      objects.heapClass.classType(serviceManager.rootInfoNow().package) !=
      ClassType.runtime;
}
