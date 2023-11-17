// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../../framework/scaffold.dart';
import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/analytics/metrics.dart';
import '../../../../shared/banner_messages.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/utils.dart';
import '../../../../shared/ui/colors.dart';
import '../../../../shared/ui/hover.dart';
import '../../../../shared/ui/utils.dart';
import '../../performance_screen.dart';
import '../../performance_utils.dart';
import 'flutter_frame_model.dart';
import 'flutter_frames_controller.dart';

// Turn this flag on to see when flutter frames are linked with timeline events.
bool debugFrames = false;

class FlutterFramesChart extends StatelessWidget {
  const FlutterFramesChart(
    this.framesController, {
    super.key,
    required this.offlineMode,
    required this.impellerEnabled,
  });

  final FlutterFramesController framesController;

  final bool offlineMode;

  final bool impellerEnabled;

  @override
  Widget build(BuildContext context) {
    return MultiValueListenableBuilder(
      listenables: [
        framesController.flutterFrames,
        framesController.displayRefreshRate,
        preferences.performance.showFlutterFramesChart,
      ],
      builder: (context, values, child) {
        final frames = values.first as List<FlutterFrame>;
        final displayRefreshRate = values.second as double;
        final showChart = values.third as bool;
        return _FlutterFramesChart(
          framesController: framesController,
          frames: frames,
          displayRefreshRate: displayRefreshRate,
          isVisible: showChart,
          offlineMode: offlineMode,
          impellerEnabled: impellerEnabled,
        );
      },
    );
  }
}

class _FlutterFramesChart extends StatefulWidget {
  const _FlutterFramesChart({
    required this.framesController,
    required this.frames,
    required this.displayRefreshRate,
    required this.isVisible,
    required this.offlineMode,
    required this.impellerEnabled,
  });

  final FlutterFramesController framesController;

  final List<FlutterFrame> frames;

  final double displayRefreshRate;

  final bool isVisible;

  final bool offlineMode;

  final bool impellerEnabled;

  static double get frameNumberSectionHeight => scaleByFontFactor(20.0);

  static double get frameChartScrollbarOffset => defaultScrollBarOffset;

  @override
  _FlutterFramesChartState createState() => _FlutterFramesChartState();
}

