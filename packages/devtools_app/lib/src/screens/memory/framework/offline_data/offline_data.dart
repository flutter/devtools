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

class OfflineMemoryData {
  OfflineMemoryData(
    this.diff,
    this.profile,
    this.chart,
    this.filter, {
    required this.selectedTab,
  });

  factory OfflineMemoryData.fromJson(Map<String, dynamic> json) {
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

  final int selectedTab;
  final ClassFilter filter; // filter is shared between tabs, so it's here

  final DiffPaneController diff;
  final ProfilePaneController profile;
  final MemoryChartPaneController chart;

  Map<String, dynamic> toJson() {
    return {
      _Json.selectedTab: selectedTab,
      _Json.diffData: diff.toJson(),
      _Json.profileData: profile.toJson(),
      _Json.chartData: chart.toJson(),
      _Json.classFilter: profile.classFilter.value.toJson(),
    };
  }
}
