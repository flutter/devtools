// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:meta/meta.dart';

import '../../panes/chart/controller/chart_data.dart';
import '../../panes/diff/controller/diff_pane_controller.dart';
import '../../panes/profile/profile_pane_controller.dart';
import '../../shared/heap/class_filter.dart';

@visibleForTesting
enum Json {
  selectedTab,
  classFilter,
  diffData,
  profileData,
  chartData;
}

class OfflineMemoryData {
  OfflineMemoryData(
    this.diff,
    this.profile,
    this.chart,
    this.filter, {
    required this.selectedTab,
  });

  factory OfflineMemoryData.fromJson(Map<String, dynamic> json) {
    return OfflineMemoryData(
      deserialize<DiffPaneController>(
        json[Json.diffData],
        DiffPaneController.fromJson,
      ),
      deserialize<ProfilePaneController>(
        json[Json.profileData],
        ProfilePaneController.fromJson,
      ),
      deserialize<ChartData>(json[Json.chartData], ChartData.fromJson),
      deserialize<ClassFilter>(json[Json.classFilter], ClassFilter.fromJson),
      selectedTab: json[Json.selectedTab] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      Json.selectedTab.name: selectedTab,
      Json.diffData.name: diff,
      Json.profileData.name: profile,
      Json.chartData.name: chart,
      Json.classFilter.name: filter,
    };
  }

  final int selectedTab;
  final ClassFilter filter; // filter is shared between tabs, so it's here

  final DiffPaneController diff;
  final ProfilePaneController profile;
  final ChartData chart;
}