class _FlutterFramesChartState extends State<_FlutterFramesChart> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeShowShaderJankMessage();
  }

  @override
  void didUpdateWidget(_FlutterFramesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      bannerMessages.addMessage(
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
  Widget build(BuildContext context) {
    // TODO(https://github.com/flutter/devtools/issues/4576): animate showing
    // and hiding the chart.
    if (!widget.isVisible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(
        left: denseSpacing,
        right: denseSpacing,
        bottom: denseSpacing,
      ),
      height: defaultChartHeight +
          _FlutterFramesChart.frameNumberSectionHeight +
          _FlutterFramesChart.frameChartScrollbarOffset,
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FramesChart(
                  framesController: widget.framesController,
                  frames: widget.frames,
                  displayRefreshRate: widget.displayRefreshRate,
                  constraints: constraints,
                  impellerEnabled: widget.impellerEnabled,
                );
              },
            ),
          ),
          const SizedBox(width: defaultSpacing),
          Padding(
            padding: EdgeInsets.only(
              bottom: _FlutterFramesChart.frameChartScrollbarOffset,
            ),
            child: FramesChartControls(
              framesController: widget.framesController,
              frames: widget.frames,
              displayRefreshRate: widget.displayRefreshRate,
              offlineMode: widget.offlineMode,
            ),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
class FramesChart extends StatefulWidget {
  const FramesChart({
    super.key,
    required this.framesController,
    required this.frames,
    required this.displayRefreshRate,
    required this.constraints,
    required this.impellerEnabled,
  });

  final FlutterFramesController framesController;

  final List<FlutterFrame> frames;

  final double displayRefreshRate;

  final BoxConstraints constraints;

  final bool impellerEnabled;

  @override
  State<FramesChart> createState() => _FramesChartState();
}

class _FramesChartState extends State<FramesChart> with AutoDisposeMixin {
  static const _defaultFrameWidthWithPadding =
      FlutterFramesChartItem.defaultFrameWidth + densePadding * 2;

  static const _outlineBorderWidth = 1.0;

  double get _yAxisUnitsSpace => scaleByFontFactor(48.0);

  late final ScrollController _framesScrollController;

  FlutterFrame? _selectedFrame;

  int? _selectedFrameIndex;

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

    cancelListeners();
    _selectedFrame = widget.framesController.selectedFrame.value;
    if (_selectedFrame != null) {
      _selectedFrameIndex = widget.frames.indexOf(_selectedFrame!);
    }
    addAutoDisposeListener(widget.framesController.selectedFrame, () {
      setState(() {
        _selectedFrame = widget.framesController.selectedFrame.value;
      });
    });

    final initialScrollOffset = _calculateInitialHorizontalScrollOffset();
    _framesScrollController = ScrollController(
      initialScrollOffset: initialScrollOffset,
    );
  }

  @override
  void didUpdateWidget(FramesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_framesScrollController.hasClients &&
        _framesScrollController.atScrollBottom) {
      unawaited(_framesScrollController.autoScrollToBottom());
    }
  }

  double _calculateInitialHorizontalScrollOffset() {
    final selectedIndex = _selectedFrameIndex;
    if (selectedIndex == null) return 0.0;

    final chartWidthWithoutAxisLabels =
        widget.constraints.maxWidth - _yAxisUnitsSpace;
    final totalFramesInView =
        chartWidthWithoutAxisLabels ~/ _defaultFrameWidthWithPadding;
    final fullFrameRangeInView = Range(0, totalFramesInView);

    if (fullFrameRangeInView.contains(selectedIndex)) return 0.0;

    return math.max(
      0.0,
      (selectedIndex - totalFramesInView / 2) * _defaultFrameWidthWithPadding,
    );
  }

  @override
  void dispose() {
    _framesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final chart = Scrollbar(
      thumbVisibility: true,
      controller: _framesScrollController,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: _FlutterFramesChart.frameChartScrollbarOffset,
        ),
        child: RoundedOutlinedBorder(
          child: ListView.builder(
            controller: _framesScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: widget.frames.length,
            itemExtent: _defaultFrameWidthWithPadding,
            itemBuilder: (context, index) => FlutterFramesChartItem(
              framesController: widget.framesController,
              index: index,
              frame: widget.frames[index],
              selected: widget.frames[index] == _selectedFrame,
              msPerPx: _msPerPx,
              availableChartHeight:
                  defaultChartHeight - 2 * _outlineBorderWidth,
              displayRefreshRate: widget.displayRefreshRate,
              onSelected: (index) => _selectedFrameIndex = index,
            ),
          ),
        ),
      ),
    );
    final chartAxisPainter = CustomPaint(
      painter: ChartAxisPainter(
        constraints: widget.constraints,
        yAxisUnitsSpace: _yAxisUnitsSpace,
        displayRefreshRate: widget.displayRefreshRate,
        msPerPx: _msPerPx,
        themeData: themeData,
        bottomMargin: _FlutterFramesChart.frameChartScrollbarOffset +
            _FlutterFramesChart.frameNumberSectionHeight,
      ),
    );
    final fpsLinePainter = CustomPaint(
      painter: FPSLinePainter(
        constraints: widget.constraints,
        yAxisUnitsSpace: _yAxisUnitsSpace,
        displayRefreshRate: widget.displayRefreshRate,
        msPerPx: _msPerPx,
        themeData: themeData,
        bottomMargin: _FlutterFramesChart.frameChartScrollbarOffset +
            _FlutterFramesChart.frameNumberSectionHeight,
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
        Positioned(
          right: denseSpacing,
          top: densePadding,
          child: Text(
            'Engine: ${widget.impellerEnabled ? 'Impeler' : 'Skia'}',
            style: themeData.subtleChartTextStyle,
          ),
        ),
      ],
    );
  }
}

@visibleForTesting
class FramesChartControls extends StatelessWidget {
  const FramesChartControls({
    super.key,
    required this.framesController,
    required this.frames,
    required this.displayRefreshRate,
    required this.offlineMode,
  });

  static const _pauseTooltip = 'Pause Flutter frame recording';

  static const _resumeTooltip = 'Resume Flutter frame recording';

  final FlutterFramesController framesController;

  final List<FlutterFrame> frames;

  final double displayRefreshRate;

  final bool offlineMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!offlineMode)
          ValueListenableBuilder<bool>(
            valueListenable: framesController.recordingFrames,
            builder: (context, recording, child) {
              return PauseResumeButtonGroup(
                paused: !recording,
                onPause: _pauseFrameRecording,
                onResume: _resumeFrameRecording,
                pauseTooltip: _pauseTooltip,
                resumeTooltip: _resumeTooltip,
                gaScreen: gac.performance,
                gaSelectionPause: gac.pause,
                gaSelectionResume: gac.resume,
              );
            },
          ),
        Legend(
          dense: true,
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
        AverageFPS(
          frames: frames,
          displayRefreshRate: displayRefreshRate,
        ),
      ],
    );
  }

  void _pauseFrameRecording() {
    ga.select(gac.performance, gac.pause);
    framesController.toggleRecordingFrames(false);
  }

  void _resumeFrameRecording() {
    ga.select(gac.performance, gac.resume);
    framesController.toggleRecordingFrames(true);
  }
}

class FlutterFramesChartItem extends StatelessWidget {
  const FlutterFramesChartItem({
    super.key,
    required this.index,
    required this.framesController,
    required this.frame,
    required this.selected,
    required this.msPerPx,
    required this.availableChartHeight,
    required this.displayRefreshRate,
    this.onSelected,
  });

  static const defaultFrameWidth = 28.0;

  static const selectedIndicatorHeight = 8.0;

  static const selectedFrameIndicatorKey =
      Key('flutter frames chart - selected frame indicator');

  final FlutterFramesController framesController;

  final int index;

  final FlutterFrame frame;

  final bool selected;

  final double msPerPx;

  final double availableChartHeight;

