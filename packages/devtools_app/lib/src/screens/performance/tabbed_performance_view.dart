// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../charts/flame_chart.dart';
import '../../primitives/auto_dispose_mixin.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/theme.dart';
import '../../ui/search.dart';
import '../../ui/tab.dart';
import 'panes/frame_analysis/frame_analysis.dart';
import 'panes/raster_stats/raster_stats.dart';
import 'panes/timeline_events/perfetto/perfetto.dart';
import 'panes/timeline_events/timeline_flame_chart.dart';
import 'performance_controller.dart';
import 'performance_model.dart';
import 'performance_screen.dart';

final timelineSearchFieldKey = GlobalKey(debugLabel: 'TimelineSearchFieldKey');

class TabbedPerformanceView extends StatefulWidget {
  const TabbedPerformanceView({
    required this.controller,
    required this.processing,
    required this.processingProgress,
  });

  final PerformanceController controller;

  final bool processing;

  final double processingProgress;

  @override
  _TabbedPerformanceViewState createState() => _TabbedPerformanceViewState();
}

class _TabbedPerformanceViewState extends State<TabbedPerformanceView>
    with AutoDisposeMixin, SearchFieldMixin<TabbedPerformanceView> {
  static const _gaPrefix = 'performanceTab';

  PerformanceController get controller => widget.controller;

  FlutterFrame? _selectedFlutterFrame;

  @override
  void initState() {
    super.initState();

    _selectedFlutterFrame = controller.selectedFrame.value;
    addAutoDisposeListener(controller.selectedFrame, () {
      setState(() {
        _selectedFlutterFrame = controller.selectedFrame.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    late Widget frameAnalysisView;
    final selectedFrame = _selectedFlutterFrame;
    if (selectedFrame != null) {
      frameAnalysisView = FlutterFrameAnalysisView(
        frameAnalysis: selectedFrame.frameAnalysis,
        enhanceTracingController: controller.enhanceTracingController,
      );
    } else {
      frameAnalysisView = const Center(
        child: Text('Select a frame above to view analysis data.'),
      );
    }

    final rasterStats = Center(
      child: RenderingLayerVisualizer(
        rasterStatsController: controller.rasterStatsController,
      ),
    );

    final isFlutterApp = serviceManager.connectedApp!.isFlutterAppNow!;
    final tabViews = [
      embeddedPerfettoEnabled
          ? KeepAliveWrapper(
              child: EmbeddedPerfetto(
                perfettoController: controller.perfettoController,
              ),
            )
          : KeepAliveWrapper(
              child: TimelineEventsView(
                controller: controller,
                processing: widget.processing,
                processingProgress: widget.processingProgress,
              ),
            ),
      if (frameAnalysisSupported && isFlutterApp)
        KeepAliveWrapper(
          child: frameAnalysisView,
        ),
      if (rasterStatsSupported && isFlutterApp)
        KeepAliveWrapper(
          child: rasterStats,
        ),
    ];

    return AnalyticsTabbedView(
      tabs: _generateTabs(isFlutterApp: isFlutterApp),
      tabViews: tabViews,
      gaScreen: analytics_constants.performance,
    );
  }

  List<DevToolsTab> _generateTabs({required bool isFlutterApp}) {
    final data = controller.data;
    final hasData = data != null && !data.isEmpty;
    final searchFieldEnabled = hasData && !widget.processing;
    return [
      _buildTab(
        tabName: 'Timeline Events',
        trailing: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!embeddedPerfettoEnabled) ...[
              _buildSearchField(searchFieldEnabled),
              const FlameChartHelpButton(
                gaScreen: PerformanceScreen.id,
                gaSelection: analytics_constants.timelineFlameChartHelp,
              ),
            ],
            RefreshTimelineEventsButton(controller: controller),
          ],
        ),
      ),
      if (frameAnalysisSupported && isFlutterApp)
        _buildTab(
          tabName: 'Frame Analysis',
        ),
      if (rasterStatsSupported && isFlutterApp)
        _buildTab(
          tabName: 'Raster Stats',
          trailing: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconLabelButton(
                tooltip:
                    'Take a snapshot of the rendering layers on the current'
                    ' screen',
                icon: Icons.camera,
                label: 'Take Snapshot',
                outlined: false,
                onPressed: () {
                  ga.select(
                    PerformanceScreen.id,
                    analytics_constants.collectRasterStats,
                  );
                  controller.collectRasterStats();
                },
              ),
              const SizedBox(width: denseSpacing),
              ClearButton(
                outlined: false,
                onPressed: controller.rasterStatsController.clear,
              ),
              const SizedBox(width: densePadding),
            ],
          ),
        ),
    ];
  }

  Widget _buildSearchField(bool searchFieldEnabled) {
    return Container(
      width: defaultSearchTextWidth,
      height: defaultTextFieldHeight,
      child: buildSearchField(
        controller: controller,
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

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    return DevToolsIconButton(
      iconData: Icons.refresh,
      onPressed: controller.processAvailableEvents,
      tooltip: 'Refresh timeline events',
      gaScreen: analytics_constants.performance,
      gaSelection: analytics_constants.refreshTimelineEvents,
    );
  }
}
