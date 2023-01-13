// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../../../../shared/globals.dart';
import '../../../shared/primitives/class_name.dart';
import '../../../shared/primitives/instance_set_view.dart';

class HeapClassSampler extends ClassSampler {
  HeapClassSampler(this.className);

  final HeapClassName className;

  @override
  Future<void> oneVariableToConsole() async {
    final isolateRef = serviceManager.isolateManager.mainIsolate.value!;
    final isolateId = isolateRef.id!;

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

    // TODO (polina-c): convert drafts below to separate commands

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
