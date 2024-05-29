// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/feature_flags.dart';
import '../../shared/globals.dart';
import '../../shared/ui/tab.dart';
import '../../shared/utils.dart';
import 'panes/flutter_frames/flutter_frame_model.dart';
import 'panes/flutter_frames/flutter_frames_controller.dart';
import 'panes/frame_analysis/frame_analysis.dart';
import 'panes/raster_stats/raster_stats.dart';
import 'panes/rebuild_stats/rebuild_stats.dart';
import 'panes/timeline_events/timeline_events_view.dart';
import 'performance_controller.dart';

class TabbedPerformanceView extends StatefulWidget {
  const TabbedPerformanceView({super.key});

  @override
  State<TabbedPerformanceView> createState() => _TabbedPerformanceViewState();
}

class _TabbedPerformanceViewState extends State<TabbedPerformanceView>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<PerformanceController, TabbedPerformanceView> {
  static const _gaPrefix = 'performanceTab';

  late FlutterFramesController _flutterFramesController;

  FlutterFrame? _selectedFlutterFrame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    _flutterFramesController = controller.flutterFramesController;

    cancelListeners();

    _selectedFlutterFrame = _flutterFramesController.selectedFrame.value;
    addAutoDisposeListener(_flutterFramesController.selectedFrame, () {
      setState(() {
        _selectedFlutterFrame = _flutterFramesController.selectedFrame.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = offlineDataController.showingOfflineData.value;
    final isFlutterApp =
        serviceConnection.serviceManager.connectedApp!.isFlutterAppNow!;

    var showFrameAnalysis = isFlutterApp;
    var showRasterStats = isFlutterApp;
    var showRebuildStats = FeatureFlags.widgetRebuildStats && isFlutterApp;
    final offlineData = controller.offlinePerformanceData;
    if (isOffline) {
      final hasOfflineData = offlineData != null;
      showFrameAnalysis =
          showFrameAnalysis && hasOfflineData && offlineData.frames.isNotEmpty;
      showRasterStats =
          showRasterStats && hasOfflineData && offlineData.rasterStats != null;
      showRebuildStats = showRebuildStats &&
          hasOfflineData &&
          offlineData.rebuildCountModel != null;
    }

    final tabsAndControllers = _generateTabs(
      showFrameAnalysis: showFrameAnalysis,
      showRasterStats: showRasterStats,
      showRebuildStats: showRebuildStats,
    );
    final tabs = tabsAndControllers
        .map((t) => (tab: t.tab, tabView: t.tabView))
        .toList();
    final featureControllers =
        tabsAndControllers.map((t) => t.featureController).toList();

    // If there is not an active feature, activate the first.
    if (featureControllers.firstWhereOrNull(
          (controller) => controller?.isActiveFeature ?? false,
        ) ==
        null) {
      _setActiveFeature(0, featureControllers[0]);
    }

    return AnalyticsTabbedView(
      tabs: tabs,
      initialSelectedIndex: controller.selectedFeatureTabIndex,
      gaScreen: gac.performance,
      onTabChanged: (int index) {
        _setActiveFeature(index, featureControllers[index]);
      },
    );
  }

  void _setActiveFeature(
    int index,
    PerformanceFeatureController? featureController,
  ) {
    controller.selectedFeatureTabIndex = index;
    unawaited(controller.setActiveFeature(featureController));
  }

  List<
      ({
        DevToolsTab tab,
        Widget tabView,
        PerformanceFeatureController? featureController,
      })> _generateTabs({
    required bool showFrameAnalysis,
    required bool showRasterStats,
    required bool showRebuildStats,
  }) {
    if (showFrameAnalysis || showRasterStats || showRebuildStats) {
      assert(serviceConnection.serviceManager.connectedApp!.isFlutterAppNow!);
    }
    return [
      if (showFrameAnalysis)
        (
          tab: _buildTab(tabName: 'Frame Analysis'),
          tabView: KeepAliveWrapper(
            child: _selectedFlutterFrame != null
                ? FlutterFrameAnalysisView(
                    frame: _selectedFlutterFrame!,
                    enhanceTracingController:
                        controller.enhanceTracingController,
                    rebuildCountModel: controller.rebuildCountModel,
                    displayRefreshRateNotifier:
                        controller.flutterFramesController.displayRefreshRate,
                  )
                : const CenteredMessage(
                    'Select a frame above to view analysis data.',
                  ),
          ),
          featureController: null,
        ),
      if (showRebuildStats)
        (
          tab: _buildTab(tabName: 'Rebuild Stats'),
          tabView: KeepAliveWrapper(
            child: RebuildStatsView(
              model: controller.rebuildCountModel,
              selectedFrame: controller.flutterFramesController.selectedFrame,
            ),
          ),
          featureController: controller.rebuildStatsController,
        ),
      if (showRasterStats)
        (
          tab: _buildTab(tabName: 'Raster Stats'),
          tabView: KeepAliveWrapper(
            child: Center(
              child: RasterStatsView(
                rasterStatsController: controller.rasterStatsController,
                impellerEnabled: controller.impellerEnabled,
              ),
            ),
          ),
          featureController: controller.rasterStatsController,
        ),
      (
        tab: _buildTab(
          tabName: 'Timeline Events',
          trailing: TimelineEventsTabControls(
            controller: controller.timelineEventsController,
          ),
        ),
        tabView: TimelineEventsTabView(
          controller: controller.timelineEventsController,
        ),
        featureController: controller.timelineEventsController,
      ),
    ];
  }

  DevToolsTab _buildTab({required String tabName, Widget? trailing}) {
    return DevToolsTab.create(
      tabName: tabName,
      gaPrefix: _gaPrefix,
      trailing: trailing,
    );
  }
}
