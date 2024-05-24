// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:meta/meta.dart';

import '../../panes/chart/controller/chart_data.dart';
import '../../panes/diff/controller/diff_pane_controller.dart';
import '../../panes/profile/profile_pane_controller.dart';
import '../../panes/tracing/tracing_pane_controller.dart';
import '../../shared/heap/class_filter.dart';

@visibleForTesting
enum Json {
  selectedTab,
  classFilter,
  diffData,
  profileData,
  chartData,
  trace;
}

class OfflineMemoryData with Serializable {
  OfflineMemoryData(
    this.diff,
    this.profile,
    this.chart,
    this.trace,
    this.filter, {
    required this.selectedTab,
  });

  factory OfflineMemoryData.fromJson(Map<String, dynamic> json) {
    return OfflineMemoryData(
      deserialize<DiffPaneController>(
        json[Json.diffData.name],
        DiffPaneController.fromJson,
      ),
      deserializeNullable<ProfilePaneController>(
        json[Json.profileData.name],
        ProfilePaneController.fromJson,
      ),
      deserializeNullable<ChartData>(
        json[Json.chartData.name],
        ChartData.fromJson,
      ),
      deserializeNullable<TracePaneController>(
        json[Json.trace.name],
        TracePaneController.fromJson,
      ),
      deserialize<ClassFilter>(
        json[Json.classFilter.name],
        ClassFilter.fromJson,
      ),
      selectedTab: json[Json.selectedTab.name] as int? ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      Json.selectedTab.name: selectedTab,
      Json.diffData.name: diff,
      Json.profileData.name: profile,
      Json.chartData.name: chart,
      Json.classFilter.name: filter,
      Json.trace.name: trace,
    };
  }

  final int selectedTab;
  final ClassFilter filter; // filter is shared between tabs, so it's here

  final DiffPaneController diff;
  final ProfilePaneController? profile;
  final ChartData? chart;
  final TracePaneController? trace;
}
