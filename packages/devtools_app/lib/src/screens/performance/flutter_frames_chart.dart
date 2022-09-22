// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../framework/scaffold.dart';
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/colors.dart';
import '../../ui/hover.dart';
import '../../ui/utils.dart';
import 'performance_controller.dart';
import 'performance_model.dart';
import 'performance_screen.dart';
import 'performance_utils.dart';

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
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<PerformanceController, FlutterFramesChart> {
  static const _defaultFrameWidthWithPadding =
      FlutterFramesChartItem.defaultFrameWidth + densePadding * 2;

  static const _outlineBorderWidth = 1.0;

  double get _yAxisUnitsSpace => scaleByFontFactor(48.0);

  static double get _frameNumberSectionHeight => scaleByFontFactor(20.0);

  double get _frameChartScrollbarOffset => defaultScrollBarOffset;

  late final ScrollController _framesScrollController;

  FlutterFrame? _selectedFrame;

  /// Milliseconds per pixel value for the y-axis.
  ///
  /// This value will result in a y-axis time range spanning two times the
  /// target frame time for a single frame (e.g. 16.6 * 2 for a 60 FPS device).
  double get _msPerPx =>
      // Multiply by two to reach two times the target frame time.
      1 / widget.displayRefreshRate * 1000 * 2 / defaultChartHeight;

  @override
  void initState() {
    super.initState();
    _framesScrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    cancelListeners();
    _selectedFrame = controller.selectedFrame.value;
    addAutoDisposeListener(controller.selectedFrame, () {
      setState(() {
        _selectedFrame = controller.selectedFrame.value;
      });
    });

    _maybeShowShaderJankMessage();
  }

  @override
  void didUpdateWidget(FlutterFramesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_framesScrollController.hasClients &&
        _framesScrollController.atScrollBottom) {
      _framesScrollController.autoScrollToBottom();
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
          offlineController.offlineMode.value
              ? SimpleScreen.id
              : PerformanceScreen.id,
          jankyFramesCount: shaderJankFrames.length,
          jankDuration: shaderJankDuration,
        ).build(context),
      );
    }
  }

  @override
  void dispose() {
    _framesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        left: denseSpacing,
        right: denseSpacing,
        bottom: denseSpacing,
      ),
      height: defaultChartHeight +
          _frameNumberSectionHeight +
          _frameChartScrollbarOffset,
      child: Row(
        children: [
          Expanded(child: _buildChart()),
          const SizedBox(width: defaultSpacing),
          Padding(
            padding: EdgeInsets.only(bottom: _frameChartScrollbarOffset),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Legend(
                  key: FlutterFramesChart.chartLegendKey,
                  entries: [
                    const LegendEntry('Frame Time (UI)', mainUiColor),
                    const LegendEntry('Frame Time (Raster)', mainRasterColor),
                    const LegendEntry('Jank (slow frame)', uiJankColor),
                    LegendEntry(
                      'Shader Compilation',
                      shaderCompilationColor.background,
                    ),
                  ],
                ),
                if (widget.frames.isNotEmpty)
                  AverageFPS(
                    frames: widget.frames,
                    displayRefreshRate: widget.displayRefreshRate,
                  ),
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
          thumbVisibility: true,
          controller: _framesScrollController,
          child: Padding(
            padding: EdgeInsets.only(bottom: _frameChartScrollbarOffset),
            child: RoundedOutlinedBorder(
              child: ListView.builder(
                controller: _framesScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: widget.frames.length,
                itemExtent: _defaultFrameWidthWithPadding,
                itemBuilder: (context, index) => FlutterFramesChartItem(
                  controller: controller,
                  index: index,
                  frame: widget.frames[index],
                  selected: widget.frames[index] == _selectedFrame,
                  msPerPx: _msPerPx,
                  availableChartHeight:
                      defaultChartHeight - 2 * _outlineBorderWidth,
                  displayRefreshRate: widget.displayRefreshRate,
                ),
              ),
            ),
          ),
        );
        final chartAxisPainter = CustomPaint(
          painter: ChartAxisPainter(
            constraints: constraints,
            yAxisUnitsSpace: _yAxisUnitsSpace,
            displayRefreshRate: widget.displayRefreshRate,
            msPerPx: _msPerPx,
            themeData: themeData,
            bottomMargin:
                _frameChartScrollbarOffset + _frameNumberSectionHeight,
          ),
        );
        final fpsLinePainter = CustomPaint(
          painter: FPSLinePainter(
            constraints: constraints,
            yAxisUnitsSpace: _yAxisUnitsSpace,
            displayRefreshRate: widget.displayRefreshRate,
            msPerPx: _msPerPx,
            themeData: themeData,
            bottomMargin:
                _frameChartScrollbarOffset + _frameNumberSectionHeight,
          ),
        );
        return Stack(
          children: [
            chartAxisPainter,
            Padding(
              padding: EdgeInsets.only(left: _yAxisUnitsSpace),
              child: chart,
            ),
            fpsLinePainter,
          ],
        );
      },
    );
  }
}

