// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/memory/class_name.dart';
import '../../../../shared/memory/gc_stats.dart';
import '../../../../shared/table/table_data.dart';
import '../../../vm_developer/vm_service_private_extensions.dart';
import '../../shared/heap/class_filter.dart';

class _ProfileJson {
  static const total = 'total';
  static const items = 'items';
  static const newGC = 'newGC';
  static const oldGC = 'oldGC';
  static const totalGC = 'totalGC';
}

class AdaptedProfile with Serializable {
  AdaptedProfile._({
    required ProfileRecord total,
    required List<ProfileRecord> items,
    required this.newSpaceGCStats,
    required this.oldSpaceGCStats,
    required this.totalGCStats,
  })  : filter = ClassFilter.empty(),
        _total = total,
        _items = items,
        _itemsFiltered = items;

  factory AdaptedProfile.fromAllocationProfile(
    AllocationProfile profile,
    ClassFilter filter,
    String? rootPackage,
  ) {
    final adaptedProfile = AdaptedProfile._(
      total: ProfileRecord.total(profile),
      items: (profile.members ?? [])
          .where((e) => (e.instancesCurrent ?? 0) > 0)
          .map((e) => ProfileRecord.fromClassHeapStats(e))
          .toList(),
      newSpaceGCStats: profile.newSpaceGCStats,
      oldSpaceGCStats: profile.oldSpaceGCStats,
      totalGCStats: profile.totalGCStats,
    );

    return AdaptedProfile.withNewFilter(adaptedProfile, filter, rootPackage);
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
  }

  factory AdaptedProfile.fromJson(Map<String, dynamic> json) {
    return AdaptedProfile._(
      total: ProfileRecord.fromJson(json[_ProfileJson.total]),
      items: (json[_ProfileJson.items] as List)
          .map((e) => ProfileRecord.fromJson(e))
          .toList(),
      newSpaceGCStats: GCStats.fromJson(json[_ProfileJson.newGC]),
      oldSpaceGCStats: GCStats.fromJson(json[_ProfileJson.oldGC]),
      totalGCStats: GCStats.fromJson(json[_ProfileJson.totalGC]),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      _ProfileJson.total: _total,
      _ProfileJson.items: _items,
      _ProfileJson.newGC: newSpaceGCStats,
      _ProfileJson.oldGC: oldSpaceGCStats,
      _ProfileJson.totalGC: totalGCStats,
    };
  }

  /// A record per class plus one total record, with applied filter.
  late final List<ProfileRecord> records = [
    _total,
    ..._itemsFiltered,
  ];

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

/// Constants are short here, as they repeat and we want to save space.
class _RecordJson {
  static const isTotal = 'it';
  static const heapClass = 'c';
  static const totalInstances = 'ti';
  static const totalSize = 'ts';
  static const totalDartHeapSize = 'tds';
  static const totalExternalSize = 'tes';
  static const newSpaceInstances = 'ni';
  static const newSpaceSize = 'ns';
  static const newSpaceDartHeapSize = 'nds';
  static const newSpaceExternalSize = 'nes';
  static const oldSpaceInstances = 'oi';
  static const oldSpaceSize = 'os';
  static const oldSpaceDartHeapSize = 'ods';
  static const oldSpaceExternalSize = 'oes';
}

class ProfileRecord with PinnableListEntry, Serializable {
  ProfileRecord._({
    required this.isTotal,
    required this.heapClass,
    required this.totalInstances,
    required this.totalSize,
    required this.totalDartHeapSize,
    required this.totalExternalSize,
    required this.newSpaceInstances,
    required this.newSpaceSize,
    required this.newSpaceDartHeapSize,
    required this.newSpaceExternalSize,
    required this.oldSpaceInstances,
    required this.oldSpaceSize,
    required this.oldSpaceDartHeapSize,
    required this.oldSpaceExternalSize,
  }) {
    _verifyIntegrity();
  }

  factory ProfileRecord.fromClassHeapStats(ClassHeapStats stats) {
    assert(
      stats.bytesCurrent! == stats.newSpace.size + stats.oldSpace.size,
      '${stats.bytesCurrent}, ${stats.newSpace.size}, ${stats.oldSpace.size}',
    );
    return ProfileRecord._(
      isTotal: false,
      heapClass: HeapClassName.fromClassRef(stats.classRef),
      totalInstances: stats.instancesCurrent ?? 0,
      totalSize: stats.bytesCurrent! +
          stats.oldSpace.externalSize +
          stats.newSpace.externalSize,
      totalDartHeapSize: stats.bytesCurrent!,
      totalExternalSize:
          stats.oldSpace.externalSize + stats.newSpace.externalSize,
      newSpaceInstances: stats.newSpace.count,
      newSpaceSize: stats.newSpace.size + stats.newSpace.externalSize,
      newSpaceDartHeapSize: stats.newSpace.size,
      newSpaceExternalSize: stats.newSpace.externalSize,
      oldSpaceInstances: stats.oldSpace.count,
      oldSpaceSize: stats.oldSpace.size + stats.oldSpace.externalSize,
      oldSpaceDartHeapSize: stats.oldSpace.size,
      oldSpaceExternalSize: stats.oldSpace.externalSize,
    );
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

  factory ProfileRecord.fromJson(Map<String, dynamic> json) {
    return ProfileRecord._(
      isTotal: json[_RecordJson.isTotal] as bool,
      heapClass: HeapClassName.fromJson(json[_RecordJson.heapClass]),
      totalInstances: json[_RecordJson.totalInstances] as int?,
      totalSize: json[_RecordJson.totalSize] as int,
      totalDartHeapSize: json[_RecordJson.totalDartHeapSize] as int,
      totalExternalSize: json[_RecordJson.totalExternalSize] as int,
      newSpaceInstances: json[_RecordJson.newSpaceInstances] as int?,
      newSpaceSize: json[_RecordJson.newSpaceSize] as int?,
      newSpaceDartHeapSize: json[_RecordJson.newSpaceDartHeapSize] as int?,
      newSpaceExternalSize: json[_RecordJson.newSpaceExternalSize] as int?,
      oldSpaceInstances: json[_RecordJson.oldSpaceInstances] as int?,
      oldSpaceSize: json[_RecordJson.oldSpaceSize] as int?,
      oldSpaceDartHeapSize: json[_RecordJson.oldSpaceDartHeapSize] as int?,
      oldSpaceExternalSize: json[_RecordJson.oldSpaceExternalSize] as int?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      _RecordJson.isTotal: isTotal,
      _RecordJson.heapClass: heapClass,
      _RecordJson.totalInstances: totalInstances,
      _RecordJson.totalSize: totalSize,
      _RecordJson.totalDartHeapSize: totalDartHeapSize,
      _RecordJson.totalExternalSize: totalExternalSize,
      _RecordJson.newSpaceInstances: newSpaceInstances,
      _RecordJson.newSpaceSize: newSpaceSize,
      _RecordJson.newSpaceDartHeapSize: newSpaceDartHeapSize,
      _RecordJson.newSpaceExternalSize: newSpaceExternalSize,
      _RecordJson.oldSpaceInstances: oldSpaceInstances,
      _RecordJson.oldSpaceSize: oldSpaceSize,
      _RecordJson.oldSpaceDartHeapSize: oldSpaceDartHeapSize,
      _RecordJson.oldSpaceExternalSize: oldSpaceExternalSize,
    };
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
