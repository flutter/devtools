// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of '../constants.dart';

/// Analytics time constants specific for memory screen.
enum MemoryTime { calculateDiff, updateValues }

enum MemoryEvents {
  browseRefLimit,
  gc,
  settings,

  // Chart events
  androidChart,
  chartHelp,
  chartInterval,
  clearChart,
  pauseChart,
  resumeChart,
  showChart,
  hideChart,
  showChartLegend,
  hideChartLegend,

  // 'Diff' tab events
  diffTakeSnapshotControlPane,
  diffClearSnapshots,
  diffHelp,

  diffSnapshotDiffSelect,
  diffSnapshotDiffSelectOff,
  diffSnapshotFilter,
  diffSnapshotDownloadCsv,
  diffSnapshotExport,
  diffSnapshotDelete,

  diffClassDiffSelect,
  diffClassSingleSelect,
  diffPathSelect,
  diffClassDiffCopy,
  diffClassSingleCopy,
  diffPathCopy,
  diffPathFilter,
  diffPathInvert,

  diffSnapshotFilterType,
  diffSnapshotFilterReset,

  // 'Profile' tab events
  profileDownloadCsv,
  profileHelp,
  profileRefreshManual,
  profileRefreshOnGc,

  // 'Tracing' tab events
  tracingClear,
  tracingRefresh,
  tracingClassFilter,
  tracingTraceCheck,
  tracingTreeExpandAll,
  tracingTreeCollapseAll,
  tracingHelp;

  static String dropOneLiveVariable({required String sourceFeature}) =>
      'dropOneLiveVariable_$sourceFeature';

  static String dropOneStaticVariable({required String sourceFeature}) =>
      'dropOneStaticVariable_$sourceFeature';

  static String dropAllLiveToConsole({
    required bool includeSubclasses,
    required bool includeImplementers,
  }) =>
      'dropAllVariables${includeSubclasses ? '_Subclasses' : ''}${includeImplementers ? '_Imlementers' : ''}';
}

/// Areas of memory screen, to prefix event names, when events are emitted
/// by a widget used in different contexts.
enum MemoryAreas {
  profile('profile'),
  snapshotDiff('diff');

  const MemoryAreas(this.name);

  final String name;
}
