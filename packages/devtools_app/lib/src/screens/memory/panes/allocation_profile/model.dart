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
      AllocationProfileRecord.total(profile),
      ...elements,
    ];
  }

  /// A record per class plus one total record.
  late final List<AllocationProfileRecord> records;
}

class AllocationProfileRecord {
  AllocationProfileRecord.fromClassHeapStats(ClassHeapStats stats)
      : isTotal = false,
        heapClass = HeapClass.fromClassRef(stats.classRef),
        totalInstances = stats.instancesCurrent ?? 0,
        totalSize = stats.bytesCurrent! +
            stats.oldSpace.externalSize +
            stats.newSpace.externalSize,
        totalDartHeapSize = stats.bytesCurrent!,
        totalExternalSize =
            stats.oldSpace.externalSize + stats.newSpace.externalSize,
        newSpaceInstances = stats.newSpace.count,
        newSpaceSize = stats.newSpace.size + stats.newSpace.externalSize,
        newSpaceDartHeapSize = stats.newSpace.size,
        newSpaceExternalSize = stats.newSpace.externalSize,
        oldSpaceInstances = stats.oldSpace.count,
        oldSpaceSize = stats.oldSpace.size + stats.oldSpace.externalSize,
        oldSpaceDartHeapSize = stats.oldSpace.size,
        oldSpaceExternalSize = stats.oldSpace.externalSize {
    _verifyIntegrity();
  }

  AllocationProfileRecord.total(AllocationProfile profile)
      : isTotal = true,
        heapClass = const HeapClass(className: 'All Classes', library: ''),
        totalInstances = null,
        totalSize = profile.memoryUsage?.externalUsage ??
            0 + (profile.memoryUsage?.heapUsage ?? 0),
        totalDartHeapSize = profile.memoryUsage?.heapUsage ?? 0,
        totalExternalSize = profile.memoryUsage?.externalUsage ?? 0,
        newSpaceInstances = null,
        newSpaceSize = null,
        newSpaceDartHeapSize = null,
        newSpaceExternalSize = null,
        oldSpaceInstances = null,
        oldSpaceSize = null,
        oldSpaceDartHeapSize = null,
        oldSpaceExternalSize = null {
    _verifyIntegrity();
  }

  final bool isTotal;

  final HeapClass heapClass;

  final int? totalInstances;
  final int totalSize;
  final int totalDartHeapSize;
  final int totalExternalSize;

  final int? newSpaceInstances;
  final int? newSpaceSize;
  final int? newSpaceDartHeapSize;
  final int? newSpaceExternalSize;

  final int? oldSpaceInstances;
  final int? oldSpaceSize;
  final int? oldSpaceDartHeapSize;
  final int? oldSpaceExternalSize;

  void _verifyIntegrity() {
    assert(() {
      assert(totalSize == totalDartHeapSize + totalExternalSize);
      if (!isTotal) {
        assert(totalSize == newSpaceSize! + oldSpaceSize!);
        assert(totalInstances == newSpaceInstances! + oldSpaceInstances!);
        assert(newSpaceSize == newSpaceDartHeapSize! + newSpaceExternalSize!);
        assert(oldSpaceSize == oldSpaceDartHeapSize! + oldSpaceExternalSize!);
      }
      return true;
    }());
  }
}
