// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';

import '../../panes/chart/controller/chart_data.dart';
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
    return OfflineMemoryData(
      deserialize<DiffPaneController>(
        json[_Json.diffData],
        DiffPaneController.fromJson,
      ),
      deserialize<ProfilePaneController>(
        json[_Json.profileData],
        ProfilePaneController.fromJson,
      ),
      deserialize<ChartData>(json[_Json.chartData], ChartData.fromJson),
      deserialize<ClassFilter>(json[_Json.classFilter], ClassFilter.fromJson),
      selectedTab: json[_Json.selectedTab] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      _Json.selectedTab: selectedTab,
      _Json.diffData: diff,
      _Json.profileData: profile,
      _Json.chartData: chart,
      _Json.classFilter: filter,
    };
  }

  final int selectedTab;
  final ClassFilter filter; // filter is shared between tabs, so it's here

  final DiffPaneController diff;
  final ProfilePaneController? profile;
  final ChartData? chart;
}
