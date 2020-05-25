// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/common_widgets.dart' show ScrollControllerAutoScroll;
import '../../flutter/theme.dart';
import '../../ui/colors.dart';
import '../../utils.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';

class FlutterFramesChart extends StatefulWidget {
  const FlutterFramesChart(
    this.frames,
    this.longestFrameDurationMs,
    this.displayRefreshRate,
  );

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

  static const defaultFrameWidth = 32.0;
  static const defaultFrameWidthWithPadding =
      defaultFrameWidth + densePadding * 2;

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
          ),
        );
        final fpsLinePainter = CustomPaint(
          painter: FPSLinePainter(
            constraints: constraints,
            totalWidth: totalChartWidth,
            displayRefreshRate: widget.displayRefreshRate,
            msPerPx: msPerPx,
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

  // TODO(kenz): add some indicator when a frame is so janky that it exceeds the
  // available axis space.
  Widget _buildFrame(TimelineFrame frame) {
    final selected = frame == _selectedFrame;
    final janky = _isFrameJanky(frame);

    Color uiColor() {
      if (selected) return selectedFlutterFrameUiColor;
      if (janky) return uiJankColor;
      return mainUiColor;
    }

    Color rasterColor() {
      if (selected) return selectedFlutterFrameRasterColor;
      if (janky) return rasterJankColor;
      return mainRasterColor;
    }

    final ui = Container(
      width: defaultFrameWidth / 2,
      height: (frame.uiDurationMs / msPerPx).clamp(0.0, availableChartHeight),
      color: uiColor(),
    );
    final raster = Container(
      width: defaultFrameWidth / 2,
      height:
          (frame.rasterDurationMs / msPerPx).clamp(0.0, availableChartHeight),
      color: rasterColor(),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: densePadding),
      child: Column(
        children: [
          // Dummy child so that the InkWell does not take up the entire column.
          const Expanded(child: SizedBox()),
          InkWell(
            // TODO(kenz): make tooltip to persist if the frame is selected.
            // TODO(kenz): change color on hover.
            onTap: () => _controller.selectFrame(frame),
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

  Widget _buildChartLegend() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legendItem('UI (Dart)', mainUiColor),
        _legendItem('Raster (Flutter Engine)', mainRasterColor),
        _legendItem('Jank (slow frame)', uiJankColor),
        _legendItem('Selected frame', selectedFlutterFrameUiColor),
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

  String _tooltipText(TimelineFrame frame) {
    return 'UI: ${msText(frame.uiEventFlow.time.duration)}\n'
        'Raster: ${msText(frame.rasterEventFlow.time.duration)}';
  }

  bool _isFrameJanky(TimelineFrame frame) {
    final targetMsPerFrame = 1 / widget.displayRefreshRate * 1000;
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
  });

  final BoxConstraints constraints;

  final double totalWidth;

  final double displayRefreshRate;

  final double msPerPx;

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

    const yAxisTickWidth = 8.0;
    const yAxisLabelCount = 6;
    final totalMs = msPerPx * constraints.maxHeight;
    // Subtract 1 because one of the labels will be 0.0 ms.
    final timeUnitMs = totalMs ~/ (yAxisLabelCount - 1);
    for (int i = 0; i < yAxisLabelCount; i++) {
      final labelMs = i * timeUnitMs;
      final labelText = msText(
        Duration(milliseconds: labelMs),
        fractionDigits: 0,
      );

      // Paint a tick on the axis.
      final tickY = constraints.maxHeight - labelMs / msPerPx;
      canvas.drawLine(
        Offset(chartArea.left - yAxisTickWidth / 2, tickY),
        Offset(chartArea.left + yAxisTickWidth / 2, tickY),
        Paint()..color = chartAccentColor,
      );

      // Paint the axis label.
      final textPainter = TextPainter(
        text: TextSpan(text: labelText),
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          0.0,
          constraints.maxHeight - labelMs / msPerPx - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(ChartAxisPainter oldDelegate) {
    return false;
  }
}

class FPSLinePainter extends CustomPainter {
  FPSLinePainter({
    @required this.constraints,
    @required this.totalWidth,
    @required this.displayRefreshRate,
    @required this.msPerPx,
  });

  static const fpsLineColor = Color.fromARGB(0x80, 0xff, 0x44, 0x44);

  static const fpsTextSpace = 60.0;

  final BoxConstraints constraints;

  final double totalWidth;

  final double displayRefreshRate;

  final double msPerPx;

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
      Offset(chartArea.right - fpsTextSpace, targetLineY),
      Paint()
        ..color = fpsLineColor
        ..strokeWidth = 2.0,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: '${displayRefreshRate.toStringAsFixed(0)} FPS'),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        chartArea.right - fpsTextSpace + denseSpacing,
        targetLineY - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
