// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../analytics/constants.dart' as analytics_constants;
import '../../charts/flame_chart.dart';
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../service/service_extensions.dart' as extensions;
import '../../shared/common_widgets.dart';
import '../../shared/theme.dart';
import '../../ui/colors.dart';
import '../../ui/label.dart';
import '../../ui/search.dart';
import '../../ui/tab.dart';
import '../../ui/utils.dart';
import 'enhance_tracing.dart';
import 'performance_controller.dart';
import 'performance_model.dart';
import 'performance_screen.dart';
import 'raster_metrics.dart';
import 'timeline_flame_chart.dart';

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
      );
    } else {
      frameAnalysisView = const Center(
        child: Text('Select a frame above to view analysis data.'),
      );
    }

    final rasterMetrics = Center(
      child: RenderingLayerVisualizer(
        rasterMetricsController: controller.rasterMetricsController,
      ),
    );

    final tabViews = [
      TimelineEventsView(
        controller: controller,
        processing: widget.processing,
        processingProgress: widget.processingProgress,
      ),
      if (frameAnalysisSupported) frameAnalysisView,
      if (rasterMetricsSupported) rasterMetrics,
    ];

    return AnalyticsTabbedView(
      tabs: _generateTabs(),
      tabViews: tabViews,
      gaScreen: analytics_constants.performance,
      // TODO(kenz): enable analytics when this view is stable.
      sendAnalytics: false,
    );
  }

  List<DevToolsTab> _generateTabs() {
    final data = controller.data;
    final hasData = data != null && !data.isEmpty;
    final searchFieldEnabled = hasData && !widget.processing;
    return [
      _buildTab(
        tabName: 'Timeline Events',
        trailing: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildSearchField(searchFieldEnabled),
            const FlameChartHelpButton(
              gaScreen: PerformanceScreen.id,
              gaSelection: analytics_constants.timelineFlameChartHelp,
            ),
            RefreshTimelineEventsButton(controller: controller),
          ],
        ),
      ),
      if (frameAnalysisSupported)
        _buildTab(
          tabName: 'Frame Analysis',
        ),
      if (rasterMetricsSupported)
        _buildTab(
          tabName: 'Raster Metrics',
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
                onPressed:
                    controller.rasterMetricsController.collectRasterStats,
              ),
              const SizedBox(width: denseSpacing),
              ClearButton(
                outlined: false,
                onPressed: controller.rasterMetricsController.clear,
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

class FlutterFrameAnalysisView extends StatelessWidget {
  const FlutterFrameAnalysisView({
    Key? key,
    required this.frameAnalysis,
  }) : super(key: key);

  final FrameAnalysis? frameAnalysis;

  @override
  Widget build(BuildContext context) {
    final frameAnalysis = this.frameAnalysis;
    if (frameAnalysis == null) {
      return const Center(
        child: Text('No analysis data available for this frame.'),
      );
    }
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
    final phasePrefix =
        longestPhase.title != FrameAnalysis.rasterEventName ? 'UI ' : '';
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
            text: ' was the longest ${phasePrefix}phase in this frame. ',
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
      case FrameAnalysis.buildEventName:
        return _enhanceTracingHint(
          extensions.profileWidgetBuilds.title,
          theme,
        );
      case FrameAnalysis.layoutEventName:
        return _enhanceTracingHint(
          extensions.profileRenderObjectLayouts.title,
          theme,
        );
      case FrameAnalysis.paintEventName:
        return _enhanceTracingHint(
          extensions.profileRenderObjectPaints.title,
          theme,
        );
      case FrameAnalysis.rasterEventName:
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

  static const labelPadding = 6.0;

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): find a way to handle taps on this widget and redirect to
    // simulate a tap gesture on the Enhance Tracing button at the top of the
    // screen.
    return RoundedOutlinedBorder(
      child: Padding(
        padding: const EdgeInsets.all(labelPadding),
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
