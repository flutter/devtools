// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../constants.dart';

/// Analytics time constants specific for memory screen.
class MemoryTime {
  static const calculateDiff = 'calculateDiff';
  static const updateValues = 'updateValues';
}

// ignore: avoid_classes_with_only_static_members, requires refactor.
/// Analytic event constants specific for memory screen.
class MemoryEvent {
  static const gc = 'gc';
  static const settings = 'settings';

  static const showChartLegend = 'showMemoryLegend';
  static const hideChartLegend = 'hideMemoryLegend';
  static const chartAndroid = 'androidChart';

  static const pauseChart = 'pauseChart';
  static const resumeChart = 'resumeChart';
  static const clearChart = 'clearChart';
  static const showChart = 'showChart';
  static const hideChart = 'hideChart';
  static const chartInterval = 'chartInterval';
  static const chartHelp = 'memoryChartHelp';

  static const profileDownloadCsv = 'profileDownloadCsv';
  static const profileRefreshManual = 'profileRefreshManual';
  static const profileRefreshOnGc = 'profileRefreshOnGc';
  static const profileHelp = 'memoryProfileHelp';

  static const tracingClear = 'tracingClear';
  static const tracingRefresh = 'tracingRefresh';
  static const tracingClassFilter = 'tracingClassFilter';
  static const tracingTraceCheck = 'tracingTraceCheck';
  static const tracingTreeExpandAll = 'tracingTreeExpandAll';
  static const tracingTreeCollapseAll = 'tracingTreeCollapseAll';
  static const tracingHelp = 'memoryTracingHelp';

  static const diffTakeSnapshotControlPane = 'diffTakeSnapshotControlPane';
  static const diffClearSnapshots = 'diffClearSnapshots';
  static const diffHelp = 'memoryDiffHelp';

  static const diffSnapshotDiffSelect = 'diffSnapshotDiffSelect';
  static const diffSnapshotDiffOff = 'diffSnapshotDiffSelectOff';
  static const diffSnapshotFilter = 'diffSnapshotFilter';
  static const diffSnapshotDownloadCsv = 'diffSnapshotDownloadCsv';
  static const diffSnapshotExport = 'diffSnapshotExport';
  static const diffSnapshotDelete = 'diffSnapshotDelete';

  static const diffClassDiffSelect = 'diffClassDiffSelect';
  static const diffClassSingleSelect = 'diffClassSingleSelect';
  static const diffPathSelect = 'diffPathSelect';
  static const diffClassDiffCopy = 'diffClassDiffCopy';
  static const diffClassSingleCopy = 'diffClassSingleCopy';
  static const diffPathCopy = 'diffPathCopy';
  static const diffPathFilter = 'diffPathFilter';
  static const diffPathInvert = 'diffPathInvert';

  static const diffSnapshotFilterType = 'diffSnapshotFilterType';
  static const diffSnapshotFilterReset = 'diffSnapshotFilterReset';

  static const browseRefLimit = 'browseRefLimit';

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
