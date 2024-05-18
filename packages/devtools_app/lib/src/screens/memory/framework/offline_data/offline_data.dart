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
class Json {
  static const selectedTab = 'selectedTab';
  static const classFilter = 'classFilter';
  static const diffData = 'diffData';
  static const profileData = 'profileData';
  static const chartData = 'chartData';

  static const all = {
    selectedTab,
    classFilter,
    diffData,
    profileData,
    chartData,
  };
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
      Json.selectedTab: selectedTab,
      Json.diffData: diff,
      Json.profileData: profile,
      Json.chartData: chart,
      Json.classFilter: filter,
    };
  }

  final int selectedTab;
  final ClassFilter filter; // filter is shared between tabs, so it's here

  final DiffPaneController diff;
  final ProfilePaneController profile;
  final ChartData chart;
}
