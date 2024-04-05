// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../panes/chart/controller/chart_pane_controller.dart';
import '../../panes/diff/controller/diff_pane_controller.dart';
import '../../panes/profile/profile_pane_controller.dart';

class _Json {
  static const selectedTab = 'selectedTab';
  static const diffData = 'diffData';
  static const profileData = 'profileData';
  static const chartData = 'chartData';
}

class OfflineMemoryData {
  OfflineMemoryData(
    this.diff,
    this.profile,
    this.chart, {
    required this.selectedTab,
  });

  factory OfflineMemoryData.parse(Map<String, dynamic> json) {
    throw UnimplementedError();
    // return OfflineMemoryData(
    //   selectedTab: json[_Json.selectedTab] as int,
    //   diffData: json[_Json.diffData] as Map<String, dynamic>,
    //   profileData: json[_Json.profileData] as Map<String, dynamic>,
    //   chartData: json[_Json.chartData] as Map<String, dynamic>,
    // );
  }

  bool isEmpty = false;

  final DiffPaneController diff;
  final ProfilePaneController profile;
  final MemoryChartPaneController chart;
  final int selectedTab;

  Map<String, dynamic> toJson() {
    return {
      _Json.selectedTab: selectedTab,
      _Json.diffData: diff.prepareForOffline(),
      _Json.profileData: profile.prepareForOffline(),
      _Json.chartData: chart.prepareForOffline(),
    };
  }
}
