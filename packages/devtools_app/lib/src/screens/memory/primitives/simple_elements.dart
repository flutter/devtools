// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

const String shallowSizeColumnTooltip =
    'The total shallow size of all of the instances.\n'
    'The shallow size of an object is the size of the object\n'
    'plus the references it holds to other Dart objects\n'
    "in its fields (this doesn't include the size of\n"
    'the fields - just the size of the references).';

const String retainedSizeColumnTooltip =
    'Total shallow Dart size of objects plus shallow Dart size of objects they retain,\n'
    'taking into account only the shortest retaining path for the referenced objects.';

const String nonGcableInstancesColumnTooltip =
    'Number of instances of the class,\n'
    'that are reachable, i.e. have a retaining path from the root\n'
    'and therefore can’t be garbage collected.';

/// Analytic time constants specific for memory screen.
class MemoryTimeAnalytics {
  static const adaptSnapshot = 'adaptSnapshot';
  static const updateValues = 'updateValues';
}

/// Analytic event constants specific for memory screen.
class MemoryEventAnalytics {
  static const gc = 'gc';
  static const settings = 'settings';

  static const chartExpand = 'chartExpand';
  static const chartCollapse = 'chartCollapse';

  static const profileDownloadCsv = 'profileDownloadCsv';
  static const profileRefreshManual = 'profileRefreshManual';
  static const profileRefreshOnGc = 'profileRefreshOnGc';

  static const allocationClear = 'allocationClear';
  static const allocationRefresh = 'allocationRefresh';
  static const allocationFilter = 'allocationFilter';
  static const allocationTrace = 'allocationTrace';
  static const allocationHelp = 'allocationHelp';

  static const diffTakeSnapshot = 'diffTakeSnapshot';
  static const diffClearSnapshots = 'diffClearSnapshots';

  static const diffSnapshotDiff = 'diffSnapshotDiff';
  static const diffSnapshotFilter = 'diffSnapshotFilter';
  static const diffSnapshotDownloadCsv = 'diffSnapshotDownloadCsv';
  static const diffSnapshotDelete = 'diffSnapshotDelete';

  static const diffClassSelect = 'diffClassSelect';
  static const diffPathSelect = 'diffPathSelect';
  static const diffPathCopy = 'diffPathCopy';
  static const diffPathFilter = 'diffPathFilter';
  static const diffPathUnfilter = 'diffPathUnfilter';
  static const diffPathRevert = 'diffPathRevert';
  static const diffPathUnrevert = 'diffPathUnrevert';

  static const diffSnapshotFilterAll = 'diffSnapshotFilterAll';
  static const diffSnapshotFilterExcept = 'diffSnapshotFilterExcept';
  static const diffSnapshotFilterOnly = 'diffSnapshotFilterOnly';
  static const diffSnapshotFilterReset = 'diffSnapshotFilterReset';
}
