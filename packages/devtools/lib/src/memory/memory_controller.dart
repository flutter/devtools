// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart';

import '../globals.dart';
import '../ui/analytics.dart' as ga;
import '../vm_service_wrapper.dart';

import 'memory_protocol.dart';
import 'memory_service.dart';

typedef BuildHoverCard = void Function(
  String referenceName,
  /* Field that owns reference to allocated memory */
  String owningAllocator,
  /* Parent class that allocated memory. */
  bool owningAllocatorIsAbstract,
  /* is owning class abstract */
);

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

  ClassHeapDetailStats _searchClass(
    List<ClassHeapDetailStats> allClasses,
    String className,
  ) =>
      allClasses.firstWhere((dynamic stat) => stat.classRef.name == className,
          orElse: () => null);

  // Compute the inboundRefs, who allocated the class/which field owns the ref.
  void computeInboundRefs(
    List<ClassHeapDetailStats> allClasses,
    InboundReferences refs,
    BuildHoverCard buildCallback,
  ) {
    for (InboundReference element in refs.elements) {
      // Could be a reference to an evaluate so this isn't known.

      // Looks like an object created from an evaluate, ignore it.
      if (element.parentField == null && element.json == null) continue;

      // TODO(terry): Verify looks like internal class (maybe to C code).
      if (element.parentField.owner != null &&
          element.parentField.owner.name.contains('&')) continue;

      String referenceName;
      String owningAllocator; // Class or library that allocated.
      bool owningAllocatorIsAbstract;

      switch (element.parentField.runtimeType.toString()) {
        case 'ClassRef':
          final ClassRef classRef = element.classRef;
          owningAllocator = classRef.name;
          // TODO(terry): Quick way to detect if class is probably abstract-
          // TODO(terry): Does it exist in the class list table?
          owningAllocatorIsAbstract =
              _searchClass(allClasses, owningAllocator) == null;
          break;
        case 'FieldRef':
          final FieldRef fieldRef = element.fieldRef;
          referenceName = fieldRef.name;
          switch (fieldRef.owner.runtimeType.toString()) {
            case 'ClassRef':
              final ClassRef classRef = ClassRef.parse(fieldRef.owner.json);
              owningAllocator = classRef.name;
              // TODO(terry): Quick way to detect if class is probably abstract-
              // TODO(terry): Does it exist in the class list table?
              owningAllocatorIsAbstract =
                  _searchClass(allClasses, owningAllocator) == null;
              break;
            case 'Library':
            case 'LibraryRef':
              final Library library = Library.parse(fieldRef.owner.json);
              owningAllocator = 'Library ${library?.name ?? ""}';
              break;
          }
          break;
        case 'FuncRef':
          ga.error(
              'Error(hoverInstanceAllocations): '
              'Unhandled ${element.parentField.runtimeType}',
              false);
          // TODO(terry): TBD
          // final FuncRef funcRef = element.funcRef;
          break;
        case 'Instance':
          ga.error(
              'Error(hoverInstanceAllocations): '
              ' Unhandled ${element.parentField.runtimeType}',
              false);
          // TODO(terry): TBD
          // final Instance instance = element.instance;
          break;
        case 'InstanceRef':
          ga.error(
              'Error(hoverInstanceAllocations): '
              'Unhandled ${element.parentField.runtimeType}',
              false);
          // TODO(terry): TBD
          // final InstanceRef instanceRef = element.instanceRef;
          break;
        case 'Library':
        case 'LibraryRef':
          ga.error(
              'Error(hoverInstanceAllocations): '
              'Unhandled ${element.parentField.runtimeType}',
              false);
          // TODO(terry): TBD
          // final Library library = element.library;
          break;
        case 'NullVal':
        case 'NullValRef':
          ga.error(
              'Error(hoverInstanceAllocations): '
              'Unhandled ${element.parentField.runtimeType}',
              false);
          // TODO(terry): TBD
          // final NullVal nullValue = element.nullVal;
          break;
        case 'Obj':
        case 'ObjRef':
          ga.error(
              'Error(hoverInstanceAllocations): '
              'Unhandled ${element.parentField.runtimeType}',
              false);
          // TODO(terry): TBD
          // final Obj obj = element.obj;
          break;
        default:
          ga.error(
              'Error(hoverInstanceAllocations): '
              'Unhandled inbound ${element.parentField.runtimeType}',
              false);
      }

      // call the build UI callback.
      if (buildCallback != null)
        buildCallback(
          referenceName,
          owningAllocator,
          owningAllocatorIsAbstract,
        );
    }
  }

  // Temporary hack to allow accessing private fields(e.g., _extra) using eval
  // of '_extra.hashCode' to fetch the hashCode of the object of that field.
  // Used to find the object which allocated/references the object being viewd.
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
