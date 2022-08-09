// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../primitives/auto_dispose.dart';
import '../../../../shared/globals.dart';
import '../../../profiler/cpu_profile_model.dart';
import '../../../profiler/cpu_profile_transformer.dart';

class TracedClass {
  TracedClass({
    required this.cls,
  })  : traceAllocations = false,
        instances = 0;

  TracedClass._({
    required this.cls,
    required this.instances,
    required this.traceAllocations,
  });

  TracedClass copyWith({
    ClassRef? cls,
    int? instances,
    bool? traceAllocations,
  }) {
    return TracedClass._(
      cls: cls ?? this.cls,
      instances: instances ?? this.instances,
      traceAllocations: traceAllocations ?? this.traceAllocations,
    );
  }

  final ClassRef cls;
  final int instances;
  final bool traceAllocations;
}

class AllocationProfileTracingViewController extends DisposableController
    with AutoDisposeControllerMixin {
  ValueListenable<bool> get initializing => _initializing;
  final _initializing = ValueNotifier<bool>(true);

  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

  List<TracedClass> get classList => _tracedClasses.values.toList();

  ValueListenable<TracedClass?> get selectedTracedClass =>
      _selectedTracedClass;
  final _selectedTracedClass = ValueNotifier<TracedClass?>(null);

  CpuProfileData? get selectedTracedClassAllocationData =>
      _tracedClassesProfiles[selectedTracedClass.value?.cls.id!];

  // Keeps track of which classes have allocation tracing enabling.
  // TODO(bkonyi): handle multiple isolate case.
  final _tracedClasses = <String, TracedClass>{};
  final _tracedClassesProfiles = <String, CpuProfileData>{};

  Future<void> initialize() async {
    _initializing.value = true;
    await refresh();
    _initializing.value = false;
  }

  /// Refreshes the allocation profiles for the currently traced classes.
  Future<void> refresh() async {
    _refreshing.value = true;
    final isolateId = serviceManager.isolateManager.selectedIsolate.value!.id!;

    // TODO(bkonyi): we don't need to request this unless we've had a hot reload.
    // We generally need to rebuild this data if we've had a hot reload or
    // switched the currently selected isolate.
    final classList = await serviceManager.service!.getClassList(isolateId);

    final profileRequests = <Future<void>>[];
    for (final cls in classList.classes!) {
      final tracedClass = _tracedClasses.putIfAbsent(
        cls.id!,
        () => TracedClass(cls: cls),
      );

      // If allocation tracing is enabled for this class, request an updated
      // profile.
      if (tracedClass.traceAllocations) {
        profileRequests.add(_getAllocationProfileForClass(tracedClass));
      }
    }

    // All profile requests need to complete before we can consider the refresh
    // completed.
    await Future.wait(profileRequests);
    _refreshing.value = false;
  }

  /// Enables or disables tracing of allocations of [cls].
  Future<void> setAllocationTracingForClass(ClassRef cls, bool enabled) async {
    final service = serviceManager.service!;
    final isolate = serviceManager.isolateManager.selectedIsolate.value!;
    final tracedClass = _tracedClasses[cls.id!]!;

    // Only update if the tracing state has changed for `cls`.
    if (tracedClass.traceAllocations != enabled) {
      await service.setTraceClassAllocation(isolate.id!, cls.id!, enabled);
      _tracedClasses[cls.id!] = tracedClass.copyWith(
        traceAllocations: enabled,
      );
    }
  }

  Future<CpuProfileData> _getAllocationProfileForClass(
    TracedClass tracedClass,
  ) async {
    if (!tracedClass.traceAllocations) {
      throw StateError(
        'Attempted to request an allocation profile for a non-traced class',
      );
    }
    final service = serviceManager.service!;
    final isolateId = serviceManager.isolateManager.selectedIsolate.value!.id!;
    final cls = tracedClass.cls;

    // Request the allocation profile for the traced class.
    final trace = await service.getAllocationTraces(
      isolateId,
      classId: cls.id!,
    );

    final profileData = await CpuProfileData.generateFromCpuSamples(
      isolateId: isolateId,
      cpuSamples: trace,
    );

    // Process the allocation profile into a tree. We can reuse the transformer
    // from the CPU Profiler tooling since it also makes use of a `CpuSamples`
    // response.
    final transformer = CpuProfileTransformer();
    await transformer.processData(profileData, processId: '');

    // Update the traced class data with the updated profile length.
    _tracedClasses[cls.id!] = tracedClass.copyWith(
      instances: profileData.cpuSamples.length,
    );

    // Expand all profiles by default. We may want to revisit this if
    // we don't want trees to be automatically expanded or we want to
    // keep expansion state for existing profiles.
    for (final root in profileData.bottomUpRoots) {
      root.expandCascading();
    }
    _tracedClassesProfiles[cls.id!] = profileData;

    // Update the currently selected class, if it's still being traced.
    if (_selectedTracedClass.value?.cls.id == cls.id) {
      _selectedTracedClass.value = tracedClass;
    }

    return profileData;
  }

  /// Returns `true` if allocations of [cls] are currently being traced.
  bool isAllocationTracingEnabledForClass(ClassRef cls) {
    return _tracedClasses[cls.id!]?.traceAllocations ?? false;
  }

  /// Updates `selectedTracedClass` with the current selection from the
  /// `AllocationTracingTable`. 
  void selectTracedClass(TracedClass? traced) {
      _selectedTracedClass.value = traced;
  }
}
