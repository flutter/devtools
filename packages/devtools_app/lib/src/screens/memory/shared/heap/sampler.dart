// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/globals.dart';
import '../../../../shared/memory/adapted_heap_data.dart';
import '../../../../shared/memory/class_name.dart';
import '../../../../shared/vm_utils.dart';
import 'heap.dart';

class _HeapObjects {
  _HeapObjects(this.objects, this.heap);

  final ObjectSet objects;
  final AdaptedHeapData heap;
}

class ClassSampler {
  ClassSampler(
    this.heapClass, {
    ObjectSet? objects,
    AdaptedHeapData? heap,
  })  : assert(objects?.objectsByCodes.isNotEmpty ?? true),
        assert((objects == null) == (heap == null)),
        _objects = objects == null ? null : _HeapObjects(objects, heap!);

  final HeapClassName heapClass;
  final _HeapObjects? _objects;

  IsolateRef get _mainIsolateRef =>
      serviceConnection.serviceManager.isolateManager.mainIsolate.value!;

  Future<InstanceRef?> _liveInstance() async {
    try {
      final isolateId = _mainIsolateRef.id!;

      final theClass = await findClass(isolateId, heapClass);
      if (theClass == null) return null;

      final object =
          (await serviceConnection.serviceManager.service!.getInstances(
        isolateId,
        theClass.id!,
        1,
      ))
              .instances?[0];

      if (object is InstanceRef) return object;
      return null;
    } catch (error, trace) {
      _outputError(error, trace);
      return null;
    }
  }

  Future<InstanceSet?> _liveInstances() async {
    try {
      final isolateId = _mainIsolateRef.id!;

      final theClass = await findClass(isolateId, heapClass);
      if (theClass == null) return null;

      return await serviceConnection.serviceManager.service!.getInstances(
        isolateId,
        theClass.id!,
        preferences.memory.refLimit.value,
      );
    } catch (error, trace) {
      _outputError(error, trace);
      return null;
    }
  }

  Future<InstanceRef?> _liveInstancesAsList() async {
    try {
      final isolateId = _mainIsolateRef.id!;

      final theClass = await findClass(isolateId, heapClass);
      if (theClass == null) return null;

      return await serviceConnection.serviceManager.service!.getInstancesAsList(
        isolateId,
        theClass.id!,
      );
    } catch (error, trace) {
      _outputError(error, trace);
      return null;
    }
  }

  void _outputError(Object error, StackTrace trace) {
    serviceConnection.consoleService.appendStdio('$error\n$trace');
  }

  bool get isEvalEnabled =>
      heapClass
          .classType(serviceConnection.serviceManager.rootInfoNow().package) !=
      ClassType.runtime;

  Future<void> allLiveToConsole({
    required bool includeSubclasses,
    required bool includeImplementers,
  }) async {
    ga.select(
      gac.memory,
      gac.MemoryEvent.dropAllLiveToConsole(
        includeImplementers: includeImplementers,
        includeSubclasses: includeSubclasses,
      ),
    );

    final list = await _liveInstancesAsList();

    if (list == null) {
      serviceConnection.consoleService.appendStdio(
        'Unable to select instances for the class ${heapClass.fullName}.',
      );
      return;
    }

    final selection = _objects;

    // drop to console
    serviceConnection.consoleService.appendBrowsableInstance(
      instanceRef: list,
      isolateRef: _mainIsolateRef,
      heapSelection: selection == null
          ? null
          : HeapObjectSelection(selection.heap, object: null),
    );
  }

  Future<void> oneLiveToConsole() async {
    ga.select(gac.memory, gac.MemoryEvent.dropOneLiveVariable);

    // drop to console
    serviceConnection.consoleService.appendBrowsableInstance(
      instanceRef: await _liveInstance(),
      isolateRef: _mainIsolateRef,
      heapSelection: null,
    );
  }
}

class HeapClassSampler extends ClassSampler {
  HeapClassSampler(
    HeapClassName heapClass,
    ObjectSet objects,
    AdaptedHeapData heap,
  ) : super(heapClass, heap: heap, objects: objects);

  Future<void> oneLiveStaticToConsole() async {
    final selection = _objects!;

    ga.select(gac.memory, gac.MemoryEvent.dropOneLiveVariable);
    final instances = (await _liveInstances())?.instances;

    final instanceRef = instances?.firstWhereOrNull(
      (objRef) =>
          objRef is InstanceRef &&
          selection.objects.objectsByCodes.containsKey(objRef.identityHashCode),
    ) as InstanceRef?;

    if (instanceRef == null) {
      serviceConnection.consoleService.appendStdio(
        'Unable to select instance that exist in snapshot and still alive in application.\n'
        'You may want to increase "${preferences.memory.refLimitTitle}" in memory settings.',
      );
      return;
    }

    final heapObject =
        selection.objects.objectsByCodes[instanceRef.identityHashCode!]!;

    final heapSelection =
        HeapObjectSelection(selection.heap, object: heapObject);

    // drop to console
    serviceConnection.consoleService.appendBrowsableInstance(
      instanceRef: instanceRef,
      isolateRef: _mainIsolateRef,
      heapSelection: heapSelection,
    );
  }

  void oneStaticToConsole() {
    final selection = _objects!;
    ga.select(gac.memory, gac.MemoryEvent.dropOneStaticVariable);

    final heapObject = selection.objects.objectsByCodes.values.first;
    final heapSelection =
        HeapObjectSelection(selection.heap, object: heapObject);

    // drop to console
    serviceConnection.consoleService.appendBrowsableInstance(
      instanceRef: null,
      isolateRef: _mainIsolateRef,
      heapSelection: heapSelection,
    );
  }
}
