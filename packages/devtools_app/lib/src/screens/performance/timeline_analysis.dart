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
import '../../ui/label.dart';
import '../../ui/utils.dart';
import 'performance_controller.dart';
import 'performance_model.dart';
import 'performance_screen.dart';
import 'timeline_events_profile.dart';

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
          IntelligentFrameFindings(frameAnalysis: frameAnalysis),
          const PaddedDivider(
            padding: EdgeInsets.only(
              top: denseSpacing,
              bottom: denseSpacing,
            ),
          ),
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
  late FrameAnalysis frameAnalysis;

  @override
  void initState() {
    super.initState();
    frameAnalysis = widget.frameAnalysis;
    frameAnalysis.selectFramePhase(frameAnalysis.longestFramePhase);
  }

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): calculate ratios to use as flex values. This will be a bit
    // tricky because sometimes the Build event(s) are children of Layout.
    // final buildTimeRatio = widget.frameAnalysis.buildTimeRatio();
    // final layoutTimeRatio = widget.frameAnalysis.layoutTimeRatio();
    // final paintTimeRatio = widget.frameAnalysis.paintTimeRatio();
    return ValueListenableBuilder<FramePhase?>(
      valueListenable: frameAnalysis.selectedPhase,
      builder: (context, selectedPhase, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('UI phases:'),
            const SizedBox(height: denseSpacing),
            Row(
              children: [
                Flexible(
                  child: FramePhaseBlock(
                    framePhase: frameAnalysis.buildPhase,
                    icon: Icons.build,
                    isSelected: selectedPhase == frameAnalysis.buildPhase,
                    onSelected: frameAnalysis.selectFramePhase,
                  ),
                ),
                Flexible(
                  child: FramePhaseBlock(
                    framePhase: frameAnalysis.layoutPhase,
                    icon: Icons.auto_awesome_mosaic,
                    isSelected: selectedPhase == frameAnalysis.layoutPhase,
                    onSelected: frameAnalysis.selectFramePhase,
                  ),
                ),
                Flexible(
                  fit: FlexFit.tight,
                  child: FramePhaseBlock(
                    framePhase: frameAnalysis.paintPhase,
                    icon: Icons.format_paint,
                    isSelected: selectedPhase == frameAnalysis.paintPhase,
                    onSelected: frameAnalysis.selectFramePhase,
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
                  child: FramePhaseBlock(
                    framePhase: frameAnalysis.rasterPhase,
                    icon: Icons.grid_on,
                    isSelected: selectedPhase == frameAnalysis.rasterPhase,
                    onSelected: frameAnalysis.selectFramePhase,
                  ),
                )
              ],
            ),
            // TODO(kenz): show flame chart of selected events here.
          ],
        );
      },
    );
  }
}

class FramePhaseBlock extends StatelessWidget {
  const FramePhaseBlock({
    Key? key,
    required this.framePhase,
    required this.icon,
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

  final FramePhase framePhase;

  final IconData icon;

  final bool isSelected;

  final void Function(FramePhase) onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final durationText = framePhase.duration != Duration.zero
        ? msText(framePhase.duration)
        : '--';
    return InkWell(
      onTap: () => onSelected(framePhase),
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
                Text('${framePhase.title} - $durationText'),
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

// TODO(kenz): provide hints about expensive flutter operations
// (canvas.saveLayer(), intrinsics, etc.).
class IntelligentFrameFindings extends StatelessWidget {
  const IntelligentFrameFindings({
    Key? key,
    required this.frameAnalysis,
  }) : super(key: key);

  final FrameAnalysis frameAnalysis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Analysis results:'),
        const SizedBox(height: denseSpacing),
        _Hint(
          message: _EnhanceTracingHint(
            longestPhase: frameAnalysis.longestFramePhase,
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({Key? key, required this.message}) : super(key: key);

  final Widget message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.lightbulb_outline,
          size: defaultIconSize,
        ),
        const SizedBox(width: denseSpacing),
        Expanded(child: message),
      ],
    );
  }
}

class _EnhanceTracingHint extends StatelessWidget {
  const _EnhanceTracingHint({Key? key, required this.longestPhase})
      : super(key: key);

  final FramePhase longestPhase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      maxLines: 2,
      text: TextSpan(
        text: '',
        children: [
          TextSpan(
            text: longestPhase.title,
            style: theme.fixedFontStyle,
          ),
          TextSpan(
            text: ' was the longest phase in this frame. ',
            style: theme.regularTextStyle,
          ),
          ..._hintForPhase(longestPhase, theme),
        ],
      ),
    );
  }

  List<InlineSpan> _hintForPhase(
    FramePhase phase,
    ThemeData theme,
  ) {
    switch (phase.title) {
      case 'Build':
        return _enhanceTracingHint('Track Widget Builds', theme);
      case 'Layout':
        return _enhanceTracingHint('Track Layouts', theme);
      case 'Paint':
        return _enhanceTracingHint('Track Paints', theme);
      case 'Raster':
        // TODO(kenz): link to shader compilation docs. In the future, integrate
        // with the work @iskakaushik is doing.
        return [];
      default:
        return [];
    }
  }

  List<InlineSpan> _enhanceTracingHint(
    String settingTitle,
    ThemeData theme,
  ) {
    const enhanceTracingButton = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: denseSpacing),
        child: _SmallEnhanceTracingButton(),
      ),
    );
    return [
      TextSpan(
        text: 'Consider enabling "$settingTitle" from the ',
        style: theme.regularTextStyle,
      ),
      enhanceTracingButton,
      TextSpan(
        text: ' options above and reproducing the behavior in your app.',
        style: theme.regularTextStyle,
      ),
    ];
  }
}

class _SmallEnhanceTracingButton extends StatelessWidget {
  const _SmallEnhanceTracingButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): find a way to handle taps on this widget and redirect to
    // simulate a tap gesture on the Enhance Tracing button at the top of the
    // screen.
    return RoundedOutlinedBorder(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: MaterialIconLabel(
          label: EnhanceTracingButton.title,
          iconData: EnhanceTracingButton.icon,
          color: Theme.of(context).colorScheme.toggleButtonsTitle,
        ),
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
