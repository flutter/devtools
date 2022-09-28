// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../primitives/auto_dispose.dart';
import '../../../../primitives/utils.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/table_data.dart';
import '../../../profiler/cpu_profile_model.dart';
import '../../../profiler/cpu_profile_transformer.dart';

// TODO(bkonyi): make compatible with ClassHeapDetailStats for serialization /
// deserialization support.
/// A representation of a class and it's allocation tracing state.
class TracedClass with PinnableListEntry {
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

  @override
  bool operator ==(Object other) {
    if (other is! TracedClass) return false;
    return cls == other.cls &&
        instances == other.instances &&
        traceAllocations == other.traceAllocations;
  }

  @override
  int get hashCode => Object.hash(cls, instances, traceAllocations);

  @override
  bool get pinToTop => traceAllocations;
}

class AllocationProfileTracingViewController extends DisposableController
    with AutoDisposeControllerMixin {
  /// Set to `true` if the controller has not yet finished initializing.
  ValueListenable<bool> get initializing => _initializing;
  final _initializing = ValueNotifier<bool>(true);

  /// Set to `true` when `refresh()` has been called and allocation profiles
  /// are being updated, before then being set again to `false`.
  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

  /// The list of classes for the currently selected isolate.
  ValueListenable<List<TracedClass>> get filteredClassList =>
      _filteredClassList;
  final _filteredClassList = ListValueNotifier<TracedClass>([]);
  final _unfilteredClassList = <TracedClass>[];

  String _currentFilter = '';

  /// The current class selection in the [AllocationTracingTable]
  ValueListenable<TracedClass?> get selectedTracedClass => _selectedTracedClass;
  final _selectedTracedClass = ValueNotifier<TracedClass?>(null);

  /// The allocation profile data for the current class selection in the
  /// [AllocationTracingTable].
  CpuProfileData? get selectedTracedClassAllocationData =>
      _tracedClassesProfiles[selectedTracedClass.value?.cls.id!];

  // Keeps track of which classes have allocation tracing enabling.
  // TODO(bkonyi): handle multiple isolate case.
  final _tracedClasses = <String, TracedClass>{};
  final _tracedClassesProfiles = <String, CpuProfileData>{};

  /// The last time, in microseconds, the table was cleared. This time is based
  /// on the VM's internal monotonic clock, which is accessible through
  /// `service.getVMTimelineMicros()`.
  int _lastClearTimeMicros = 0;

  void updateClassFilter(String value, {bool force = false}) {
    if (value.isEmpty && _currentFilter.isEmpty && !force) return;
    final updatedFilter = (value.contains(_currentFilter) && !force
            ? _filteredClassList.value
            : _unfilteredClassList)
        .where(
          (e) => e.cls.name!.contains(value),
        )
        .map((e) => _tracedClasses[e.cls.id!]!)
        .toList();

    _filteredClassList.replaceAll(updatedFilter);
    _currentFilter = value;
  }

  Future<void> initialize() async {
    _initializing.value = true;

    final isolateId = serviceManager.isolateManager.selectedIsolate.value!.id!;

    // TODO(bkonyi): we don't need to request this unless we've had a hot reload.
    // We generally need to rebuild this data if we've had a hot reload or
    // switched the currently selected isolate.
    final classList = await serviceManager.service!.getClassList(isolateId);
    for (final cls in classList.classes!) {
      _tracedClasses[cls.id!] = TracedClass(cls: cls);
    }
    _filteredClassList.addAll(_tracedClasses.values);
    _unfilteredClassList.addAll(_tracedClasses.values);

    await refresh();
    _initializing.value = false;
  }

  /// Refreshes the allocation profiles for the currently traced classes.
  Future<void> refresh() async {
    _refreshing.value = true;

    final profileRequests = <Future<void>>[];
    for (final tracedClass in _filteredClassList.value) {
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

  /// Clears the allocation profiles for the currently traced classes.
  Future<void> clear() async {
    _refreshing.value = true;
    _lastClearTimeMicros =
        (await serviceManager.service!.getVMTimelineMicros()).timestamp!;

    // Reset the counts for traced classes.
    final updatedTracedClasses = _tracedClasses.map((key, value) {
      return MapEntry(key, value.copyWith(instances: 0));
    });

    _tracedClasses
      ..clear()
      ..addAll(updatedTracedClasses);

    // Reset the unfiltered class list with the new `TracedClass` instances.
    _unfilteredClassList
      ..clear()
      ..addAll(_tracedClasses.values);
    updateClassFilter(_currentFilter, force: true);

    // Since there's no longer any tracing data, clear the existing profiles.
    _tracedClassesProfiles.clear();

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
      final update = tracedClass.copyWith(
        traceAllocations: enabled,
      );
      _updateClassState(tracedClass, update);
    }
  }

  void _updateClassState(TracedClass original, TracedClass updated) {
    final cls = original.cls;
    // Update the currently selected class, if it's still being traced.
    if (_selectedTracedClass.value?.cls.id == cls.id) {
      _selectedTracedClass.value = updated;
    }
    _tracedClasses[cls.id!] = updated;
    _filteredClassList.replace(original, updated);
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

    // Note: we need to provide `timeExtentMicros` to `getAllocationTraces`,
    // otherwise the VM will respond with all samples, not just the samples
    // collected after `_lastClearTimeMicros`. We'll just use the maximum
    // Javascript integer value (2^53 - 1) to represent "infinity".
    // Request the allocation profile for the traced class.
    final trace = await service.getAllocationTraces(
      isolateId,
      classId: cls.id!,
      timeOriginMicros: _lastClearTimeMicros,
      timeExtentMicros: maxJsInt,
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
    final updated = tracedClass.copyWith(
      instances: profileData.cpuSamples.length,
    );
    _tracedClasses[cls.id!] = updated;
    _tracedClassesProfiles[cls.id!] = profileData;

    _updateClassState(tracedClass, updated);
    return profileData;
  }

  /// Updates `selectedTracedClass` with the current selection from the
  /// `AllocationTracingTable`.
  void selectTracedClass(TracedClass traced) {
    TracedClass? update = traced;
    // Clear the selection if the user tries to select the currently selected
    // class.
    if (_selectedTracedClass.value == traced) {
      update = null;
    }
    _selectedTracedClass.value = update;
  }
}
