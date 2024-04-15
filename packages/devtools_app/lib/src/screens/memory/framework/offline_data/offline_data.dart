// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../panes/chart/controller/chart_pane_controller.dart';
import '../../panes/diff/controller/diff_pane_controller.dart';
import '../../panes/profile/profile_pane_controller.dart';
import '../../shared/heap/class_filter.dart';

class _Json {
  static const selectedTab = 'selectedTab';
  static const classFilter = 'classFilter';
  static const diffData = 'diffData';
  static const profileData = 'profileData';
  static const chartData = 'chartData';
}

extension type _OfflineMemoryDataJson(Map<String, Object?> json) {
  OfflineMemoryData parse() {
    Map<String, dynamic> item(String key) =>
        json[key] as Map<String, dynamic>? ?? {};
    return OfflineMemoryData(
      DiffPaneController.fromJson(item(_Json.diffData)),
      ProfilePaneController.fromJson(item(_Json.profileData)),
      MemoryChartPaneController.fromJson(item(_Json.chartData)),
      ClassFilter.fromJson(item(_Json.classFilter)),
      selectedTab: json[_Json.selectedTab] as int? ?? 0,
    );
  }

  static Map<String, Object?> toJson(OfflineMemoryData data) => {
        _Json.selectedTab: data.selectedTab,
        _Json.diffData: data.diff.toJson(),
        _Json.profileData: data.profile.toJson(),
        _Json.chartData: data.chart.toJson(),
        _Json.classFilter: data.profile.classFilter.value.toJson(),
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

  factory OfflineMemoryData.fromJson(Map<String, dynamic> json) =>
      _OfflineMemoryDataJson(json).parse();
  Map<String, dynamic> toJson() => _OfflineMemoryDataJson.toJson(this);

  final int selectedTab;
  final ClassFilter filter; // filter is shared between tabs, so it's here

  final DiffPaneController diff;
  final ProfilePaneController profile;
  final MemoryChartPaneController chart;
}
