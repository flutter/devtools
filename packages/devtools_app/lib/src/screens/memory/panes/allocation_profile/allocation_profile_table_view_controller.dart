// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../config_specific/import_export/import_export.dart';
import '../../../../primitives/auto_dispose.dart';
import '../../../../shared/globals.dart';
import 'model.dart';

class AllocationProfileTableViewController extends DisposableController
    with AutoDisposeControllerMixin {
  final _exportController = ExportController();

  /// The current profile being displayed.
  ValueListenable<AdaptedAllocationProfile?> get currentAllocationProfile =>
      _currentAllocationProfile;
  final _currentAllocationProfile =
      ValueNotifier<AdaptedAllocationProfile?>(null);

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
          refresh();
        }
      }),
    );
    addAutoDisposeListener(serviceManager.isolateManager.selectedIsolate, () {
      refresh();
    });
    refresh();
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
    _currentAllocationProfile.value = null;
    final service = serviceManager.service!;
    final isolate = serviceManager.isolateManager.selectedIsolate.value;
    final allocationProfile = await service.getAllocationProfile(isolate!.id!);
    _currentAllocationProfile.value =
        AdaptedAllocationProfile.fromAllocationProfile(allocationProfile);
  }

  /// Converts the current [AllocationProfile] to CSV format and downloads it.
  ///
  /// The returned string is the name of the downloaded CSV file.
  void downloadMemoryTableCsv(AdaptedAllocationProfile profile) {
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
    _exportController.downloadAndNotify(
      csvBuffer.toString(),
      type: ExportFileType.csv,
    );
  }
}
