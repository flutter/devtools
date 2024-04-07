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
    this.isEmpty = false,
    required this.selectedTab,
  });

  factory OfflineMemoryData.parse(Map<String, dynamic> json) {
    Map<String, dynamic> item(String key) =>
        json[key] as Map<String, dynamic>? ?? {};
    return OfflineMemoryData(
      DiffPaneController.parse(item(_Json.diffData)),
      ProfilePaneController.parse(item(_Json.profileData)),
      MemoryChartPaneController.parse(item(_Json.chartData)),
      ClassFilter.parse(item(_Json.classFilter)),
      selectedTab: json[_Json.selectedTab] as int? ?? 0,
      isEmpty: json.isEmpty,
    );
  }

  final bool isEmpty;

  final int selectedTab;
  final ClassFilter filter; // filter is shared between tabs, so it's here

  final DiffPaneController diff;
  final ProfilePaneController profile;
  final MemoryChartPaneController chart;

  Map<String, dynamic> prepareForOffline() {
    return {
      _Json.selectedTab: selectedTab,
      _Json.diffData: diff.prepareForOffline(),
      _Json.profileData: profile.prepareForOffline(),
      _Json.chartData: chart.prepareForOffline(),
      _Json.classFilter: profile.classFilter.value.prepareForOffline(),
    };
  }
}
