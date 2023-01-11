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
    //final isolateRef = serviceManager.isolateManager.mainIsolate.value!;

    final theClass = (await serviceManager.service!.getClassList(isolateId))
        .classes!
        .firstWhere((ref) => ref.name == className.shortName);

    final instances = await serviceManager.service!.getInstances(
      isolateId,
      theClass.id!,
      1,
      //classId: theClass.id,
    );

    final instance = instances.instances!.first;

    final evalResponse = await serviceManager.service!
        .evaluate(isolateId, instance.id!, 'toString()');

    final result = evalResponse.json!['valueAsString'];

    print('!!!! eval result: $result');
  }
}
