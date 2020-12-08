// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../auto_dispose_mixin.dart';
import '../config_specific/logger/logger.dart' as logger;
import 'chart_controller.dart';
import 'chart_trace.dart';

typedef DrawCodeCallback = void Function(Canvas canvas);

/// Perform some draw operations on a canvas after applying translate.
///
/// This helper function performs basic booking for translate tasks:
///   1. save canvas state
///   2. translate coordinates
///   3. draw to the canvas with respect to translation coordinates
///   4. restore canvas state back to the saved state.
void drawTranslate(
  Canvas canvas,
  double x,
  double y,
  DrawCodeCallback drawCode,
) {
  canvas.save();
  canvas.translate(x, y);

  drawCode(canvas);

  canvas.restore();
}

class Chart extends StatefulWidget {
  Chart(
    this.controller, {
    String title,
  }) {
    controller.title = title;
  }

  final ChartController controller;

  @override
  ChartState createState() => ChartState();
}

class ChartState extends State<Chart> with AutoDisposeMixin {
  ChartState();

  ChartController get controller => widget.controller;

  /// Helper to hookup notifiers.
  void _initSetup() {
    addAutoDisposeListener(controller.traceChanged, () {
      setState(() {
        if (controller.isZoomAll) {
          controller.computeZoomRatio();
        }

        controller.computeChartArea();
      });
    });
  }

  @override
  void initState() {
    super.initState();

    _initSetup();
  }

  @override
  void didUpdateWidget(Chart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != controller) {
      _initSetup();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Chart's Custom Painter (paint) can be expensive for lots of data points (10,000s).
    // A repaint boundary is necessary.
    // TODO(terry): Optimize the 10,000s of data points to just the number of pixels in the
    //              chart - this will make paint very fast.
    return RepaintBoundary(
      child: LayoutBuilder(
        // Inner container
        builder: (_, constraints) => Container(
          width: constraints.widthConstraints().maxWidth,
          height: constraints.widthConstraints().maxHeight,
          child: CustomPaint(
            painter: ChartPainter(controller),
          ),
        ),
      ),
    );
  }
}

class Point {
  Point(this.x, this.y);

  final double x;
  final double y;
}

class ChartPainter extends CustomPainter {
  ChartPainter(this.chartController) {
//    marginTopY = createText(chartController.title, 1.5).height + paddingY;
  }

  final debugTrackPaintTime = false;

  final ChartController chartController;

  static const double axisWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    // TODO(terry): Used to monitor total painting time. For large
    //              datasets e.g., offline files of 10,000s of data
    //              points time can be kind of slows. Consider only
    //              sampling 1 point per horizontal pixel.
    final startTime = DateTime.now();

    final axis = Paint()
      ..strokeWidth = axisWidth
      ..color = Colors.grey;

    if (size != chartController.size) {
      chartController.size = size;
      chartController.computeChartArea();
    }

    drawTranslate(
      canvas,
      chartController.xCanvasChart,
      chartController.yCanvasChart,
      (canavas) {
        drawAxes(
          canvas,
          size,
          axis,
          displayX: chartController.displayXAxis,
          displayTopLine: chartController.displayTopLine,
        );
      },
    );

    final traces = chartController.traces;
    final tracesDataIndex = List<int>.generate(
      traces.length,
      (int index) {
        final length = traces[index].data.length;
        return length > 0 ? length - 1 : -1;
      },
    );

    /// Key is trace index and value is x,y point.
    final previousTracesData = <int, Point>{};

    /// Key is trace index and value is x,y point.
    final currentTracesData = <int, Point>{};

    // Visible Y max.
    var visibleYMax = 0.0;

    // TODO(terry): Need to compute x-axis left-most position for last timestamp.
    //              May need to do the other direction so it looks better.
    final endVisibleIndex =
        chartController.timestampsLength - chartController.visibleTicks;

    final xTranslation = chartController.xCoordLeftMostVisibleTimestamp;
    final yTranslation = chartController.zeroYPosition;