class FlutterFramesChartItem extends StatelessWidget {
  const FlutterFramesChartItem({
    required this.index,
    required this.controller,
    required this.frame,
    required this.selected,
    required this.msPerPx,
    required this.availableChartHeight,
    required this.displayRefreshRate,
  });

  static const defaultFrameWidth = 28.0;

  static const selectedIndicatorHeight = 8.0;

  static const selectedFrameIndicatorKey =
      Key('flutter frames chart - selected frame indicator');

  final PerformanceController controller;

  final int index;

  final FlutterFrame frame;

  final bool selected;

  final double msPerPx;

  final double availableChartHeight;

  final double displayRefreshRate;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;

    final bool uiJanky = frame.isUiJanky(displayRefreshRate);
    final bool rasterJanky = frame.isRasterJanky(displayRefreshRate);
    final bool hasShaderJank = frame.hasShaderJank(displayRefreshRate);

    var uiColor = uiJanky ? uiJankColor : mainUiColor;
    var rasterColor = rasterJanky ? rasterJankColor : mainRasterColor;
    var shaderColor = shaderCompilationColor.background;

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

    final content = Padding(
      padding: EdgeInsets.only(
        bottom: _FlutterFramesChartState._frameNumberSectionHeight,
      ),
      child: InkWell(
        onTap: _selectFrame,
        child: Stack(
          children: [
            // TODO(kenz): make tooltip to persist if the frame is selected.
            FlutterFrameTooltip(
              frame: frame,
              hasShaderJank: hasShaderJank,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: densePadding),
                color:
                    selected ? colorScheme.selectedFrameBackgroundColor : null,
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
              const Padding(
                padding: EdgeInsets.only(
                  top: FlutterFramesChartItem.selectedIndicatorHeight,
                ),
                child: ShaderJankWarningIcon(),
              ),
          ],
        ),
      ),
    );
    return index % 2 == 0
        ? Stack(
            children: [
              content,
              Container(
                margin: EdgeInsets.only(top: defaultChartHeight),
                height: _FlutterFramesChartState._frameNumberSectionHeight,
                alignment: AlignmentDirectional.center,
                child: Text(
                  '${frame.id}',
                  style: themeData.subtleChartTextStyle,
                ),
              )
            ],
          )
        : content;
  }

  void _selectFrame() {
    if (frame != controller.selectedFrame.value) {
      // TODO(kenz): the shader time could be missing here if a frame is
      // selected before timeline events are associated with the
      // FlutterFrame. If this is the case, process the analytics call once
      // the frame's timeline events are available.
      ga.select(
        analytics_constants.performance,
        analytics_constants.selectFlutterFrame,
        screenMetricsProvider: () => PerformanceScreenMetrics(
          uiDuration: frame.buildTime,
          rasterDuration: frame.rasterTime,
          shaderCompilationDuration: frame.shaderDuration,
        ),
      );
    }
    controller.toggleSelectedFrame(frame);
  }
}

class FlutterFrameTooltip extends StatelessWidget {
  const FlutterFrameTooltip({
    Key? key,
    required this.child,
    required this.frame,
    required this.hasShaderJank,
  }) : super(key: key);

  final Widget child;

  final FlutterFrame frame;

  final bool hasShaderJank;

  static const double _moreInfoLinkWidth = 85.0;

  static const _textMeasurementBuffer = 4.0;

  @override
  Widget build(BuildContext context) {
    return HoverCardTooltip.sync(
      enabled: () => true,
      generateHoverCardData: (_) => _buildCardData(context),
      child: child,
    );
  }

