// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/feature_flags.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/auto_dispose.dart';
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
    final isOffline = offlineController.offlineMode.value;
    final isFlutterApp = serviceManager.connectedApp!.isFlutterAppNow!;

    var showFrameAnalysis = isFlutterApp;
    var showRasterStats = isFlutterApp;
    var showRebuildStats = FeatureFlags.widgetRebuildstats && isFlutterApp;
    final offlineData = controller.offlinePerformanceData;
    if (isOffline) {
      final hasOfflineData = offlineData != null;
      showFrameAnalysis =
          showFrameAnalysis && hasOfflineData && offlineData.frames.isNotEmpty;
      showRasterStats =
          showRasterStats && hasOfflineData && offlineData.rasterStats != null;
      showRebuildStats = showRebuildStats &&
          hasOfflineData &&
          offlineData.rebuildCountModel.isNotEmpty;
    }
    final tabRecords = <_PerformanceTabRecord>[
      if (showFrameAnalysis) _frameAnalysisRecord(),
      if (showRasterStats) _rasterStatsRecord(),
      if (showRebuildStats) _rebuildStatsRecord(),
      _timelineEventsRecord(),
    ];

    final tabs = <DevToolsTab>[];
    final tabViews = <Widget>[];
    final featureControllers = <PerformanceFeatureController?>[];
    for (final record in tabRecords) {
      tabs.add(record.tab);
      tabViews.add(record.tabView);
      featureControllers.add(record.featureController);
    }

    // If there is not an active feature, activate the first.
    if (featureControllers.firstWhereOrNull(
          (controller) => controller?.isActiveFeature ?? false,
        ) ==
        null) {
      _setActiveFeature(0, featureControllers[0]);
    }

    return AnalyticsTabbedView(
      tabs: tabs,
      tabViews: tabViews,
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

  _PerformanceTabRecord _frameAnalysisRecord() {
    assert(serviceManager.connectedApp!.isFlutterAppNow!);
    Widget frameAnalysisView;
    final selectedFrame = _selectedFlutterFrame;
    frameAnalysisView = selectedFrame != null
        ? FlutterFrameAnalysisView(
            frameAnalysis: selectedFrame.frameAnalysis,
            enhanceTracingController: controller.enhanceTracingController,
            rebuildCountModel: controller.data!.rebuildCountModel,
          )
        : const Center(
            child: Text('Select a frame above to view analysis data.'),
          );
    return _PerformanceTabRecord(
      tab: _buildTab(tabName: 'Frame Analysis'),
      tabView: KeepAliveWrapper(
        child: frameAnalysisView,
      ),
      featureController: null,
    );
  }

  _PerformanceTabRecord _rebuildStatsRecord() {
    final rebuildStatsView = RebuildStatsView(
      model: controller.data!.rebuildCountModel,
      selectedFrame: controller.flutterFramesController.selectedFrame,
    );

    return _PerformanceTabRecord(
      tab: _buildTab(tabName: 'Rebuild Stats'),
      tabView: KeepAliveWrapper(
        child: rebuildStatsView,
      ),
      featureController: null,
    );
  }

  _PerformanceTabRecord _rasterStatsRecord() {
    assert(serviceManager.connectedApp!.isFlutterAppNow!);
    return _PerformanceTabRecord(
      tab: _buildTab(tabName: 'Raster Stats'),
      tabView: KeepAliveWrapper(
        child: Center(
          child: RasterStatsView(
            rasterStatsController: controller.rasterStatsController,
          ),
        ),
      ),
      featureController: controller.rasterStatsController,
    );
  }

  _PerformanceTabRecord _timelineEventsRecord() {
    return _PerformanceTabRecord(
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
    );
  }

  DevToolsTab _buildTab({required String tabName, Widget? trailing}) {
    return DevToolsTab.create(
      tabName: tabName,
      gaPrefix: _gaPrefix,
      trailing: trailing,
    );
  }
}

class _PerformanceTabRecord extends TabRecord {
  _PerformanceTabRecord({
    required super.tab,
    required super.tabView,
    required this.featureController,
  });

  final PerformanceFeatureController? featureController;
}
