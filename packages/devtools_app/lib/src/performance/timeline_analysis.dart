// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';

import '../analytics/constants.dart' as analytics_constants;
import '../charts/flame_chart.dart';
import '../common_widgets.dart';
import '../theme.dart';
import '../ui/colors.dart';
import '../ui/utils.dart';
import 'flutter_frames_chart.dart';
import 'performance_controller.dart';
import 'performance_model.dart';
import 'performance_screen.dart';

class TimelineAnalysisHeader extends StatelessWidget {
  const TimelineAnalysisHeader({
    Key key,
    @required this.controller,
    @required this.selectedTab,
    @required this.searchFieldBuilder,
  }) : super(key: key);

  final PerformanceController controller;

  final FlutterFrameAnalysisTabData selectedTab;

  final Widget Function() searchFieldBuilder;

  @override
  Widget build(BuildContext context) {
    final showFrameAnalysisButton = frameAnalysisSupported &&
        (controller.selectedFrame.value
                ?.isUiJanky(controller.displayRefreshRate.value) ??
            false);
    return ValueListenableBuilder(
      valueListenable: controller.analysisTabs,
      builder: (context, tabs, _) {
        return AreaPaneHeader(
          title: InkWell(
            onTap: controller.showTimeline,
            child: const Text('Timeline Events'),
          ),
          tall: true,
          needsTopBorder: false,
          rightPadding: 0.0,
          leftActions: [
            const SizedBox(width: denseSpacing),
            RefreshTimelineEventsButton(controller: controller),
            if (showFrameAnalysisButton) AnalyzeFrameButton(controller),
          ],
          scrollableCenterActions: [
            for (final tab in tabs)
              FlutterFrameAnalysisTab(
                tabData: tab,
                isSelected: tab == selectedTab,
                onSelected: () => controller.openAnalysisTab(tab.frame),
                onClosed: () => controller.closeAnalysisTab(tab),
              ),
          ],
          rightActions: [
            searchFieldBuilder(),
            const FlameChartHelpButton(
              gaScreen: PerformanceScreen.id,
              gaSelection: analytics_constants.timelineFlameChartHelp,
            ),
          ],
        );
      },
    );
  }
}

class FlutterFrameAnalysisTab extends StatelessWidget {
  const FlutterFrameAnalysisTab({
    Key key,
    this.tabData,
    this.isSelected,
    this.onSelected,
    this.onClosed,
  }) : super(key: key);

  static const selectionIndicatorHeight = 2.0;

  final FlutterFrameAnalysisTabData tabData;

  final bool isSelected;

  final VoidCallback onSelected;

  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle =
        isSelected ? theme.selectedTextStyle : theme.subtleTextStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '|',
            style: theme.textTheme.headline5.copyWith(
              color: theme.unselectedWidgetColor,
            ),
          ),
          const SizedBox(width: defaultSpacing),
          InkWell(
            onTap: onSelected,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  const SizedBox(
                    height: selectionIndicatorHeight + denseModeDenseSpacing,
                  ),
                Text(
                  tabData.title,
                  style: textStyle,
                ),
                if (isSelected) ...[
                  const SizedBox(height: denseModeDenseSpacing),
                  Container(
                    height: selectionIndicatorHeight,
                    width: calculateTextSpanWidth(
                      TextSpan(
                        text: tabData.title,
                        style: textStyle,
                      ),
                    ),
                    color: defaultSelectionColor,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: defaultSpacing),
          InkWell(
            onTap: onClosed,
            child: Icon(
              Icons.close,
              size: defaultIconSize,
              color: isSelected
                  ? theme.textSelectionTheme.selectionColor
                  : theme.unselectedWidgetColor,
            ),
          ),
        ],
      ),
    );
  }
}

class FlutterFrameAnalysisView extends StatelessWidget {
  const FlutterFrameAnalysisView({
    Key key,
    @required this.frame,
  }) : super(key: key);

  final FlutterFrame frame;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Analysis for frame ${frame.id} - Coming Soon'),
    );
  }
}

class RefreshTimelineEventsButton extends StatelessWidget {
  const RefreshTimelineEventsButton({
    Key key,
    @required this.controller,
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

class AnalyzeFrameButton extends StatelessWidget {
  const AnalyzeFrameButton(this.controller);

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    return DevToolsIconButton(
      iconWidget: FrameAnalysisIcon(
        iconSize: defaultIconSize,
      ),
      onPressed: () =>
          controller.openAnalysisTab(controller.selectedFrame.value),
      tooltip: 'Analyze the selected frame',
      gaScreen: analytics_constants.performance,
      gaSelection: analytics_constants.analyzeSelectedFrame,
    );
  }
}

// TODO(kenz): in the future this could be expanded to show data for an
// arbitrary range of timeline data, not just a single flutter frame.
class FlutterFrameAnalysisTabData {
  FlutterFrameAnalysisTabData(this.title, this.frame);

  final String title;

  final FlutterFrame frame;
}
