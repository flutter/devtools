// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/config_specific/import_export/import_export.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/auto_dispose.dart';
import 'model.dart';

class ProfilePaneController extends DisposableController
    with AutoDisposeControllerMixin {
  final _exportController = ExportController();

  /// The current profile being displayed.
  ValueListenable<AdaptedProfile?> get currentAllocationProfile =>
      _currentAllocationProfile;
  final _currentAllocationProfile = ValueNotifier<AdaptedProfile?>(null);

  /// Specifies if the allocation profile should be refreshed when a GC event
  /// is received.
  ValueListenable<bool> get refreshOnGc => _refreshOnGc;
  final _refreshOnGc = ValueNotifier<bool>(true);

  bool _initialized = false;

  void initialize() {
    if (_initialized) {
      return;
    }
    autoDisposeStreamSubscription(
      serviceManager.service!.onGCEvent.listen((event) {
        if (refreshOnGc.value) {
          unawaited(refresh());
        }
      }),
    );
    addAutoDisposeListener(serviceManager.isolateManager.selectedIsolate, () {
      unawaited(refresh());
    });
    unawaited(refresh());
    _initialized = true;
  }

  @visibleForTesting
  void clearCurrentProfile() => _currentAllocationProfile.value = null;

  /// Enable or disable refreshing the allocation profile when a GC event is
  /// received.
  void toggleRefreshOnGc() {
    _refreshOnGc.value = !_refreshOnGc.value;
  }

  /// Clear the current allocation profile and request an updated version from
  /// the VM service.
  Future<void> refresh() async {
    final service = serviceManager.service;
    if (service == null) return;
    _currentAllocationProfile.value = null;

    final isolate = serviceManager.isolateManager.selectedIsolate.value;
    if (isolate == null) return;

    final allocationProfile = await service.getAllocationProfile(isolate.id!);
    _currentAllocationProfile.value =
        AdaptedProfile.fromAllocationProfile(allocationProfile);
  }

  /// Converts the current [AllocationProfile] to CSV format and downloads it.
  ///
  /// The returned string is the name of the downloaded CSV file.
  void downloadMemoryTableCsv(AdaptedProfile profile) {
    ga.select(
      gac.memory,
      gac.MemoryEvent.profileDownloadCsv,
    );
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
