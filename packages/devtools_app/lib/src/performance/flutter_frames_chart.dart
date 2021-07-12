// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../banner_messages.dart';
import '../common_widgets.dart';
import '../globals.dart';
import '../scaffold.dart';
import '../theme.dart';
import '../ui/colors.dart';
import '../utils.dart';
import 'performance_controller.dart';
import 'performance_model.dart';
import 'performance_screen.dart';

// Turn this flag on to see when flutter frames are linked with timeline events.
bool debugFrames = false;

class FlutterFramesChart extends StatefulWidget {
  const FlutterFramesChart(
    this.frames,
    this.displayRefreshRate,
  );

  static const chartLegendKey = Key('Flutter frames chart legend');

  final List<FlutterFrame> frames;

  final double displayRefreshRate;

  @override
  _FlutterFramesChartState createState() => _FlutterFramesChartState();
}

class _FlutterFramesChartState extends State<FlutterFramesChart>
    with AutoDisposeMixin {
  static const defaultFrameWidthWithPadding =
      FlutterFramesChartItem.defaultFrameWidth + densePadding * 2;

  static const yAxisUnitsSpace = 48.0;

  static const legendSquareSize = 16.0;

  static const outlineBorderWidth = 1.0;

  PerformanceController _controller;

  ScrollController scrollController;

  FlutterFrame _selectedFrame;

  double horizontalScrollOffset = 0.0;

  double get availableChartHeight => defaultChartHeight - defaultSpacing;

  /// Milliseconds per pixel value for the y-axis.
  ///
  /// This value will result in a y-axis time range spanning two times the
  /// target frame time for a single frame (e.g. 16.6 * 2 for a 60 FPS device).
  double get msPerPx =>
      // Multiply by two to reach two times the target frame time.
      1 / widget.displayRefreshRate * 1000 * 2 / availableChartHeight;

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
    final newController = Provider.of<PerformanceController>(context);
    if (newController == _controller) return;
    _controller = newController;

    cancel();
    _selectedFrame = _controller.selectedFrame.value;
    addAutoDisposeListener(_controller.selectedFrame, () {
      setState(() {
        _selectedFrame = _controller.selectedFrame.value;
      });
    });

    _maybeShowShaderJankMessage();
  }

  @override
  void didUpdateWidget(FlutterFramesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (scrollController.hasClients && scrollController.atScrollBottom) {
      scrollController.autoScrollToBottom();
    }

    if (!collectionEquals(oldWidget.frames, widget.frames)) {
      _maybeShowShaderJankMessage();
    }
  }

  void _maybeShowShaderJankMessage() {
    final shaderJankFrames = widget.frames
        .where((frame) => frame.hasShaderJank(widget.displayRefreshRate))
        .toList();
    if (shaderJankFrames.isNotEmpty) {
      final Duration shaderJankDuration = shaderJankFrames.fold(
        Duration.zero,
        (prev, frame) => prev + frame.shaderDuration,
      );
      Provider.of<BannerMessagesController>(context).addMessage(
        ShaderJankMessage(
          offlineMode ? SimpleScreen.id : PerformanceScreen.id,
          jankyFramesCount: shaderJankFrames.length,
          jankDuration: shaderJankDuration,
        ).build(context),
      );
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
      height: defaultChartHeight + defaultScrollBarOffset,
      child: Row(
        children: [
          Expanded(child: _buildChart()),
          const SizedBox(width: defaultSpacing),
          Padding(
            padding: const EdgeInsets.only(bottom: defaultScrollBarOffset),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChartLegend(),
                if (widget.frames.isNotEmpty) _buildAverageFps(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final themeData = Theme.of(context);
        final chart = Scrollbar(
          isAlwaysShown: true,
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.only(bottom: defaultScrollBarOffset),
            child: RoundedOutlinedBorder(
              child: ListView.builder(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: widget.frames.length,
                itemExtent: defaultFrameWidthWithPadding,
                itemBuilder: (context, index) =>
                    _buildFrame(widget.frames[index]),
              ),
            ),
          ),
        );
        final chartAxisPainter = CustomPaint(
          painter: ChartAxisPainter(
            constraints: constraints,
            displayRefreshRate: widget.displayRefreshRate,
            msPerPx: msPerPx,
            themeData: themeData,
          ),
        );
        final fpsLinePainter = CustomPaint(
          painter: FPSLinePainter(
            constraints: constraints,
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

  Widget _buildFrame(FlutterFrame frame) {
    return InkWell(
      onTap: () => _controller.toggleSelectedFrame(frame),
      child: FlutterFramesChartItem(
        frame: frame,
        selected: frame == _selectedFrame,
        msPerPx: msPerPx,
        availableChartHeight: availableChartHeight - 2 * outlineBorderWidth,
        displayRefreshRate: widget.displayRefreshRate,
      ),
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
        const SizedBox(height: denseRowSpacing),
        _legendItem('Shader Compilation', shaderCompilationColor),
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

  Widget _buildAverageFps() {
    final double sumFrameTimesMs = widget.frames.fold(
      0.0,
      (sum, frame) =>
          sum +
          math.max(
            1000 / widget.displayRefreshRate,
            math.max(
              frame.buildTime.inMilliseconds,
              frame.rasterTime.inMilliseconds,
            ),
          ),
    );
    final avgFrameTime = sumFrameTimesMs / widget.frames.length;
    final avgFps = (1 / avgFrameTime * 1000).round();
    return Text(
      '$avgFps FPS (average)',
      maxLines: 2,
    );
  }
}

class FlutterFramesChartItem extends StatelessWidget {
  const FlutterFramesChartItem({
    @required this.frame,
    @required this.selected,
    @required this.msPerPx,
    @required this.availableChartHeight,
    @required this.displayRefreshRate,
  });

  static const defaultFrameWidth = 32.0;

  static const selectedIndicatorHeight = 8.0;

  static const selectedFrameIndicatorKey =
      Key('flutter frames chart - selected frame indicator');

  final FlutterFrame frame;

  final bool selected;

  final double msPerPx;

  final double availableChartHeight;

  final double displayRefreshRate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final bool uiJanky = frame.isUiJanky(displayRefreshRate);
    final bool rasterJanky = frame.isRasterJanky(displayRefreshRate);
    final bool hasShaderJank = frame.hasShaderJank(displayRefreshRate);

    var uiColor = uiJanky ? uiJankColor : mainUiColor;
    var rasterColor = rasterJanky ? rasterJankColor : mainRasterColor;
    var shaderColor = shaderCompilationColor;

    if (debugFrames) {
      if (frame.timelineEventData.uiEvent == null) {
        uiColor = uiColor.darken(.5);
      }
      if (frame.timelineEventData.rasterEvent == null) {
        rasterColor = rasterColor.darken(.5);
        shaderColor = shaderColor.darken(.5);
      }
    }

    // TODO(kenz): add some indicator when a frame is so janky that it exceeds the
    // available axis space.
    final ui = Container(
      key: Key('frame ${frame.id} - ui'),
      width: defaultFrameWidth / 2,
      height: (frame.buildTime.inMilliseconds / msPerPx)
          .clamp(0.0, availableChartHeight),
      color: uiColor,
    );

    final shaderToRasterRatio =
        frame.shaderDuration.inMilliseconds / frame.rasterTime.inMilliseconds;

    final raster = Column(
      children: [
        Container(
          key: Key('frame ${frame.id} - raster'),
          width: defaultFrameWidth / 2,
          height: ((frame.rasterTime.inMilliseconds -
                      frame.shaderDuration.inMilliseconds) /
                  msPerPx)
              .clamp(0.0, availableChartHeight * (1 - shaderToRasterRatio)),
          color: rasterColor,
        ),
        if (frame.hasShaderTime)
          Container(
            key: Key('frame ${frame.id} - shaders'),
            width: defaultFrameWidth / 2,
            height: (frame.shaderDuration.inMilliseconds / msPerPx)
                .clamp(0.0, availableChartHeight * shaderToRasterRatio),
            color: shaderColor,
          ),
      ],
    );

    return Stack(
      children: [
        // TODO(kenz): make tooltip to persist if the frame is selected.
        DevToolsTooltip(
          tooltip: _tooltipText(frame, hasShaderJank),
          padding: const EdgeInsets.all(denseSpacing),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: densePadding),
            color: selected ? colorScheme.selectedFrameBackgroundColor : null,
            child: Column(
              children: [
                // Dummy child so that the InkWell does not take up the entire column.
                const Expanded(child: SizedBox()),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ui,
                    raster,
                  ],
                ),
              ],
            ),
          ),
        ),
        if (selected)
          Container(
            key: selectedFrameIndicatorKey,
            color: defaultSelectionColor,
            height: selectedIndicatorHeight,
          ),
        if (hasShaderJank)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              ShaderJankWarningIcon(),
            ],
          ),
      ],
    );
  }

  // TODO(kenz): Support a rich tooltip
  // https://github.com/flutter/devtools/issues/3139
  String _tooltipText(FlutterFrame frame, bool hasShaderJank) {
    return [
      'UI: ${msText(frame.buildTime)}',
      'Raster: ${msText(frame.rasterTime)}',
      if (hasShaderJank) 'Shader Compilation: ${msText(frame.shaderDuration)}',
    ].join('\n');
  }
}

class ShaderJankWarningIcon extends StatefulWidget {
  const ShaderJankWarningIcon({Key key}) : super(key: key);

  @override
  State<ShaderJankWarningIcon> createState() => _ShaderJankWarningIconState();
}

class _ShaderJankWarningIconState extends State<ShaderJankWarningIcon> {
  Timer timer;

  bool showFirst;

  @override
  void initState() {
    super.initState();
    showFirst = true;
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        showFirst = !showFirst;
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(seconds: 1),
      firstChild: _warningIcon(),
      secondChild: _warningIcon(color: Colors.amber),
      crossFadeState:
          showFirst ? CrossFadeState.showFirst : CrossFadeState.showSecond,
    );
  }

  Widget _warningIcon({Color color}) {
    return Icon(
      Icons.warning_amber_rounded,
      color: color,
    );
  }
}