    int xTickIndex = chartController.timestampsLength;
    while (--xTickIndex >= 0) {
      final currentTimestamp = chartController.timestamps[xTickIndex];

      if (xTickIndex < endVisibleIndex) {
        // Once outside of visible range of data skip the rest of the collected data.
        break;
      }

      final tracesLength = traces.length;

      // Short-circuit if no traceDataIndexes left (all are -1) then we're done.
      if (!tracesDataIndex.any((element) => element >= 0)) continue;

      // Remember old cliprect.
      canvas.save();

      // Clip to the just the area being plotted.  This is important so symbols
      // larger than the tick area doesn't spill out on the left-side.
      clipChart(canvas);

      for (var index = 0; index < tracesLength; index++) {
        final traceDataIndex = tracesDataIndex[index];
        if (traceDataIndex >= 0) {
          final trace = traces[index];
          final traceData = trace.data[traceDataIndex];
          final xTimestamp = traceData.timestamp;
          final xCanvasCoord =
              chartController.timestampXCanvasCoord(xTimestamp);
          if (currentTimestamp == xTimestamp) {
            if (xCanvasCoord != null) {
              // Get ready to render on canvas. Remember old canvas state
              // and setup translations for x,y coordinates into the rendering
              // area of the chart.
              drawTranslate(
                canvas,
                xTranslation,
                yTranslation,
                (canvas) {
                  final xCoord = xCanvasCoord;
                  final yCoord =
                      chartController.yPositonToYCanvasCoord(traceData.y);

                  // Is the visible Y-axis max larger.
                  if (traceData.y > visibleYMax) {
                    visibleYMax = traceData.y;
                  }

                  currentTracesData[index] = Point(xCoord, yCoord);

                  if (trace.chartType == ChartType.symbol) {
                    drawCircle(canvas, trace.characteristics, xCoord, yCoord);
                  } else if (trace.chartType == ChartType.line) {
                    if (trace.characteristics.symbol ==
                        ChartSymbol.dashedLine) {
                      // TODO(terry): Collect all points and draw a dashed line using
                      // path_drawing package.
                      drawDashed(
                        canvas,
                        trace.characteristics,
                        xCoord,
                        yCoord,
                        chartController.tickWidth - 4,
                      );
                    } else if (previousTracesData[index] != null) {
                      // Stacked lines.
                      // Drawline from previous plotted point to new point.
                      drawConnectedLine(
                        canvas,
                        trace.characteristics,
                        xCoord,
                        yCoord,
                        previousTracesData[index].x,
                        previousTracesData[index].y,
                      );
                      drawCircle(canvas, trace.characteristics, xCoord, yCoord);

                      // TODO(terry): Honor z-order and also maybe path just on the traces e.g.,
                      //              fill from top of trace 0 to top of trace 1 don't origin
                      //              from zero.
                      // Fill area between traces.
                      drawFillArea(
                        canvas,
                        trace.characteristics,
                        previousTracesData[index].x,
                        previousTracesData[index].y,
                        chartController.yPositonToYCanvasCoord(0),
                        currentTracesData[index].x,
                        currentTracesData[index].y,
                        chartController.yPositonToYCanvasCoord(0),
                      );
                    } else {
                      // Draw point
                      drawCircle(canvas, trace.characteristics, xCoord, yCoord);
                    }
                  }
                  tracesDataIndex[index]--;
                },
              );
            }
          }
        }

        previousTracesData.addAll(currentTracesData);
        currentTracesData.clear();
      }

      // Undo the clipRect at beginning of for loop.
      canvas.restore();
    }

    chartController.computeChartArea();
    chartController.buildLabelTimestamps();

    if (chartController.displayXAxis || chartController.displayXLabels) {
      // Y translation is below X-axis line.
      drawTranslate(
        canvas,
        xTranslation,
        chartController.zeroYPosition + 1,
        (canvas) {
          // Draw the X-axis labels.
          for (var timestamp in chartController.labelTimestamps) {
            final xCoord = chartController.timestampXCanvasCoord(timestamp);
            drawXTick(canvas, timestamp, xCoord, axis, displayTime: true);
          }
        },
      );

      // X translation is left-most edge of chart widget.
      drawTranslate(
        canvas,
        chartController.xCanvasChart,
        yTranslation,
        (canvas) {
          // Rescale Y-axis to max visible Y range.
          chartController.resetYMaxValue(visibleYMax);

          // Draw Y-axis ticks and labels.
          // TODO(terry): Optimization add a listener for Y-axis range changing
          //              only need to redraw Y-axis if the range changed.
          if (chartController.displayYLabels) {
            drawYTicks(canvas, chartController, axis);
          }
        },
      );
    }

