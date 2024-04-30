// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/config_specific/import_export/import_export.dart';
import '../../../../shared/globals.dart';
import '../../shared/heap/class_filter.dart';
import 'model.dart';

class ProfilePaneController extends DisposableController
    with AutoDisposeControllerMixin {
  ProfilePaneController();

  factory ProfilePaneController.fromJson(Map<String, dynamic> map) {
    // TODO(polina-c): implement, https://github.com/flutter/devtools/issues/6972
    return ProfilePaneController();
  }

  Map<String, dynamic> toJson() {
    // TODO(polina-c): implement, https://github.com/flutter/devtools/issues/6972
    return {};
  }

  final _exportController = ExportController();

  /// The current profile being displayed.
  ValueListenable<AdaptedProfile?> get currentAllocationProfile =>
      _currentAllocationProfile;
  final _currentAllocationProfile = ValueNotifier<AdaptedProfile?>(null);

  /// Specifies if the allocation profile should be refreshed when a GC event
  /// is received.
  ///
  /// TODO(polina-c): set refresher on by default after resolving issue
  /// with flickering
  /// https://github.com/flutter/devtools/issues/5176
  ValueListenable<bool> get refreshOnGc => _refreshOnGc;
  final _refreshOnGc = ValueNotifier<bool>(false);

  /// Current class filter.
  ValueListenable<ClassFilter> get classFilter => _classFilter;
  final _classFilter = ValueNotifier(ClassFilter.empty());

  late final _rootPackage =
      serviceConnection.serviceManager.rootInfoNow().package;

  bool _initialized = false;

  void initialize() {
    if (_initialized) {
      return;
    }

    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onGCEvent.listen((event) {
        if (refreshOnGc.value) {
          unawaited(refresh());
        }
      }),
    );
    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.selectedIsolate,
      () {
        unawaited(refresh());
      },
    );
    unawaited(refresh());
    _initialized = true;
  }

  void setFilter(ClassFilter filter) {
    if (filter == _classFilter.value) return;
    _classFilter.value = filter;
    final currentProfile = _currentAllocationProfile.value;
    if (currentProfile == null) return;
    _currentAllocationProfile.value = AdaptedProfile.withNewFilter(
      currentProfile,
      classFilter.value,
      _rootPackage,
    );
  }

  @visibleForTesting
  void clearCurrentProfile() => _currentAllocationProfile.value = null;

  /// Enable or disable refreshing the allocation profile when a GC event is
  /// received.
  void toggleRefreshOnGc() {
    _refreshOnGc.value = !_refreshOnGc.value;
  }

  final selection = ValueNotifier<ProfileRecord?>(null);

  /// Clear the current allocation profile and request an updated version from
  /// the VM service.
  Future<void> refresh() async {
    final service = serviceConnection.serviceManager.service;
    if (service == null) return;
    _currentAllocationProfile.value = null;

    final isolate =
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value;
    if (isolate == null) return;

    final allocationProfile = await service.getAllocationProfile(isolate.id!);
    _currentAllocationProfile.value = AdaptedProfile.fromAllocationProfile(
      allocationProfile,
      classFilter.value,
      _rootPackage,
    );
    _initializeSelection();
  }

  void _initializeSelection() {
    final records = _currentAllocationProfile.value?.records;
    if (records == null) return;
    records.sort((a, b) => b.totalSize.compareTo(a.totalSize));
    var recordToSelect = records.elementAtOrNull(0);
    if (recordToSelect?.isTotal ?? false) {
      recordToSelect = records.elementAtOrNull(1);
    }
    selection.value = recordToSelect;
  }

  /// Converts the current [AllocationProfile] to CSV format and downloads it.
  ///
  /// The returned string is the name of the downloaded CSV file.
  void downloadMemoryTableCsv(AdaptedProfile profile) {
    final csvBuffer = StringBuffer();

    // Write the headers first.
    csvBuffer.writeln(
      [
        'Class',
        'Library',
        'Total Instances',
        'Total Size',
        'Total Dart Heap Size',
        'Total External Size',
        'New Space Instances',
        'New Space Size',
        'New Space Dart Heap Size',
        'New Space External Size',
        'Old Space Instances',
        'Old Space Size',
        'Old Space Dart Heap Size',
        'Old Space External Size',
      ].map((e) => '"$e"').join(','),
    );
    // Write a row for each entry in the profile.
    for (final member in profile.records) {
      if (member.isTotal) continue;

      csvBuffer.writeln(
        [
          member.heapClass.className,
          member.heapClass.library,
          member.totalInstances,
          member.totalSize,
          member.totalDartHeapSize,
          member.totalExternalSize,
          member.newSpaceInstances,
          member.newSpaceSize,
          member.newSpaceDartHeapSize,
          member.newSpaceExternalSize,
          member.oldSpaceInstances,
          member.oldSpaceSize,
          member.oldSpaceDartHeapSize,
          member.oldSpaceExternalSize,
        ].join(','),
      );
    }
    _exportController.downloadFile(
      csvBuffer.toString(),
      type: ExportFileType.csv,
    );
  }
}
