// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/charts/flame_chart.dart';
import '../../shared/common_widgets.dart';
import '../../shared/feature_flags.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/theme.dart';
import '../../shared/ui/search.dart';
import '../../shared/ui/tab.dart';
import '../../shared/utils.dart';
import 'panes/flutter_frames/flutter_frame_model.dart';
import 'panes/flutter_frames/flutter_frames_controller.dart';
import 'panes/frame_analysis/frame_analysis.dart';
import 'panes/raster_stats/raster_stats.dart';
import 'panes/rebuild_stats/rebuild_stats.dart';
import 'panes/timeline_events/legacy/timeline_flame_chart.dart';
import 'panes/timeline_events/perfetto/perfetto.dart';
import 'panes/timeline_events/timeline_events_controller.dart';
import 'performance_controller.dart';
import 'performance_screen.dart';

final timelineSearchFieldKey = GlobalKey(debugLabel: 'TimelineSearchFieldKey');

class TabbedPerformanceView extends StatefulWidget {
  const TabbedPerformanceView();

  @override
  _TabbedPerformanceViewState createState() => _TabbedPerformanceViewState();
}

class _TabbedPerformanceViewState extends State<TabbedPerformanceView>
    with
        AutoDisposeMixin,
        SearchFieldMixin<TabbedPerformanceView>,
        ProvidedControllerMixin<PerformanceController, TabbedPerformanceView> {
  static const _gaPrefix = 'performanceTab';

  late FlutterFramesController _flutterFramesController;

  late TimelineEventsController _timelineEventsController;

  FlutterFrame? _selectedFlutterFrame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    _timelineEventsController = controller.timelineEventsController;
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
    if (isOffline && offlineData != null) {
      showFrameAnalysis = showFrameAnalysis && offlineData.frames.isNotEmpty;
      showRasterStats = showRasterStats && offlineData.rasterStats != null;
      showRebuildStats =
          showRebuildStats && offlineData.rebuildCountModel.isNotEmpty;
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

    return AnalyticsTabbedView(
      tabs: tabs,
      tabViews: tabViews,
      initialSelectedIndex: controller.selectedFeatureTabIndex,
      gaScreen: gac.performance,
      onTabChanged: (int index) {
        controller.selectedFeatureTabIndex = index;
        final featureController = featureControllers[index];
        unawaited(controller.setActiveFeature(featureController));
      },
    );
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
        trailing: ValueListenableBuilder<bool>(
          valueListenable: _timelineEventsController.useLegacyTraceViewer,
          builder: (context, useLegacy, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (useLegacy || !FeatureFlags.embeddedPerfetto) ...[
                  ValueListenableBuilder<EventsControllerStatus>(
                    valueListenable: _timelineEventsController.status,
                    builder: (context, status, _) {
                      final searchFieldEnabled =
                          status == EventsControllerStatus.ready;
                      return _buildSearchField(searchFieldEnabled);
                    },
                  ),
                  FlameChartHelpButton(
                    gaScreen: PerformanceScreen.id,
                    gaSelection: gac.timelineFlameChartHelp,
                  ),
                ],
                if (!offlineController.offlineMode.value)
                  RefreshTimelineEventsButton(
                    controller: _timelineEventsController,
                  ),
              ],
            );
          },
        ),
      ),
      tabView: ValueListenableBuilder<bool>(
        valueListenable: _timelineEventsController.useLegacyTraceViewer,
        builder: (context, useLegacy, _) {
          return (useLegacy || !FeatureFlags.embeddedPerfetto)
              ? KeepAliveWrapper(
                  child: DualValueListenableBuilder<EventsControllerStatus,
                      double>(
                    firstListenable: _timelineEventsController.status,
                    secondListenable: _timelineEventsController
                        .legacyController.processor.progressNotifier,
                    builder: (context, status, processingProgress, _) {
                      return TimelineEventsView(
                        controller: _timelineEventsController,
                        processing: status == EventsControllerStatus.processing,
                        processingProgress: processingProgress,
                      );
                    },
                  ),
                )
              : KeepAliveWrapper(
                  child: EmbeddedPerfetto(
                    perfettoController:
                        _timelineEventsController.perfettoController,
                  ),
                );
        },
      ),
      featureController: controller.timelineEventsController,
    );
  }

  Widget _buildSearchField(bool searchFieldEnabled) {
    return Container(
      width: defaultSearchTextWidth,
      height: defaultTextFieldHeight,
      child: buildSearchField(
        controller: _timelineEventsController.legacyController,
        searchFieldKey: timelineSearchFieldKey,
        searchFieldEnabled: searchFieldEnabled,
        shouldRequestFocus: false,
        supportsNavigation: true,
      ),
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

@visibleForTesting
class RefreshTimelineEventsButton extends StatelessWidget {
  const RefreshTimelineEventsButton({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final TimelineEventsController controller;

  @override
  Widget build(BuildContext context) {
    return DevToolsIconButton(
      iconData: Icons.refresh,
      onPressed: controller.processAllTraceEvents,
      tooltip: 'Refresh timeline events',
      gaScreen: gac.performance,
      gaSelection: gac.refreshTimelineEvents,
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