    drawTitle(canvas, size, chartController.title);

    final elapsedTime = DateTime.now().difference(startTime).inMilliseconds;
    if (debugTrackPaintTime && elapsedTime > 500) {
      logger.log('${chartController.name} ${chartController.timestampsLength} '
          'CustomPainter paint elapsed time $elapsedTime');
    }

    // Once painted we're not dirty anymore.
    chartController.dirty = false;
  }

  void clipChart(Canvas canvas, {ClipOp op = ClipOp.intersect}) {
    final leftSideSide = chartController.xCanvasChart;
    final topChartSide = chartController.yCanvasChart;
    final r = Rect.fromLTRB(
      leftSideSide,
      topChartSide,
      chartController.canvasChartWidth +
          leftSideSide -
          chartController.xPaddingRight,
      topChartSide + chartController.canvasChartHeight,
    );

    canvas.clipRect(r, clipOp: op);
  }

  // TODO(terry): Use drawText?
  void drawTitle(Canvas canvas, Size size, String title) {
    final tp = createText(title, 1.5);
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, 0));
  }

  void drawAxes(
    Canvas canvas,
    Size size,
    Paint axis, {
    bool displayX = true,
    bool displayY = true,
    bool displayTopLine = true,
  }) {
    final chartWidthPosition =
        chartController.canvasChartWidth - chartController.xPaddingRight;
    final chartHeight = chartController.canvasChartHeight;

    // Top line of chart.
    if (displayTopLine) {
      canvas.drawLine(const Offset(0, 0), Offset(chartWidthPosition, 0), axis);
    }

    // Left-side of chart
    if (displayY) {
      canvas.drawLine(
        const Offset(0, 0),
        Offset(0, chartHeight),
        axis,
      );
    }

    // Bottom line of chart.
    if (displayX) {
      canvas.drawLine(
        Offset(0, chartHeight),
        Offset(chartWidthPosition, chartHeight),
        axis,
      );
    }
  }

  /// Separated out from drawAxis because we don't know range until plotted.
  void drawYTicks(Canvas canvas, ChartController chartController, Paint axis) {
    final yScale = chartController.yScale;

    for (var labelIndex = yScale.labelTicks; labelIndex >= 0; labelIndex--) {
      final unit = pow(10, yScale?.labelUnitExponent).floor();
      final y = labelIndex * unit;
      // Need to be zero based
      final yCoord = chartController.yPositonToYCanvasCoord(y);

      final labelName = constructLabel(
        labelIndex.floor(),
        yScale.labelUnitExponent.floor(),
      );

      // Label starts at left edge.
      drawText(labelName, canvas, -chartController.xCanvasChart / 2, yCoord);

      // Draw horizontal tick 6 pixels from Y-axis line.
      canvas.drawLine(
        Offset(0, yCoord),
        Offset(-6, yCoord),
        axis,
      );
    }
  }

  /// Return Y axis labels using the exponent to signal unit type and the
  /// label value e.g.
  static String constructLabel(int labelValue, int unitExponent) {
    var unit = '';
    switch (unitExponent) {
      case 0:
      case 1:
      case 2:
      case 3:
        labelValue = labelValue * pow(10, unitExponent);
        break;
      // Return units in K e.g., 10K, 80K, 100K, 700K, etc.
      // Notice that anything < 10K will return as 500, 2050, 5000, 9000, etc.
      case 4:
      case 5:
        labelValue = labelValue * pow(10, unitExponent - 4);
        unit = 'K';
        break;
      // Return units in M e.g., 1M, 8M, 10M, 30M, 100M, 400M, etc.
      case 6:
      case 7:
      case 8:
        labelValue = labelValue * pow(10, unitExponent - 6);
        unit = 'M';
        break;
      // Return units in B e.g., 1B, 7B, 10B, 50B, 100B, 900B, etc.
      case 9:
      case 10:
      case 11:
        labelValue = labelValue * pow(10, unitExponent - 9);
        unit = 'B';
        break;
      // Return units in T e.g., 1T, 5T, 10T, 40T, 100T, 300T, etc.
      case 12:
      case 13:
      case 14:
        labelValue = labelValue * pow(10, unitExponent - 12);
        unit = 'T';
        break;
      default:
        unit = 'e+$unitExponent';
    }

    final label = labelValue.toInt();
    return label == 0 ? '0' : '$label$unit';
  }

  void drawXTick(
    Canvas canvas,
    int timestamp,
    double xTickCoord,
    Paint axis, {
    shortTick = true,
    displayTime = false,
  }) {
    if (displayTime) {
      // Draw vertical tick (short or long).
      canvas.drawLine(
        Offset(xTickCoord, 0),
        Offset(xTickCoord, shortTick ? 2 : 6),
        axis,
      );

      final tp = createText(prettyTimestamp(timestamp), 1);
      tp.paint(
        canvas,
        Offset(
          xTickCoord - tp.width ~/ 2,
          15.0 - tp.height ~/ 2,
        ),
      );
    }
  }

  void drawText(String textValue, Canvas canvas, double x, double y) {
    final tp = createText(textValue, 1);
    tp.paint(canvas, Offset(x + -tp.width / 2, y - tp.height / 2));
  }

  TextPainter createText(String textValue, double scale) {
    const TextStyle(
      color: Colors.black,
      fontSize: 30,
    );
    final span = TextSpan(
      // TODO(terry): All text in a chart is grey. A chart like a Trace
      //              should have PaintCharacteristics.
      style: TextStyle(color: Colors.grey[600], fontSize: 10),
      text: textValue,
    );
    final tp = TextPainter(
      text: span,
      textAlign: TextAlign.right,
      textScaleFactor: scale,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    return tp;
  }

  void drawCircle(
    Canvas canvas,
    PaintCharacteristics characteristics,
    double x,
    double y,
  ) {
    final paint = Paint()
      ..style = characteristics.symbol == ChartSymbol.disc
          ? PaintingStyle.fill
          : PaintingStyle.stroke
      ..strokeWidth = characteristics.strokeWidth
      ..color = characteristics.color;

    canvas.drawCircle(Offset(x, y), characteristics.diameter, paint);
  }

  // TODO(terry): Use bezier path.
  void drawDashed(Canvas canvas, PaintCharacteristics characteristics, double x,
      double y, double tickWidth) {
    assert(characteristics.symbol == ChartSymbol.dashedLine);
    drawLine(
      canvas,
      characteristics,
      x,
      y,
      tickWidth,
    );
  }

  void drawConnectedLine(
    Canvas canvas,
    PaintCharacteristics characteristics,
    double startX,
    double startY,
    double endX,
    double endY,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = characteristics.strokeWidth
      ..color = characteristics.color;

    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
  }

  void drawLine(
    Canvas canvas,
    PaintCharacteristics characteristics,
    double x,
    double y,
    double tickWidth,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = characteristics.strokeWidth
      ..color = characteristics.color;

    canvas.drawLine(Offset(x, y), Offset(x + tickWidth, y), paint);
  }

  /// Used to fill in the area for a tick from X-coordinate 0 to the tick's
  /// Y-coordinate with the current tick's width.
  void drawFillArea(
    Canvas canvas,
    PaintCharacteristics characteristics,
    double x0,
    double y0,
    double y0Bottom,
    double x1,
    double y1,
    double y1Bottom,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = characteristics.strokeWidth
      ..color = characteristics.color.withAlpha(140);

    final fillArea = Path()
      ..moveTo(x0, y0Bottom)
      ..lineTo(x0, y0)
      ..lineTo(x1, y1)
      ..lineTo(x1, y1Bottom)
      ..lineTo(x0, y0Bottom);
    fillArea.close();
    canvas.drawPath(fillArea, paint);

    fillArea.reset();
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) => chartController.isDirty;

  Data _reduceHelper(Data curr, Data next) => curr.y > next.y ? curr : next;

  /// Return the largest Y value in a particular trace if traceIndex is passed or
  /// all traces if traceIndex is not passed in.
  double maxValue({int traceIndex}) {
    var maxValue = 0.0;
    if (traceIndex == null) {
      for (var index = 0; index < chartController.traces.length; index++) {
        final trace = chartController.traces[index];
        final traceMax = trace.data.reduce(_reduceHelper).y;
        maxValue = max(maxValue, traceMax);
      }
    } else {
      final trace = chartController.traces[traceIndex];
      maxValue =
          trace.data.reduce((curr, next) => curr.y > next.y ? curr : next).y;
    }

    return maxValue;
  }
}
