// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../../../shared/memory/class_name.dart';
import '../../../../shared/memory/gc_stats.dart';
import '../../../../shared/table/table_data.dart';
import '../../../vm_developer/vm_service_private_extensions.dart';
import '../../shared/heap/class_filter.dart';

class AdaptedProfile {
  AdaptedProfile.fromAllocationProfile(
    AllocationProfile profile,
    this.filter,
    String? rootPackage,
  )   : newSpaceGCStats = profile.newSpaceGCStats,
        oldSpaceGCStats = profile.oldSpaceGCStats,
        totalGCStats = profile.totalGCStats {
    _items = (profile.members ?? [])
        .where((element) {
          return element.bytesCurrent != 0 ||
              element.newSpace.externalSize != 0 ||
              element.oldSpace.externalSize != 0;
        })
        .map((e) => ProfileRecord.fromClassHeapStats(e))
        .toList();

    _itemsFiltered = _items
        .where((element) => filter.apply(element.heapClass, rootPackage))
        .toList();

    _total = ProfileRecord.total(profile);

    records = [
      _total,
      ..._itemsFiltered,
    ];
  }

  AdaptedProfile.withNewFilter(
    AdaptedProfile profile,
    this.filter,
    String? rootPackage,
  )   : newSpaceGCStats = profile.newSpaceGCStats,
        oldSpaceGCStats = profile.oldSpaceGCStats,
        totalGCStats = profile.totalGCStats {
    _items = profile._items;
    _total = profile._total;

    _itemsFiltered = ClassFilter.filter(
      oldFilter: profile.filter,
      oldFiltered: profile._itemsFiltered,
      newFilter: filter,
      original: profile._items,
      extractClass: (s) => s.heapClass,
      rootPackage: rootPackage,
    );

    records = [
      _total,
      ..._itemsFiltered,
    ];
  }

  /// A record per class plus one total record, with applied filter.
  late final List<ProfileRecord> records;

  /// Record for totals.
  late final ProfileRecord _total;

  /// A record per class.
  late final List<ProfileRecord> _items;

  /// A record per class, filtered.
  late final List<ProfileRecord> _itemsFiltered;

  /// Applied filter.
  final ClassFilter filter;

  final GCStats newSpaceGCStats;
  final GCStats oldSpaceGCStats;
  final GCStats totalGCStats;
}

class ProfileRecord with PinnableListEntry {
  ProfileRecord.fromClassHeapStats(ClassHeapStats stats)
      : assert(
          stats.bytesCurrent! == stats.newSpace.size + stats.oldSpace.size,
          '${stats.bytesCurrent}, ${stats.newSpace.size}, ${stats.oldSpace.size}',
        ),
        isTotal = false,
        heapClass = HeapClassName.fromClassRef(stats.classRef),
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

  ProfileRecord.total(AllocationProfile profile)
      : isTotal = true,
        heapClass =
            HeapClassName.fromPath(className: 'All Classes', library: ''),
        totalInstances = null,
        totalSize = (profile.memoryUsage?.externalUsage ?? 0) +
            (profile.memoryUsage?.heapUsage ?? 0),
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

  final HeapClassName heapClass;

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

  @override
  bool get pinToTop => isTotal;

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
