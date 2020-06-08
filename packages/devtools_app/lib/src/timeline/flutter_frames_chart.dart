// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../theme.dart';
import '../ui/colors.dart';
import '../utils.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';

class FlutterFramesChart extends StatefulWidget {
  const FlutterFramesChart(
    this.frames,
    this.longestFrameDurationMs,
    this.displayRefreshRate,
  );

  static const chartLegendKey = Key('Flutter frames chart legend');

  final List<TimelineFrame> frames;

  final int longestFrameDurationMs;

  final double displayRefreshRate;

  @override
  _FlutterFramesChartState createState() => _FlutterFramesChartState();
}

class _FlutterFramesChartState extends State<FlutterFramesChart>
    with AutoDisposeMixin {
  static const maxMsForDisplay = 48.0;
  static const minMsForDisplay = 18.0;

  static const defaultFrameWidthWithPadding =
      FlutterFramesChartItem.defaultFrameWidth + densePadding * 2;

  static const yAxisUnitsSpace = 48.0;

  static const legendSquareSize = 16.0;

  TimelineController _controller;

  ScrollController scrollController;

  TimelineFrame _selectedFrame;

  double horizontalScrollOffset = 0.0;

  double get totalChartWidth =>
      widget.frames.length * defaultFrameWidthWithPadding;

  double get availableChartHeight => defaultChartHeight - defaultSpacing;

  double get msPerPx =>
      widget.longestFrameDurationMs.clamp(minMsForDisplay, maxMsForDisplay) /
      availableChartHeight;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController()
      ..addListener(() {
        horizontalScrollOffset = scrollController.offset;
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Provider.of<TimelineController>(context);
    if (newController == _controller) return;
    _controller = newController;

    cancel();
    addAutoDisposeListener(_controller.selectedFrame, () {
      setState(() {
        _selectedFrame = _controller.selectedFrame.value;
      });
    });
  }

  @override
  void didUpdateWidget(FlutterFramesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (scrollController.hasClients && scrollController.atScrollBottom) {
      scrollController.autoScrollToBottom();
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: denseSpacing,
        right: denseSpacing,
        bottom: defaultSpacing,
      ),
      height: defaultChartHeight,
      child: Row(
        children: [
          Expanded(child: _buildChart()),
          const SizedBox(width: defaultSpacing),
          _buildChartLegend(),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final themeData = Theme.of(context);
        final chart = ListView.builder(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: widget.frames.length,
          itemExtent: defaultFrameWidthWithPadding,
          itemBuilder: (context, index) => _buildFrame(widget.frames[index]),
        );
        final chartAxisPainter = CustomPaint(
          painter: ChartAxisPainter(
            constraints: constraints,
            totalWidth: totalChartWidth,
            displayRefreshRate: widget.displayRefreshRate,
            msPerPx: msPerPx,
            themeData: themeData,
          ),
        );
        final fpsLinePainter = CustomPaint(
          painter: FPSLinePainter(
            constraints: constraints,
            totalWidth: totalChartWidth,
            displayRefreshRate: widget.displayRefreshRate,
            msPerPx: msPerPx,
            themeData: themeData,
          ),
        );
        return Stack(
          children: [
            chartAxisPainter,
            Padding(
              padding: const EdgeInsets.only(left: yAxisUnitsSpace),
              child: chart,
            ),
            fpsLinePainter,
          ],
        );
      },
    );
  }

  Widget _buildFrame(TimelineFrame frame) {
    return FlutterFramesChartItem(
      frame: frame,
      selected: frame == _selectedFrame,
      onSelected: () => _controller.selectFrame(frame),
      msPerPx: msPerPx,
      availableChartHeight: availableChartHeight,
      displayRefreshRate: widget.displayRefreshRate,
    );
  }

  Widget _buildChartLegend() {
    return Column(
      key: FlutterFramesChart.chartLegendKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legendItem('Frame Time (UI)', mainUiColor),
        const SizedBox(height: denseRowSpacing),
        _legendItem('Frame Time (Raster)', mainRasterColor),
        const SizedBox(height: denseRowSpacing),
        _legendItem('Jank (slow frame)', uiJankColor),
      ],
    );
  }

  Widget _legendItem(String description, Color color) {
    return Row(
      children: [
        Container(
          height: legendSquareSize,
          width: legendSquareSize,
          color: color,
        ),
        const SizedBox(width: denseSpacing),
        Text(description),
      ],
    );
  }
}

