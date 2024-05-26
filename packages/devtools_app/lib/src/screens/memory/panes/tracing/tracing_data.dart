// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/globals.dart';
import '../../../../shared/memory/class_name.dart';
import '../../../../shared/primitives/encoding.dart';
import '../../../../shared/primitives/simple_items.dart';
import '../../../../shared/primitives/utils.dart';
import '../../../../shared/table/table_data.dart';
import '../../../profiler/cpu_profile_model.dart';
import '../../../profiler/cpu_profile_transformer.dart';

@visibleForTesting
enum TracedClassJson {
  cls,
  instances,
  allocations,
}

/// A representation of a class and it's allocation tracing state.
class TracedClass with PinnableListEntry, Serializable {
  TracedClass({
    required this.cls,
  })  : traceAllocations = false,
        instances = 0,
        name = HeapClassName.fromClassRef(cls);

  TracedClass._({
    required this.cls,
    required this.instances,
    required this.traceAllocations,
  }) : name = HeapClassName.fromClassRef(cls);

  factory TracedClass.fromJson(Map<String, dynamic> json) {
    return TracedClass._(
      instances: json[TracedClassJson.instances.name] as int,
      cls: ClassRefEncodeDecode.instance.decode(json[TracedClassJson.cls.name]),
      traceAllocations: json[TracedClassJson.allocations.name] as bool,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      TracedClassJson.allocations.name: traceAllocations,
      TracedClassJson.cls.name: cls,
      TracedClassJson.instances.name: instances,
    };
  }

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

  final HeapClassName name;
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

@visibleForTesting
enum TracingIsolateStateJson {
  isolate,
  tracedClasses,
  tracedClassesProfiles,
  unfilteredClassList,
  selectedClass;
}

/// Contains allocation tracing state for a single isolate.
///
/// `AllocationProfileTracingController` is effectively only used to provide
/// consumers the allocation tracing state for the currently selected isolate.
class TracingIsolateState with Serializable {
  TracingIsolateState({
    required this.mode,
    required this.isolate,
    Map<String, TracedClass>? tracedClasses,
    Map<String, CpuProfileData>? tracedClassesProfiles,
    List<TracedClass>? unfilteredClassList,
    String? selectedClass,
  }) {
    this.unfilteredClassList = unfilteredClassList ?? [];
    this.tracedClasses = tracedClasses ?? {};
    this.tracedClassesProfiles = tracedClassesProfiles ?? {};

    if (selectedClass == null) {
      selectedTracedClass.value = null;
    } else {
      selectedTracedClass.value = this.unfilteredClassList.firstWhereOrNull(
            (e) => e.name.fullName == selectedClass,
          );
    }
  }

  TracingIsolateState.empty()
      : this(isolate: IsolateRef(), mode: ControllerCreationMode.connected);

  factory TracingIsolateState.fromJson(Map<String, dynamic> json) {
    return TracingIsolateState(
      mode: ControllerCreationMode.offlineData,
      isolate: IsolateRefEncodeDecode.instance
          .decode(json[TracingIsolateStateJson.isolate.name]),
      tracedClasses:
          (json[TracingIsolateStateJson.tracedClasses.name] as Map).map(
        (key, value) => MapEntry(
          key,
          deserialize<TracedClass>(value, TracedClass.fromJson),
        ),
      ),
      tracedClassesProfiles:
          (json[TracingIsolateStateJson.tracedClassesProfiles.name] as Map).map(
        (key, value) => MapEntry(
          key,
          deserialize<CpuProfileData>(value, CpuProfileData.fromJson),
        ),
      ),
      unfilteredClassList:
          (json[TracingIsolateStateJson.unfilteredClassList.name] as List)
              .map((e) => deserialize<TracedClass>(e, TracedClass.fromJson))
              .toList(),
      selectedClass:
          json[TracingIsolateStateJson.selectedClass.name] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      TracingIsolateStateJson.isolate.name: isolate,
      TracingIsolateStateJson.tracedClasses.name: tracedClasses,
      TracingIsolateStateJson.tracedClassesProfiles.name: tracedClassesProfiles,
      TracingIsolateStateJson.unfilteredClassList.name: unfilteredClassList,
      TracingIsolateStateJson.selectedClass.name:
          selectedTracedClass.value?.name.fullName,
    };
  }

  final ControllerCreationMode mode;