  HoverCardData _buildCardData(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.toggleButtonsTitle;
    final textStyle = TextStyle(color: textColor);
    final uiText = 'UI: ${msText(frame.buildTime)}';
    final rasterText = 'Raster: ${msText(frame.rasterTime)}';
    final shaderText = hasShaderJank
        ? 'Shader Compilation: ${msText(frame.shaderDuration)}  -'
        : '';
    return HoverCardData(
      position: HoverCardPosition.element,
      width: _calculateTooltipWidth([uiText, rasterText, shaderText]),
      contents: Material(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uiText,
              style: textStyle,
            ),
            const SizedBox(height: densePadding),
            Text(
              rasterText,
              style: textStyle,
            ),
            if (hasShaderJank)
              Row(
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right,
                    color: textColor,
                    size: defaultIconSizeBeforeScaling,
                  ),
                  Text(
                    shaderText,
                    style: textStyle,
                  ),
                  const MoreInfoLink(
                    url: preCompileShadersDocsUrl,
                    gaScreenName: analytics_constants.performance,
                    gaSelectedItemDescription:
                        analytics_constants.shaderCompilationDocsTooltipLink,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  double _calculateTooltipWidth(List<String> lines) {
    var maxWidth = 0.0;
    for (final line in lines) {
      final lineWidth = calculateTextSpanWidth(TextSpan(text: line));
      maxWidth = math.max(maxWidth, lineWidth);
    }
    // Add (2 * denseSpacing) for the card padding, and add
    // [_textMeasurementBuffer] to account for slight variations in the measured
    // text vs text displayed.
    maxWidth += 2 * denseSpacing + _textMeasurementBuffer;
    if (hasShaderJank) {
      return maxWidth + defaultIconSizeBeforeScaling + _moreInfoLinkWidth;
    }
    return maxWidth;
  }
}

class AverageFPS extends StatelessWidget {
  const AverageFPS({required this.frames, required this.displayRefreshRate});

  final List<FlutterFrame> frames;

  final double displayRefreshRate;

  @override
  Widget build(BuildContext context) {
    final double sumFrameTimesMs = frames.fold(
      0.0,
      (sum, frame) =>
          sum +
          math.max(
            1000 / displayRefreshRate,
            math.max(
              frame.buildTime.inMilliseconds,
              frame.rasterTime.inMilliseconds,
            ),
          ),
    );
    final avgFrameTime = sumFrameTimesMs / frames.length;
    final avgFps = (1 / avgFrameTime * 1000).round();
    return Text(
      '$avgFps FPS (average)',
      maxLines: 2,
    );
  }
}

class ShaderJankWarningIcon extends StatelessWidget {
  const ShaderJankWarningIcon();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        BlinkingIcon(
          icon: Icons.warning_amber_rounded,
          color: Colors.amber,
          size: defaultActionsIconSizeBeforeScaling,
        ),
      ],
    );
  }
}

class ChartAxisPainter extends CustomPainter {
  ChartAxisPainter({
    required this.constraints,
    required this.yAxisUnitsSpace,
    required this.displayRefreshRate,
    required this.msPerPx,
    required this.themeData,
    required this.bottomMargin,
  });

  static const yAxisTickWidth = 8.0;

  final BoxConstraints constraints;

  final double yAxisUnitsSpace;

  final double displayRefreshRate;

  final double msPerPx;

  final ThemeData themeData;

  final double bottomMargin;

  @override
  void paint(Canvas canvas, Size size) {
    // The absolute coordinates of the chart's visible area.
    final chartArea = Rect.fromLTWH(
      yAxisUnitsSpace,
      0.0,
      constraints.maxWidth - yAxisUnitsSpace,
      constraints.maxHeight - bottomMargin,
    );

    _paintYAxisLabels(canvas, chartArea);
  }

  void _paintYAxisLabels(
    Canvas canvas,
    Rect chartArea,
  ) {
    const yAxisLabelCount = 5;
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
    required int timeMs,
  }) {
    final labelText = msText(
      Duration(milliseconds: timeMs),
      fractionDigits: 0,
    );

    // Paint a tick on the axis.
    final tickY = chartArea.height - timeMs / msPerPx;

    // Do not draw the y axis label if it will collide with the 0.0 label or if
    // it will go beyond the uper bound of the chart.
    if (timeMs != 0 && (tickY > chartArea.height - 10.0 || tickY < 10.0))
      return;

    canvas.drawLine(
      Offset(chartArea.left - yAxisTickWidth / 2, tickY),
      Offset(chartArea.left + yAxisTickWidth / 2, tickY),
      Paint()..color = themeData.colorScheme.chartAccentColor,
    );

    // Paint the axis label.
    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: themeData.subtleChartTextStyle,
      ),
      textAlign: TextAlign.end,
      textDirection: TextDirection.ltr,
    )..layout();

    const baselineAdjust = 2.0;

    textPainter.paint(
      canvas,
      Offset(
        yAxisUnitsSpace -
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
    required this.constraints,
    required this.yAxisUnitsSpace,
    required this.displayRefreshRate,
    required this.msPerPx,
    required this.themeData,
    required this.bottomMargin,
  });

  double get fpsTextSpace => scaleByFontFactor(45.0);

  final BoxConstraints constraints;

  final double yAxisUnitsSpace;

  final double displayRefreshRate;

  final double msPerPx;

  final ThemeData themeData;

  final double bottomMargin;

  @override
  void paint(Canvas canvas, Size size) {
    // The absolute coordinates of the chart's visible area.
    final chartArea = Rect.fromLTWH(
      yAxisUnitsSpace,
      0.0,
      constraints.maxWidth - yAxisUnitsSpace,
      constraints.maxHeight - bottomMargin,
    );

    // Max FPS non-jank value in ms. E.g., 16.6 for 60 FPS, 8.3 for 120 FPS.
    final targetMsPerFrame = 1000 / displayRefreshRate;
    final targetLineY = chartArea.height - targetMsPerFrame / msPerPx;

    canvas.drawLine(
      Offset(chartArea.left, targetLineY),
      Offset(chartArea.right, targetLineY),
      Paint()..color = themeData.colorScheme.chartAccentColor,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${displayRefreshRate.toStringAsFixed(0)} FPS',
        style: themeData.subtleChartTextStyle,
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