  final double displayRefreshRate;

  final void Function(int)? onSelected;

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
        uiColor = uiColor.darken(0.5);
      }
      if (frame.timelineEventData.rasterEvent == null) {
        rasterColor = rasterColor.darken(0.5);
        shaderColor = shaderColor.darken(0.5);
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

    final shaderDuration = frame.shaderDuration.inMilliseconds;
    final rasterTime = frame.rasterTime.inMilliseconds;
    final shaderToRasterRatio = shaderDuration / rasterTime;

    final raster = Column(
      children: [
        Container(
          key: Key('frame ${frame.id} - raster'),
          width: defaultFrameWidth / 2,
          height: ((frame.rasterTime.inMilliseconds - shaderDuration) / msPerPx)
              .clamp(0.0, availableChartHeight * (1 - shaderToRasterRatio)),
          color: rasterColor,
        ),
        if (frame.hasShaderTime)
          Container(
            key: Key('frame ${frame.id} - shaders'),
            width: defaultFrameWidth / 2,
            height: (shaderDuration / msPerPx)
                .clamp(0.0, availableChartHeight * shaderToRasterRatio),
            color: shaderColor,
          ),
      ],
    );

    final content = Padding(
      padding: EdgeInsets.only(
        bottom: _FlutterFramesChart.frameNumberSectionHeight,
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
                color: colorScheme.primary,
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
                height: _FlutterFramesChart.frameNumberSectionHeight,
                alignment: AlignmentDirectional.center,
                child: Text(
                  '${frame.id}',
                  style: themeData.subtleChartTextStyle,
                ),
              ),
            ],
          )
        : content;
  }

  void _selectFrame() {
    if (frame != framesController.selectedFrame.value) {
      // TODO(kenz): the shader time could be missing here if a frame is
      // selected before timeline events are associated with the
      // FlutterFrame. If this is the case, process the analytics call once
      // the frame's timeline events are available.
      ga.select(
        gac.performance,
        gac.PerformanceEvents.selectFlutterFrame.name,
        screenMetricsProvider: () => PerformanceScreenMetrics(
          uiDuration: frame.buildTime,
          rasterDuration: frame.rasterTime,
          shaderCompilationDuration: frame.shaderDuration,
        ),
      );
    }
    framesController.handleSelectedFrame(frame);
    onSelected?.call(index);
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

  static const double _moreInfoLinkWidth = 100.0;

  static const _textMeasurementBuffer = 8.0;

  @override
  Widget build(BuildContext context) {
    return HoverCardTooltip.sync(
      enabled: () => true,
      generateHoverCardData: (_) => _buildCardData(),
      child: child,
    );
  }

  HoverCardData _buildCardData() {
    final uiText = 'UI: ${durationText(
      frame.buildTime,
      unit: DurationDisplayUnit.milliseconds,
      allowRoundingToZero: false,
    )}';
    final rasterText = 'Raster: ${durationText(
      frame.rasterTime,
      unit: DurationDisplayUnit.milliseconds,
      allowRoundingToZero: false,
    )}';
    final shaderText = hasShaderJank
        ? 'Shader Compilation: ${durationText(
            frame.shaderDuration,
            unit: DurationDisplayUnit.milliseconds,
            allowRoundingToZero: false,
          )}  -'
        : '';
    return HoverCardData(
      position: HoverCardPosition.element,
      width: _calculateTooltipWidth([uiText, rasterText, shaderText]),
      contents: Material(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(uiText),
            const SizedBox(height: densePadding),
            Text(rasterText),
            if (hasShaderJank)
              Row(
                children: [
                  const Icon(
                    Icons.subdirectory_arrow_right,
                    size: defaultIconSizeBeforeScaling,
                  ),
                  Text(shaderText),
                  MoreInfoLink(
                    url: preCompileShadersDocsUrl,
                    gaScreenName: gac.performance,
                    gaSelectedItemDescription: gac
                        .PerformanceDocs.shaderCompilationDocsTooltipLink.name,
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
  const AverageFPS({
    super.key,
    required this.frames,
    required this.displayRefreshRate,
  });

  final List<FlutterFrame> frames;

  final double displayRefreshRate;

  @override
  Widget build(BuildContext context) {
    late String fpsText;
    if (frames.isEmpty) {
      fpsText = '--';
    } else {
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
      fpsText = '$avgFps';
    }
    return Text(
      '$fpsText FPS (average)',
      maxLines: 2,
      style: Theme.of(context).legendTextStyle,
    );
  }
}

class ShaderJankWarningIcon extends StatelessWidget {
  const ShaderJankWarningIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
    final labelText = durationText(
      Duration(milliseconds: timeMs),
      unit: DurationDisplayUnit.milliseconds,
      fractionDigits: 0,
    );

    // Paint a tick on the axis.
    final tickY = chartArea.height - timeMs / msPerPx;

    // Do not draw the y axis label if it will collide with the 0.0 label or if
    // it will go beyond the uper bound of the chart.
    if (timeMs != 0 && (tickY > chartArea.height - 10.0 || tickY < 10.0)) {
      return;
    }

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
