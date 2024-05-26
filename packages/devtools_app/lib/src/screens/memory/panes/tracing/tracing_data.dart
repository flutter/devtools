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
  classes,
  profiles,
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
    Map<String, CpuProfileData>? profiles,
    List<TracedClass>? classes,
    String? selectedClass,
  }) {
    this.classes = classes ?? [];
    classesById = {for (var e in this.classes) e.cls.id!: e};
    this.profiles = profiles ?? {};

    if (selectedClass == null) {
      this.selectedClass.value = null;
    } else {
      this.selectedClass.value = this.classes.firstWhereOrNull(
            (e) => e.name.fullName == selectedClass,
          );
    }
    updateClassFilter('', force: true);
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
      selectedClass:
          json[TracingIsolateStateJson.selectedClass.name] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      TracingIsolateStateJson.isolate.name: isolate,
      TracingIsolateStateJson.classes.name: classesById.values.toList(),
      TracingIsolateStateJson.profiles.name: profiles,
      TracingIsolateStateJson.selectedClass.name:
          selectedClass.value?.name.fullName,
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
    return profiles[selectedClass.value?.cls.id!];
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
        classesById[cls.id!] = TracedClass(cls: cls);
      }
      classes.addAll(classesById.values);
    } else {
      for (final kv in profiles.entries) {
        final profile = kv.value;
        await _setProfile(classesById[kv.key]!, profile);
      }
    }
    _filteredClassList.replaceAll(classes);
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
              (e) => e.cls.name!.caseInsensitiveContains(newFilter),
            )
            .map((e) => classesById[e.cls.id!]!)
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

  /// Enables or disables tracing of allocations of [cls].
  Future<void> setAllocationTracingForClass(ClassRef cls, bool enabled) async {
    final service = serviceConnection.serviceManager.service!;
    final isolate =
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value!;
    final tracedClass = classesById[cls.id!]!;

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
    if (selectedClass.value?.cls.id == cls.id) {
      selectedClass.value = updated;
    }
    classesById[cls.id!] = updated;
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
    classesById[cls.id!] = updated;
    profiles[cls.id!] = profileData;

    _updateClassState(tracedClass, updated);
  }
}
