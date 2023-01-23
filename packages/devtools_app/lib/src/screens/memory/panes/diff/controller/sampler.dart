// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../../../../shared/globals.dart';
import '../../../../../shared/memory/adapted_heap_data.dart';
import '../../../../../shared/memory/class_name.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import '../../../shared/primitives/instance_set_view.dart';

class HeapClassSampler extends ClassSampler {
  HeapClassSampler(this.objects, this.heap);

  final SingleClassStats objects;
  final AdaptedHeapData heap;

  IsolateRef get _mainIsolateRef =>
      serviceManager.isolateManager.mainIsolate.value!;

  Future<InstanceRef?> _oneInstance() async {
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

    final result = instances.instances!.first;

    if (result is InstanceRef) return result;

    return null;
  }

  @override
  Future<void> oneVariableToConsole() async {
    final instance = await _oneInstance();

    if (instance == null) {
      serviceManager.consoleService
          .appendStdio('the instance cannot be evaluated');
    } else {
      // drop to console
      serviceManager.consoleService.appendInstanceRef(
        value: instance,
        diagnostic: null,
        isolateRef: _mainIsolateRef,
        forceScrollIntoView: true,
        heap: heap,
      );
    }

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
