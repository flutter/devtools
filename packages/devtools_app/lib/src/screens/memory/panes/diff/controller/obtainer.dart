// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/globals.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/primitives/class_name.dart';
import '../../../shared/primitives/instance_set_view.dart';

class HeapSampleObtainer extends SampleObtainer {
  HeapSampleObtainer(this.classId, this.className);

  final int classId;
  final HeapClassName className;

  @override
  Future<void> obtain() async {
    final isolateId = serviceManager.isolateManager.mainIsolate.value!.id!;
    final isolateRef = serviceManager.isolateManager.mainIsolate.value!;
    final Isolate isolate =
        serviceManager.isolateManager.mainIsolateState!.isolateNow!;

    final theClass = (await serviceManager.service!.getClassList(isolateId))
        .classes!
        .firstWhere((ref) => className.matches(ref));

    final instances = await serviceManager.service!.getInstances(
      isolateId,
      theClass.id!,
      1,
    );

    final instance = instances.instances!.first as InstanceRef;

    // drop to console
    serviceManager.consoleService.appendInstanceRef(
      value: instance,
      diagnostic: null,
      isolateRef: isolateRef,
      forceScrollIntoView: true,
    );

    // eval object
    final response1 = await serviceManager.service!
        .evaluate(isolateId, instance.id!, 'toString()');
    print('!!!! eval without scope: ' + response1.json!['valueAsString']);

    // eval object
    final response2 = await serviceManager.service!.evaluate(
      isolateId,
      instance.id!,
      'identityHashCode(this)',
      scope: {'this': instance.id!},
    );
    print('!!!! eval with scope: ' + response2.json!['valueAsString']);
  }
}
