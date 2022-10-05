// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../../vm_developer/vm_service_private_extensions.dart';
import '../../shared/heap/model.dart';

class AdaptedAllocationProfile {
  AdaptedAllocationProfile.fromAllocationProfile(AllocationProfile profile) {
    final elements = (profile.members ?? []).where((element) {
      return element.bytesCurrent != 0 ||
          element.newSpace.externalSize != 0 ||
          element.oldSpace.externalSize != 0;
    }).map((e) => AllocationProfileRecord.fromClassHeapStats(e));

    records = [
      AllocationProfileRecord.fromAllocationProfile(profile),
      ...elements,
    ];
  }

  /// A record per class plus one total record.
  late final List<AllocationProfileRecord> records;
}

class AllocationProfileRecord {
  AllocationProfileRecord.fromClassHeapStats(ClassHeapStats stats)
      : heapClass = HeapClass.fromClassRef(stats.classRef),
        instances = stats.instancesCurrent ?? 0,
        totalExternalSize =
            stats.newSpace.externalSize + stats.oldSpace.externalSize,
        newExternalSize = stats.newSpace.externalSize,
        oldExternalSize = stats.oldSpace.externalSize,
        totalDartSize = stats.newSpace.size + stats.oldSpace.size,
        newDartSize = stats.newSpace.size,
        oldDartSize = stats.oldSpace.size;

  AllocationProfileRecord.fromAllocationProfile(AllocationProfile profile)
      : heapClass = null,
        instances = null,
        totalExternalSize = profile.memoryUsage?.externalUsage ?? 0,
        newExternalSize = null,
        oldExternalSize = null,
        totalDartSize = profile.memoryUsage?.heapUsage ?? 0,
        newDartSize = null,
        oldDartSize = null;

  /// If null, the record represents total numbers for all classes.
  final HeapClass? heapClass;

  final int? instances;

  final int totalSize;
  final int totalDartSize;
  final int totalExternalSize;

  final int? newDartSize;
  final int? oldDartSize;
  final int totalDartSize;

  final int? newExternalSize;
  final int? oldExternalSize;
  final int totalExternalSize;
}


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