class FlutterFramesChartItem extends StatelessWidget {
  const FlutterFramesChartItem({
    @required this.frame,
    @required this.selected,
    @required this.onSelected,
    @required this.msPerPx,
    @required this.availableChartHeight,
    @required this.displayRefreshRate,
  });

  static const defaultFrameWidth = 32.0;

  final TimelineFrame frame;

  final bool selected;

  final VoidCallback onSelected;

  final double msPerPx;

  final double availableChartHeight;

  final double displayRefreshRate;

  @override
  Widget build(BuildContext context) {
    final bool janky = _isFrameJanky(frame);
    // TODO(kenz): add some indicator when a frame is so janky that it exceeds the
    // available axis space.
    final ui = Container(
      key: Key('frame ${frame.id} - ui'),
      width: defaultFrameWidth / 2,
      height: (frame.uiDurationMs / msPerPx).clamp(0.0, availableChartHeight),
      color: janky ? uiJankColor : mainUiColor,
    );
    final raster = Container(
      key: Key('frame ${frame.id} - raster'),
      width: defaultFrameWidth / 2,
      height:
          (frame.rasterDurationMs / msPerPx).clamp(0.0, availableChartHeight),
      color: janky ? rasterJankColor : mainRasterColor,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: densePadding),
      color: selected ? chartAccentColor : null,
      child: Column(
        children: [
          // Dummy child so that the InkWell does not take up the entire column.
          const Expanded(child: SizedBox()),
          InkWell(
            // TODO(kenz): make tooltip to persist if the frame is selected.
            // TODO(kenz): change color on hover.
            onTap: onSelected,
            child: Tooltip(
              message: _tooltipText(frame),
              padding: const EdgeInsets.all(denseSpacing),
              preferBelow: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ui,
                  raster,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _tooltipText(TimelineFrame frame) {
    return 'UI: ${msText(frame.uiEventFlow.time.duration)}\n'
        'Raster: ${msText(frame.rasterEventFlow.time.duration)}';
  }

  bool _isFrameJanky(TimelineFrame frame) {
    final targetMsPerFrame = 1 / displayRefreshRate * 1000;
    return frame.uiDurationMs > targetMsPerFrame ||
        frame.rasterDurationMs > targetMsPerFrame;
  }
}

class ChartAxisPainter extends CustomPainter {
  ChartAxisPainter({
    @required this.constraints,
    @required this.totalWidth,
    @required this.displayRefreshRate,
    @required this.msPerPx,
    @required this.themeData,
  });

  static const yAxisTickWidth = 8.0;

  final BoxConstraints constraints;

  final double totalWidth;

  final double displayRefreshRate;

  final double msPerPx;

  final ThemeData themeData;

  @override
  void paint(Canvas canvas, Size size) {
    // The absolute coordinates of the chart's visible area.
    final chartArea = Rect.fromLTWH(
      _FlutterFramesChartState.yAxisUnitsSpace,
      0.0,
      constraints.maxWidth - _FlutterFramesChartState.yAxisUnitsSpace,
      constraints.maxHeight,
    );

    // Paint the Y axis.
    canvas.drawLine(
      chartArea.topLeft,
      chartArea.bottomLeft,
      Paint()..color = chartAccentColor,
    );

    // Paint the X axis
    canvas.drawLine(
      chartArea.bottomLeft,
      chartArea.bottomRight,
      Paint()..color = chartAccentColor,
    );

    _paintYAxisLabels(canvas, chartArea);
  }

  void _paintYAxisLabels(
    Canvas canvas,
    Rect chartArea,
  ) {
    const yAxisLabelCount = 6;
    final totalMs = msPerPx * constraints.maxHeight;

    // Subtract 1 because one of the labels will be 0.0 ms.
    final int timeUnitMs = totalMs ~/ (yAxisLabelCount - 1);

    // Max FPS non-jank value in ms. E.g., 16.6 for 60 FPS, 8.3 for 120 FPS.
    final targetMsPerFrame = 1 / displayRefreshRate * 1000;
    final targetMsPerFrameRounded = targetMsPerFrame.round();

    // TODO(kenz): maybe we should consider making these round values in
    // multiples of 5 or 10?
    // Y axis time units centered around [targetMsPerFrameRounded].
    final yAxisTimes = [
      0,
      for (int timeMs = targetMsPerFrameRounded - timeUnitMs;
          timeMs > 0;
          timeMs -= timeUnitMs)
        timeMs,
      targetMsPerFrameRounded,
      for (int timeMs = targetMsPerFrameRounded + timeUnitMs;
          timeMs < totalMs;
          timeMs += timeUnitMs)
        timeMs,
    ];

    for (final timeMs in yAxisTimes) {
      _paintYAxisLabel(canvas, chartArea, timeMs: timeMs);
    }
  }

  void _paintYAxisLabel(
    Canvas canvas,
    Rect chartArea, {
    @required int timeMs,
  }) {
    final labelText = msText(
      Duration(milliseconds: timeMs),
      fractionDigits: 0,
    );

    // Paint a tick on the axis.
    final tickY = constraints.maxHeight - timeMs / msPerPx;
    canvas.drawLine(
      Offset(chartArea.left - yAxisTickWidth / 2, tickY),
      Offset(chartArea.left + yAxisTickWidth / 2, tickY),
      Paint()..color = chartAccentColor,
    );

    // Paint the axis label.
    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: const TextStyle(
          color: chartSubtleColor,
          fontSize: chartFontSizeSmall,
        ),
      ),
      textAlign: TextAlign.end,
      textDirection: TextDirection.ltr,
    )..layout();

    const baselineAdjust = 2.0;

    textPainter.paint(
      canvas,
      Offset(
        _FlutterFramesChartState.yAxisUnitsSpace -
            yAxisTickWidth / 2 -
            densePadding - // Padding between y axis tick and label
            textPainter.width,
        constraints.maxHeight -
            timeMs / msPerPx -
            textPainter.height / 2 -
            baselineAdjust,
      ),
    );
  }

  @override
  bool shouldRepaint(ChartAxisPainter oldDelegate) {
    return themeData.isDarkTheme != oldDelegate.themeData.isDarkTheme;
  }
}

class FPSLinePainter extends CustomPainter {
  FPSLinePainter({
    @required this.constraints,
    @required this.totalWidth,
    @required this.displayRefreshRate,
    @required this.msPerPx,
    @required this.themeData,
  });

  static const fpsTextSpace = 40.0;

  final BoxConstraints constraints;

  final double totalWidth;

  final double displayRefreshRate;

  final double msPerPx;

  final ThemeData themeData;

  @override
  void paint(Canvas canvas, Size size) {
    // The absolute coordinates of the chart's visible area.
    final chartArea = Rect.fromLTWH(
      _FlutterFramesChartState.yAxisUnitsSpace,
      0.0,
      constraints.maxWidth - _FlutterFramesChartState.yAxisUnitsSpace,
      constraints.maxHeight,
    );

    // Max FPS non-jank value in ms. E.g., 16.6 for 60 FPS, 8.3 for 120 FPS.
    final targetMsPerFrame = 1 / displayRefreshRate * 1000;
    final targetLineY = constraints.maxHeight - targetMsPerFrame / msPerPx;

    canvas.drawLine(
      Offset(chartArea.left, targetLineY),
      Offset(chartArea.right, targetLineY),
      Paint()..color = chartAccentColor,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${displayRefreshRate.toStringAsFixed(0)} FPS',
        style: const TextStyle(
          color: chartSubtleColor,
          fontSize: chartFontSizeSmall,
        ),
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        chartArea.right - fpsTextSpace,
        targetLineY + borderPadding,
      ),
    );
  }

  @override
  bool shouldRepaint(FPSLinePainter oldDelegate) {
    return themeData.isDarkTheme != oldDelegate.themeData.isDarkTheme;
  }
}
