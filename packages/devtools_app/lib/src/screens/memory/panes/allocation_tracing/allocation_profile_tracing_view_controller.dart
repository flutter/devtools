// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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

  @override
  String toString() =>
      '${cls.name} instances: $instances trace: $traceAllocations';
}

/// Contains allocation tracing state for a single isolate.
///
/// `AllocationProfileTracingController` is effectively only used to provide
/// consumers the allocation tracing state for the currently selected isolate.
class AllocationProfileTracingIsolateState {
  AllocationProfileTracingIsolateState({required this.isolate});

  AllocationProfileTracingIsolateState._empty() : isolate = IsolateRef();

  final IsolateRef isolate;

  // Keeps track of which classes have allocation tracing enabling.
  final tracedClasses = <String, TracedClass>{};
  final tracedClassesProfiles = <String, CpuProfileData>{};
  final unfilteredClassList = <TracedClass>[];

  /// The current class selection in the [AllocationTracingTable]
  ValueListenable<TracedClass?> get selectedTracedClass => _selectedTracedClass;
  final _selectedTracedClass = ValueNotifier<TracedClass?>(null);

  /// The list of classes for the currently selected isolate.
  ValueListenable<List<TracedClass>> get filteredClassList =>
      _filteredClassList;
  final _filteredClassList = ListValueNotifier<TracedClass>([]);

  String _currentFilter = '';

  /// The allocation profile data for the current class selection in the
  /// [AllocationTracingTable].
  CpuProfileData? get selectedTracedClassAllocationData {
    return tracedClassesProfiles[selectedTracedClass.value?.cls.id!];
  }

  Future<void> initialize() async {
    final classList = await serviceManager.service!.getClassList(isolate.id!);
    for (final cls in classList.classes!) {
      tracedClasses[cls.id!] = TracedClass(cls: cls);
    }
    _filteredClassList.replaceAll(tracedClasses.values);
    unfilteredClassList.addAll(tracedClasses.values);
  }

  Future<void> refresh() async {
    final profileRequests = <Future<void>>[];
    for (final tracedClass in filteredClassList.value) {
      // If allocation tracing is enabled for this class, request an updated
      // profile.
      if (tracedClass.traceAllocations) {
        profileRequests.add(_getAllocationProfileForClass(tracedClass));
      }
    }

    // All profile requests need to complete before we can consider the refresh
    // completed.
    await Future.wait(profileRequests);
  }

  void updateClassFilter(String value) {
    if (value.isEmpty && _currentFilter.isEmpty) return;
    final updatedFilter = (value.contains(_currentFilter)
            ? _filteredClassList.value
            : unfilteredClassList)
        .where(
          (e) => e.cls.name!.contains(value),
        )
        .map((e) => tracedClasses[e.cls.id!]!)
        .toList();

    _filteredClassList.replaceAll(updatedFilter);
    _currentFilter = value;
  }

  /// Enables or disables tracing of allocations of [cls].
  Future<void> setAllocationTracingForClass(ClassRef cls, bool enabled) async {
    final service = serviceManager.service!;
    final isolate = serviceManager.isolateManager.selectedIsolate.value!;
    final tracedClass = tracedClasses[cls.id!]!;

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
    if (selectedTracedClass.value?.cls.id == cls.id) {
      _selectedTracedClass.value = updated;
    }
    tracedClasses[cls.id!] = updated;
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
    final updated = tracedClass.copyWith(
      instances: profileData.cpuSamples.length,
    );
    tracedClasses[cls.id!] = updated;
    tracedClassesProfiles[cls.id!] = profileData;

    _updateClassState(tracedClass, updated);
    return profileData;
  }

  /// Updates `selectedTracedClass` with the current selection from the
  /// `AllocationTracingTable`.
  void selectTracedClass(TracedClass traced) {
    TracedClass? update = traced;
    // Clear the selection if the user tries to select the currently selected
    // class.
    if (selectedTracedClass.value == traced) {
      update = null;
    }
    _selectedTracedClass.value = update;
  }
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

  /// The allocation tracing state for the currently selected isolate.
  ValueListenable<AllocationProfileTracingIsolateState> get stateForIsolate =>
      _stateForIsolateListenable;
  final _stateForIsolateListenable =
      ValueNotifier<AllocationProfileTracingIsolateState>(
    AllocationProfileTracingIsolateState._empty(),
  );

  final _stateForIsolate = <String, AllocationProfileTracingIsolateState>{};

  /// The [TextEditingController] for the 'Class Filter' text field.
  final textEditingController = TextEditingController();

  Future<void> initialize() async {
    _initializing.value = true;

    final updateState = () async {
      final isolate = serviceManager.isolateManager.selectedIsolate.value!;
      final isolateId = isolate.id!;
      var state = _stateForIsolate[isolateId];
      if (state == null) {
        // TODO(bkonyi): we don't need to request this unless we've had a hot reload.
        // We generally need to rebuild this data if we've had a hot reload or
        // switched the currently selected isolate.
        state = AllocationProfileTracingIsolateState(isolate: isolate);
        await state.initialize();
        _stateForIsolate[isolateId] = state;
      }
      // Restore the previously applied filter for the isolate.
      textEditingController.text = state._currentFilter;
      _stateForIsolateListenable.value = state;
    };

    addAutoDisposeListener(
      serviceManager.isolateManager.selectedIsolate,
      updateState,
    );

    await updateState();
    await refresh();

    _initializing.value = false;
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  /// Refreshes the allocation profiles for the current isolate's traced classes.
  Future<void> refresh() async {
    _refreshing.value = true;
    await stateForIsolate.value.refresh();
    _refreshing.value = false;
  }

  /// Enables or disables tracing of allocations of [cls] in the current
  /// isolate.
  Future<void> setAllocationTracingForClass(ClassRef cls, bool enabled) async {
    await stateForIsolate.value.setAllocationTracingForClass(cls, enabled);
  }

  /// Updates the class filter criteria for the current isolate's allocation
  /// tracing state.
  void updateClassFilter(String value) {
    stateForIsolate.value.updateClassFilter(value);
  }
}