class ChartAxisPainter extends CustomPainter {
  ChartAxisPainter({
    @required this.constraints,
    @required this.displayRefreshRate,
    @required this.msPerPx,
    @required this.themeData,
  });

  static const yAxisTickWidth = 8.0;

  final BoxConstraints constraints;

  final double displayRefreshRate;

  final double msPerPx;

  final ThemeData themeData;

  ColorScheme get colorScheme => themeData.colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    // The absolute coordinates of the chart's visible area.
    final chartArea = Rect.fromLTWH(
      _FlutterFramesChartState.yAxisUnitsSpace,
      0.0,
      constraints.maxWidth - _FlutterFramesChartState.yAxisUnitsSpace,
      constraints.maxHeight - defaultScrollBarOffset,
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
    final tickY = chartArea.height - timeMs / msPerPx;
    canvas.drawLine(
      Offset(chartArea.left - yAxisTickWidth / 2, tickY),
      Offset(chartArea.left + yAxisTickWidth / 2, tickY),
      Paint()..color = colorScheme.chartAccentColor,
    );

    // Paint the axis label.
    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          color: colorScheme.chartSubtleColor,
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
        chartArea.height -
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
    @required this.displayRefreshRate,
    @required this.msPerPx,
    @required this.themeData,
  });

  static const fpsTextSpace = 45.0;

  final BoxConstraints constraints;

  final double displayRefreshRate;

  final double msPerPx;

  final ThemeData themeData;

  ColorScheme get colorScheme => themeData.colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    // The absolute coordinates of the chart's visible area.
    final chartArea = Rect.fromLTWH(
      _FlutterFramesChartState.yAxisUnitsSpace,
      0.0,
      constraints.maxWidth - _FlutterFramesChartState.yAxisUnitsSpace,
      constraints.maxHeight - defaultScrollBarOffset,
    );

    // Max FPS non-jank value in ms. E.g., 16.6 for 60 FPS, 8.3 for 120 FPS.
    final targetMsPerFrame = 1000 / displayRefreshRate;
    final targetLineY = chartArea.height - targetMsPerFrame / msPerPx;

    canvas.drawLine(
      Offset(chartArea.left, targetLineY),
      Offset(chartArea.right, targetLineY),
      Paint()..color = colorScheme.chartAccentColor,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${displayRefreshRate.toStringAsFixed(0)} FPS',
        style: TextStyle(
          color: colorScheme.chartSubtleColor,
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
