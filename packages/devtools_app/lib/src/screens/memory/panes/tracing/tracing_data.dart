// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
  clazz,
  instances,
  allocations,
}

/// A representation of a class and it's allocation tracing state.
class TracedClass with PinnableListEntry, Serializable {
  TracedClass({
    required this.clazz,
  })  : traceAllocations = false,
        instances = 0,
        name = HeapClassName.fromClassRef(clazz);

  TracedClass._({
    required this.clazz,
    required this.instances,
    required this.traceAllocations,
  }) : name = HeapClassName.fromClassRef(clazz);

  factory TracedClass.fromJson(Map<String, dynamic> json) {
    return TracedClass._(
      instances: json[TracedClassJson.instances.name] as int,
      clazz: ClassRefEncodeDecode.instance
          .decode(json[TracedClassJson.clazz.name]),
      traceAllocations: json[TracedClassJson.allocations.name] as bool,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      TracedClassJson.allocations.name: traceAllocations,
      TracedClassJson.clazz.name: clazz,
      TracedClassJson.instances.name: instances,
    };
  }

  TracedClass copyWith({
    ClassRef? clazz,
    int? instances,
    bool? traceAllocations,
  }) {
    return TracedClass._(
      clazz: clazz ?? this.clazz,
      instances: instances ?? this.instances,
      traceAllocations: traceAllocations ?? this.traceAllocations,
    );
  }

  final HeapClassName name;
  final ClassRef clazz;
  final int instances;
  final bool traceAllocations;

  @override
  bool operator ==(Object other) {
    if (other is! TracedClass) return false;
    return clazz == other.clazz &&
        instances == other.instances &&
        traceAllocations == other.traceAllocations;
  }

  @override
  int get hashCode => Object.hash(clazz, instances, traceAllocations);

  @override
  bool get pinToTop => traceAllocations;

  @override
  String toString() =>
      '${clazz.name} instances: $instances trace: $traceAllocations';
}

@visibleForTesting
enum TracingIsolateStateJson {
  isolate,
  classes,
  profiles;
}

/// Contains allocation tracing state for a single isolate.
///
/// `AllocationProfileTracingController` is effectively only used to provide
/// consumers the allocation tracing state for the currently selected isolate.
class TracingIsolateState with Serializable {
  TracingIsolateState({
    required this.mode,
    required this.isolate,
    Map<String, CpuProfileData>? profiles,
    List<TracedClass>? classes,
    String? selectedClass,
  }) {
    this.classes = classes ?? [];
    classesById = {for (var e in this.classes) e.clazz.id!: e};
    this.profiles = profiles ?? {};
  }

  TracingIsolateState.empty()
      : this(isolate: IsolateRef(), mode: ControllerCreationMode.connected);

  factory TracingIsolateState.fromJson(Map<String, dynamic> json) {
    return TracingIsolateState(
      mode: ControllerCreationMode.offlineData,
      isolate: IsolateRefEncodeDecode.instance
          .decode(json[TracingIsolateStateJson.isolate.name]),
      profiles: (json[TracingIsolateStateJson.profiles.name] as Map).map(
        (key, value) => MapEntry(
          key,
          deserialize<CpuProfileData>(value, CpuProfileData.fromJson),
        ),
      ),
      classes: (json[TracingIsolateStateJson.classes.name] as List)
          .map((e) => deserialize<TracedClass>(e, TracedClass.fromJson))
          .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      TracingIsolateStateJson.isolate.name: isolate,
      TracingIsolateStateJson.classes.name: classesById.values.toList(),
      TracingIsolateStateJson.profiles.name: profiles,
    };
  }

  final ControllerCreationMode mode;

  final IsolateRef isolate;

  // Keeps track of which classes have allocation tracing enabling.
  late final Map<String, TracedClass> classesById;
  late final Map<String, CpuProfileData> profiles;
  late final List<TracedClass> classes;

  /// The current class selection in the [AllocationTracingTable]
  final selectedClass = ValueNotifier<TracedClass?>(null);

  /// The list of classes for the currently selected isolate.
  ValueListenable<List<TracedClass>> get filteredClassList =>
      _filteredClassList;
  final _filteredClassList = ListValueNotifier<TracedClass>([]);

  String currentFilter = '';

  /// The allocation profile data for the current class selection in the
  /// [AllocationTracingTable].
  CpuProfileData? get selectedClassProfile {
    return profiles[selectedClass.value?.clazz.id!];
  }

  /// The last time, in microseconds, the table was cleared. This time is based
  /// on the VM's internal monotonic clock, which is accessible through
  /// `service.getVMTimelineMicros()`.
  int _lastClearTimeMicros = 0;

  Future<void> initialize() async {
    if (mode == ControllerCreationMode.connected) {
      final classList = await serviceConnection.serviceManager.service!
          .getClassList(isolate.id!);
      for (final clazz in classList.classes!) {
        classesById[clazz.id!] = TracedClass(clazz: clazz);
      }
      classes.addAll(classesById.values);
    } else {
      for (final kv in profiles.entries) {
        final profile = kv.value;
        await _setProfile(classesById[kv.key]!, profile);
      }
    }
    updateClassFilter('', force: true);
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
                : classes)
            .where(
              (e) => e.clazz.name!.caseInsensitiveContains(newFilter),
            )
            .map((e) => classesById[e.clazz.id!]!)
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
    final updatedTracedClasses = classesById.map((key, value) {
      return MapEntry(key, value.copyWith(instances: 0));
    });

    classesById
      ..clear()
      ..addAll(updatedTracedClasses);

    // Reset the unfiltered class list with the new `TracedClass` instances.
    classes
      ..clear()
      ..addAll(classesById.values);
    updateClassFilter(currentFilter, force: true);

    // Since there's no longer any tracing data, clear the existing profiles.
    profiles.clear();
  }

  /// Enables or disables tracing of allocations of [clazz].
  Future<void> setAllocationTracingForClass(
    ClassRef clazz,
    bool enabled,
  ) async {
    final service = serviceConnection.serviceManager.service!;
    final isolate =
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value!;
    final tracedClass = classesById[clazz.id!]!;

    // Only update if the tracing state has changed for `clazz`.
    if (tracedClass.traceAllocations != enabled) {
      await service.setTraceClassAllocation(isolate.id!, clazz.id!, enabled);
      final update = tracedClass.copyWith(
        traceAllocations: enabled,
      );
      _updateClassState(tracedClass, update);
    }
  }

  void _updateClassState(TracedClass original, TracedClass updated) {
    final clazz = original.clazz;
    // Update the currently selected class, if it's still being traced.
    if (selectedClass.value?.clazz.id == clazz.id) {
      selectedClass.value = updated;
    }
    classesById[clazz.id!] = updated;
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
    final clazz = tracedClass.clazz;

    // Note: we need to provide `timeExtentMicros` to `getAllocationTraces`,
    // otherwise the VM will respond with all samples, not just the samples
    // collected after `_lastClearTimeMicros`. We'll just use the maximum
    // Javascript integer value (2^53 - 1) to represent "infinity".
    // Request the allocation profile for the traced class.
    final trace = await service.getAllocationTraces(
      isolateId,
      classId: clazz.id!,
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
    final clazz = tracedClass.clazz;
    classesById[clazz.id!] = updated;
    profiles[clazz.id!] = profileData;

    _updateClassState(tracedClass, updated);
  }
}
