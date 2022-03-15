// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../analytics/constants.dart' as analytics_constants;
import '../../charts/flame_chart.dart';
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/theme.dart';
import '../../ui/colors.dart';
import '../../ui/utils.dart';
import 'performance_controller.dart';
import 'performance_model.dart';
import 'performance_screen.dart';

class TimelineAnalysisHeader extends StatelessWidget {
  const TimelineAnalysisHeader({
    Key? key,
    required this.controller,
    required this.selectedTab,
    required this.searchFieldBuilder,
  }) : super(key: key);

  final PerformanceController controller;

  final FlutterFrameAnalysisTabData? selectedTab;

  final Widget Function() searchFieldBuilder;

  @override
  Widget build(BuildContext context) {
    final showFrameAnalysisButton = frameAnalysisSupported &&
        (controller.selectedFrame.value
                ?.isUiJanky(controller.displayRefreshRate.value) ??
            false) &&
        (controller.selectedFrame.value?.timelineEventData.isNotEmpty ?? false);
    return ValueListenableBuilder<List<FlutterFrameAnalysisTabData>>(
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
    Key? key,
    required this.tabData,
    required this.isSelected,
    required this.onSelected,
    required this.onClosed,
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
            style: theme.textTheme.headline5!.copyWith(
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
    Key? key,
    required this.frameAnalysis,
  }) : super(key: key);

  final FrameAnalysis frameAnalysis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(defaultSpacing),
      child: Column(
        children: [
          // TODO(kenz): add IntelligentFrameFindings here
          // TODO(kenz): handle missing timeline events.
          Expanded(
            child: FrameTimeVisualizer(frameAnalysis: frameAnalysis),
          ),
        ],
      ),
    );
  }
}

class FrameTimeVisualizer extends StatefulWidget {
  const FrameTimeVisualizer({
    Key? key,
    required this.frameAnalysis,
  }) : super(key: key);

  final FrameAnalysis frameAnalysis;

  @override
  State<FrameTimeVisualizer> createState() => _FrameTimeVisualizerState();
}

class _FrameTimeVisualizerState extends State<FrameTimeVisualizer> {
  static const _build = 'Build';

  static const _layout = 'Layout';

  static const _paint = 'Paint';

  static const _raster = 'Raster';

  late String _selectedBlockTitle;

  @override
  void initState() {
    super.initState();
    // TODO(kenz): automatically select the most expensive part of the frame.
    _selectedBlockTitle = _build;
  }

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): calculate ratios to use as flex values. This will be a bit
    // tricky because sometimes the Build event(s) are children of Layout.
    // final buildTimeRatio = widget.frameAnalysis.buildTimeRatio();
    // final layoutTimeRatio = widget.frameAnalysis.layoutTimeRatio();
    // final paintTimeRatio = widget.frameAnalysis.paintTimeRatio();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('UI phases:'),
        const SizedBox(height: denseSpacing),
        Row(
          children: [
            Flexible(
              child: FrameTimeVisualizerBlock(
                label: _build,
                icon: Icons.build,
                duration: widget.frameAnalysis.buildTime,
                isSelected: _selectedBlockTitle == _build,
                onSelected: _onBlockSelected,
              ),
            ),
            Flexible(
              child: FrameTimeVisualizerBlock(
                label: _layout,
                icon: Icons.auto_awesome_mosaic,
                duration: widget.frameAnalysis.layoutTime,
                isSelected: _selectedBlockTitle == _layout,
                onSelected: _onBlockSelected,
              ),
            ),
            Flexible(
              fit: FlexFit.tight,
              child: FrameTimeVisualizerBlock(
                label: _paint,
                icon: Icons.format_paint,
                duration: widget.frameAnalysis.paintTime,
                isSelected: _selectedBlockTitle == _paint,
                onSelected: _onBlockSelected,
              ),
            ),
          ],
        ),
        const SizedBox(height: denseSpacing),
        const Text('Raster phase:'),
        const SizedBox(height: denseSpacing),
        Row(
          children: [
            Expanded(
              child: FrameTimeVisualizerBlock(
                label: _raster,
                icon: Icons.grid_on,
                duration: widget.frameAnalysis.frame.timelineEventData
                        .rasterEvent?.time.duration ??
                    Duration.zero,
                isSelected: _selectedBlockTitle == _raster,
                onSelected: _onBlockSelected,
              ),
            )
          ],
        ),
        const SizedBox(height: defaultSpacing),
        Expanded(
          child: FrameSectionProfile(selectedSection: _selectedBlockTitle),
        ),
      ],
    );
  }

  void _onBlockSelected(String blockName) {
    setState(() {
      _selectedBlockTitle = blockName;
    });
  }
}

class FrameTimeVisualizerBlock extends StatelessWidget {
  const FrameTimeVisualizerBlock({
    Key? key,
    required this.label,
    required this.icon,
    required this.duration,
    required this.isSelected,
    required this.onSelected,
  }) : super(key: key);

  static const _height = 30.0;

  static const _selectedIndicatorHeight = 4.0;

  static const _backgroundColor = ThemedColor(
    light: Color(0xFFEEEEEE),
    dark: Color(0xFF3C4043),
  );

  static const _selectedBackgroundColor = ThemedColor(
    light: Color(0xFFFFFFFF),
    dark: Color(0xFF5F6367),
  );

  final String label;

  final IconData icon;

  final Duration duration;

  final bool isSelected;

  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final durationText = msText(duration);
    return InkWell(
      onTap: () => onSelected(label),
      child: Stack(
        alignment: AlignmentDirectional.bottomStart,
        children: [
          Container(
            color: isSelected
                ? _selectedBackgroundColor.colorFor(colorScheme)
                : _backgroundColor.colorFor(colorScheme),
            height: _height,
            padding: const EdgeInsets.symmetric(horizontal: densePadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: defaultIconSize,
                ),
                const SizedBox(width: denseSpacing),
                Text('$label - $durationText'),
              ],
            ),
          ),
          if (isSelected)
            Container(
              color: defaultSelectionColor,
              height: _selectedIndicatorHeight,
            ),
        ],
      ),
    );
  }
}

class FrameSectionProfile extends StatelessWidget {
  const FrameSectionProfile({
    Key? key,
    required this.selectedSection,
  }) : super(key: key);

  // TODO(kenz): pass the event to this section instead of the title.
  final String selectedSection;

  @override
  Widget build(BuildContext context) {
    return RoundedOutlinedBorder(
      child: Center(
        child: Text(
            'flame chart / bottom up chart showing timeline events for $selectedSection'),
      ),
    );
  }
}

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

class AnalyzeFrameButton extends StatelessWidget {
  const AnalyzeFrameButton(this.controller);

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    return DevToolsIconButton(
      iconData: Icons.saved_search,
      onPressed: () =>
          controller.openAnalysisTab(controller.selectedFrame.value!),
      tooltip: 'Analyze the selected frame',
      gaScreen: analytics_constants.performance,
      gaSelection: analytics_constants.analyzeSelectedFrame,
    );
  }
}

// TODO(kenz): in the future this could be expanded to show data for an
// arbitrary range of timeline data, not just a single flutter frame.
class FlutterFrameAnalysisTabData {
  FlutterFrameAnalysisTabData(this.title, FlutterFrame frame)
      : frameAnalysis = FrameAnalysis(frame);

  final String title;

  final FrameAnalysis frameAnalysis;

  FlutterFrame get frame => frameAnalysis.frame;
}