  final IsolateRef isolate;

  // Keeps track of which classes have allocation tracing enabling.
  late final Map<String, TracedClass> tracedClasses;
  late final Map<String, CpuProfileData> tracedClassesProfiles;
  late final List<TracedClass> unfilteredClassList;

  /// The current class selection in the [AllocationTracingTable]
  final selectedTracedClass = ValueNotifier<TracedClass?>(null);

  /// The list of classes for the currently selected isolate.
  ValueListenable<List<TracedClass>> get filteredClassList =>
      _filteredClassList;
  final _filteredClassList = ListValueNotifier<TracedClass>([]);

  String currentFilter = '';

  /// The allocation profile data for the current class selection in the
  /// [AllocationTracingTable].
  CpuProfileData? get selectedTracedClassAllocationData {
    return tracedClassesProfiles[selectedTracedClass.value?.cls.id!];
  }

  /// The last time, in microseconds, the table was cleared. This time is based
  /// on the VM's internal monotonic clock, which is accessible through
  /// `service.getVMTimelineMicros()`.
  int _lastClearTimeMicros = 0;

  Future<void> initialize() async {
    if (mode == ControllerCreationMode.connected) {
      final classList = await serviceConnection.serviceManager.service!
          .getClassList(isolate.id!);
      for (final cls in classList.classes!) {
        tracedClasses[cls.id!] = TracedClass(cls: cls);
      }
      unfilteredClassList.addAll(tracedClasses.values);
    } else {
      for (final kv in tracedClassesProfiles.entries) {
        final profile = kv.value;
        profile.processed = true;
        _setProfile(tracedClasses[kv.key]!, profile);
      }
    }
    _filteredClassList.replaceAll(unfilteredClassList);
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

  void updateClassFilter(String newFilter, {bool force = false}) {
    if (newFilter.isEmpty && currentFilter.isEmpty && !force) return;
    final updatedFilteredClassList =
        (newFilter.caseInsensitiveContains(currentFilter) && !force
                ? _filteredClassList.value
                : unfilteredClassList)
            .where(
              (e) => e.cls.name!.caseInsensitiveContains(newFilter),
            )
            .map((e) => tracedClasses[e.cls.id!]!)
            .toList();

    _filteredClassList.replaceAll(updatedFilteredClassList);
    currentFilter = newFilter;
  }

  /// Clears the allocation profiles for the currently traced classes.
  Future<void> clear() async {
    _lastClearTimeMicros =
        (await serviceConnection.serviceManager.service!.getVMTimelineMicros())
            .timestamp!;
    // Reset the counts for traced classes.
    final updatedTracedClasses = tracedClasses.map((key, value) {
      return MapEntry(key, value.copyWith(instances: 0));
    });

    tracedClasses
      ..clear()
      ..addAll(updatedTracedClasses);

    // Reset the unfiltered class list with the new `TracedClass` instances.
    unfilteredClassList
      ..clear()
      ..addAll(tracedClasses.values);
    updateClassFilter(currentFilter, force: true);

    // Since there's no longer any tracing data, clear the existing profiles.
    tracedClassesProfiles.clear();
  }

  /// Enables or disables tracing of allocations of [cls].
  Future<void> setAllocationTracingForClass(ClassRef cls, bool enabled) async {
    final service = serviceConnection.serviceManager.service!;
    final isolate =
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value!;
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
      selectedTracedClass.value = updated;
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
    final service = serviceConnection.serviceManager.service!;
    final isolateId = serviceConnection
        .serviceManager.isolateManager.selectedIsolate.value!.id!;
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

    await _setProfile(tracedClass, profileData);

    return profileData;
  }

  Future<void> _setProfile(
    TracedClass tracedClass,
    CpuProfileData profileData,
  ) async {
    // Process the allocation profile into a tree. We can reuse the transformer
    // from the CPU Profiler tooling since it also makes use of a `CpuSamples`
    // response.
    final transformer = CpuProfileTransformer();
    await transformer.processData(profileData, processId: '');

    // Update the traced class data with the updated profile length.
    final updated = tracedClass.copyWith(
      instances: profileData.cpuSamples.length,
    );
    final cls = tracedClass.cls;
    tracedClasses[cls.id!] = updated;
    tracedClassesProfiles[cls.id!] = profileData;

    _updateClassState(tracedClass, updated);
  }
}
