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

class _HeapSelection {
  _HeapSelection(this.objects, this.heap);

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
        _selection = objects == null ? null : _HeapSelection(objects, heap!);

  final HeapClassName heapClass;
  final _HeapSelection? _selection;

  IsolateRef get _mainIsolateRef =>
      serviceManager.isolateManager.mainIsolate.value!;

  Future<InstanceSet?> _liveInstances() async {
    try {
      final isolateId = _mainIsolateRef.id!;

      final theClass = await findClass(isolateId, heapClass);
      if (theClass == null) return null;

      return await serviceManager.service!.getInstances(
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

      return await serviceManager.service!.getInstancesAsList(
        isolateId,
        theClass.id!,
      );
    } catch (error, trace) {
      _outputError(error, trace);
      return null;
    }
  }

  void _outputError(Object error, StackTrace trace) {
    serviceManager.consoleService.appendStdio('$error\n$trace');
  }

  bool get isEvalEnabled =>
      heapClass.classType(serviceManager.rootInfoNow().package) !=
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
      serviceManager.consoleService.appendStdio(
        'Unable to select instances for the class ${heapClass.fullName}.',
      );
      return;
    }

    final selection = _selection;

    // drop to console
    serviceManager.consoleService.appendBrowsableInstance(
      instanceRef: list,
      isolateRef: _mainIsolateRef,
      heapSelection: selection == null
          ? null
          : HeapObjectSelection(selection.heap, object: null),
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
    final selection = _selection!;

    ga.select(gac.memory, gac.MemoryEvent.dropOneLiveVariable);
    final instances = (await _liveInstances())?.instances;

    final instanceRef = instances?.firstWhereOrNull(
      (objRef) =>
          objRef is InstanceRef &&
          selection.objects.objectsByCodes.containsKey(objRef.identityHashCode),
    ) as InstanceRef?;

    if (instanceRef == null) {
      serviceManager.consoleService.appendStdio(
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
    serviceManager.consoleService.appendBrowsableInstance(
      instanceRef: instanceRef,
      isolateRef: _mainIsolateRef,
      heapSelection: heapSelection,
    );
  }

  void oneStaticToConsole() {
    final selection = _selection!;
    ga.select(gac.memory, gac.MemoryEvent.dropOneStaticVariable);

    final heapObject = selection.objects.objectsByCodes.values.first;
    final heapSelection =
        HeapObjectSelection(selection.heap, object: heapObject);

    // drop to console
    serviceManager.consoleService.appendBrowsableInstance(
      instanceRef: null,
      isolateRef: _mainIsolateRef,
      heapSelection: heapSelection,
    );
  }
}
