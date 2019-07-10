// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart';

import '../globals.dart';
import '../vm_service_wrapper.dart';
import 'memory_protocol.dart';
import 'memory_service.dart';

/// This class contains the business logic for [memory.dart].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM and will help
/// simplify porting this code to work with Hummingbird.
class MemoryController {
  MemoryController();

  String get _isolateId => serviceManager.isolateManager.selectedIsolate.id;

  final StreamController<MemoryTracker> _memoryTrackerController =
      StreamController<MemoryTracker>.broadcast();

  Stream<MemoryTracker> get onMemory => _memoryTrackerController.stream;

  final StreamController<void> _disconnectController =
      StreamController<void>.broadcast();

  Stream<void> get onDisconnect => _disconnectController.stream;

  MemoryTracker _memoryTracker;

  MemoryTracker get memoryTracker => _memoryTracker;

  bool get hasStarted => _memoryTracker != null;

  bool hasStopped;

  void _handleIsolateChanged() {
    // TODO(terry): Need an event on the controller for this too?
  }

  void _handleConnectionStart(VmServiceWrapper service) {
    _memoryTracker = MemoryTracker(service);
    _memoryTracker.start();

    _memoryTracker.onChange.listen((Null _) {
      _memoryTrackerController.add(_memoryTracker);
    });
  }

  void _handleConnectionStop(dynamic event) {
    _memoryTracker?.stop();
    _memoryTrackerController.add(_memoryTracker);

    _disconnectController.add(Null);
    hasStopped = true;
  }

  Future<void> startTimeline() async {
    serviceManager.isolateManager.onSelectedIsolateChanged.listen((_) {
      _handleIsolateChanged();
    });

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);
  }

  Future<List<ClassHeapDetailStats>> resetAllocationProfile() =>
      getAllocationProfile(reset: true);

  // 'reset': true to reset the object allocation accumulators
  Future<List<ClassHeapDetailStats>> getAllocationProfile(
      {bool reset = false}) async {
    final AllocationProfile allocationProfile =
        await serviceManager.service.getAllocationProfile(
      _isolateId,
      reset: reset,
    );
    return allocationProfile.members
        .map((ClassHeapStats stats) => ClassHeapDetailStats(stats.json))
        .where((ClassHeapDetailStats stats) {
      return stats.instancesCurrent > 0 || stats.instancesAccumulated > 0;
    }).toList();
  }

  Future<List<InstanceSummary>> getInstances(
      String classRef, String className, int maxInstances) async {
    // TODO(terry): Expose as a stream to reduce stall when querying for 1000s
    // TODO(terry): of instances.
    final InstanceSet instanceSet = await serviceManager.service.getInstances(
      _isolateId,
      classRef,
      maxInstances,
      classId: classRef,
    );

    return instanceSet.instances
        .map((ObjRef ref) => InstanceSummary(classRef, className, ref.id))
        .toList();
  }

  Future<dynamic> getObject(String objectRef) async =>
      await serviceManager.service.getObject(
        _isolateId,
        objectRef,
      );

  Future<void> gc() async {
    await serviceManager.service.getAllocationProfile(
      _isolateId,
      gc: true,
    );
  }

  // Temporary hack to allow accessing private fields(e.g., _extra) using eval
  // of '_extra.hashCode' to fetch the hashCode of the object of that field.
  // Used to find the object which allocated/references the object being viewed.
  Future<bool> matchObject(
      String objectRef, String fieldName, int instanceHashCode) async {
    final dynamic object = await getObject(objectRef);
    if (object is Instance) {
      final Instance instance = object;
      final List<BoundField> fields = instance.fields;
      for (var field in fields) {
        if (field.decl.name == fieldName) {
          final InstanceRef ref = field.value;
          final evalResult = await evaluate(ref.id, 'hashCode');
          final int objHashCode = int.parse(evalResult?.valueAsString);
          if (objHashCode == instanceHashCode) {
            return true;
          }
        }
      }
    }

    if (object is Sentinel) {
      // TODO(terry): Need more graceful handling of sentinels.
      print('Trying to matchObject with a Sentinel $objectRef');
    }

    return false;
  }
}
