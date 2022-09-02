// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../config_specific/import_export/import_export.dart';
import '../../../../primitives/auto_dispose.dart';
import '../../../../shared/globals.dart';
import '../../../vm_developer/vm_service_private_extensions.dart';

class AllocationProfileTableViewController extends DisposableController
    with AutoDisposeControllerMixin {
  final _exportController = ExportController();

  /// The current [AllocationProfile] being displayed.
  ValueListenable<AllocationProfile?> get currentAllocationProfile =>
      _currentAllocationProfile;
  final _currentAllocationProfile = ValueNotifier<AllocationProfile?>(null);

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
    _currentAllocationProfile.value = allocationProfile;
  }

  /// Converts the current [AllocationProfile] to CSV format and downloads it.
  ///
  /// The returned string is the name of the downloaded CSV file.
  String downloadMemoryTableCsv(AllocationProfile profile) {
    final csvBuffer = StringBuffer();

    // Write the headers first.
    csvBuffer.writeln(
      [
        'Class',
        'Total Instances',
        'Total Size',
        'Total Internal Size',
        'Total External Size',
        'New Space Instances',
        'New Space Size',
        'New Space Internal Size',
        'New Space External Size',
        'Old Space Instances',
        'Old Space Size',
        'Old Space Internal Size',
        'Old Space External Size',
      ].map((e) => '"$e"').join(','),
    );
    // Write a row for each entry in the profile.
    for (final member in profile.members!) {
      csvBuffer.writeln(
        [
          member.classRef!.name,
          member.instancesCurrent,
          member.bytesCurrent! +
              member.oldSpace.externalSize +
              member.newSpace.externalSize,
          member.bytesCurrent!,
          member.oldSpace.externalSize + member.newSpace.externalSize,
          member.newSpace.count,
          member.newSpace.size + member.newSpace.externalSize,
          member.newSpace.size,
          member.newSpace.externalSize,
          member.oldSpace.count,
          member.oldSpace.size + member.oldSpace.externalSize,
          member.oldSpace.size,
          member.oldSpace.externalSize,
        ].join(','),
      );
    }
    return _exportController.downloadFile(
      csvBuffer.toString(),
      type: ExportFileType.csv,
    );
  }
}
