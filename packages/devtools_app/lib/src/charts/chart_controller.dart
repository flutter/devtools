// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../auto_dispose.dart';

import 'chart_trace.dart';

/// Zoom level of chart
enum displayDuration { live, fiveMinutes, fifteenMinutes, all }

/// Given a durationLabel return the displayDuration.
displayDuration durationToDisplayDuration(
  displayDuration currentZoomDuration,
  Duration duration,
) {
  if (currentZoomDuration == displayDuration.live) {
    if (duration.inMinutes == 0 && duration.inSeconds >= 10) {
      return displayDuration.live;
    }
  } else if (currentZoomDuration == displayDuration.fifteenMinutes) {
    if (duration.inMinutes >= 5) {
      return displayDuration.fifteenMinutes;
    }
  } else if (currentZoomDuration == displayDuration.fiveMinutes) {
    if (duration.inMinutes == 3) {
      return displayDuration.fiveMinutes;
    }
  }

  return null;
}

String prettyTimestamp(int timestamp) {
  final timestampDT = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return intl.DateFormat.Hms().format(timestampDT); // HH:mm:ss
}

/// Indexes into xAxisLabeledTimestamps.
const leftLabelIndex = 0;
const centerLabelIndex = 1;
const rightLabelIndex = 2;

/*
                                          xPaddingRight
                                          |
      leftPadding          topPadding     |  rightPadding
      |                    |              |  |
    ==|====================|==============|==|=
    " |                    V              |  |
    " V ----------------------------------V  V
    "   |
    "   |
    "   |
    "   | ------ canvasChartWidth --------
    "   |
    "   |
    "   ---------------------------------- <----- yCanvasChart
    "   '  '  '  '  '  '  '  '  '  '  '  '    {-------- bottomPadding
    "   ^                ^                     \
    ====|================|======================
        |                |
        xCanvasChart     X-axis ticks

*/
class ChartController extends DisposableController
    with AutoDisposeControllerMixin {
  ChartController({
    this.displayXLabels = true,
    this.displayYLabels = true,
  });

  // Total size of area to display the chart (includes title, axis, labels, etc.).
  Size size;

  // TODO(terry): Compute dynamically based on title text height.
  final topPadding = 20.0;
  // TODO(terry): Compute dynamically based on Y-axis lables text width.
  final leftPadding = 50.0;
  // Computed minimum right padding.
  int rightPadding = 25;
  // TODO(terry): Compute dynamically based on X-axis lables text height.
  final bottomPadding = 40.0;

  // TODO(terry): Consider computation of each X-axis tick width (scaled).
  double tickWidth = 10.0;

  int visibleTicks;

  // TODO(terry): For now three labels.  Need better mechanism, some number of labels
  //              based on x-axis zoom factor and default unit to display for labels e.g.,
  //              live take the duration (visible) and divide by some nice unit e.g., 10/20
  //              seconds, 5 minute show 1 minute units, 15 minutes show 5 minute units, etc.

  final List<int> _xAxisLabeledTimestamps = [null, null, null];

  int getLabelsCount() => _xAxisLabeledTimestamps.length;

  int getLabeledIndexByTimestamp(int timestamp) =>
      _xAxisLabeledTimestamps.indexOf(timestamp);

  int getLabelTimestampByIndex(int index) => _xAxisLabeledTimestamps[index];

  int get leftLabelTimestamp => _xAxisLabeledTimestamps[leftLabelIndex];
  set leftLabelTimestamp(int timestamp) {
    _xAxisLabeledTimestamps[leftLabelIndex] = timestamp;
  }

  int get centerLabelTimestamp => _xAxisLabeledTimestamps[centerLabelIndex];
  set centerLabelTimestamp(int timestamp) {
    _xAxisLabeledTimestamps[centerLabelIndex] = timestamp;
  }

  int get rightLabelTimestamp => _xAxisLabeledTimestamps[rightLabelIndex];
  set rightLabelTimestamp(int timestamp) {
    _xAxisLabeledTimestamps[rightLabelIndex] = timestamp;
  }

  final bool displayXLabels;
  final bool displayYLabels;

  Duration durationLabel;

  // TODO(terry): Duration based on x-axis zoom factor (live,5 min,15 min,etc).
  void computeDurationLabel() {
    if (durationLabel == null && rightLabelTimestamp != null) {
      final timestampsLength = timestamps.length;
      final midTick = (visibleTicks / 2).truncate();
      if (timestampsLength > visibleTicks) {
        // Lots of collected data > visible ticks so compute the visible mid tick.
        final midTimestamp = timestamps[timestampsLength - midTick];
        final lastTimestamp = rightLabelTimestamp;
        final midDT = DateTime.fromMillisecondsSinceEpoch(midTimestamp);
        final lastDT = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
        durationLabel = lastDT.difference(midDT);
      } else if (timestampsLength > midTick) {
        // Still collecting data when mid tick is collected compute the duration
        // of the mid tick.
        final midTimestamp = timestamps[midTick];
        final lastTimestamp = rightLabelTimestamp;
        final midDT = DateTime.fromMillisecondsSinceEpoch(midTimestamp);
        final lastDT = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
        durationLabel = midDT.difference(lastDT);
      }
    }
  }

  /// Used to compute incoming ticks.
  /// @param refresh true rebuild all labels (probably zoom changed).
  /// @param timestamp current timestamp received implies building all
  /// parts of the x-axis labels.
  void recomputeLabels({int timestamp, bool refresh = false}) {
    if (refresh) {
      // Need the correct tickWidth based on current zoom.
      computeChartArea();

      // All labels need to be recomputed.
      durationLabel = null;
      _xAxisLabeledTimestamps.replaceRange(
        0,
        _xAxisLabeledTimestamps.length,
        [null, null, null],
      );

      final timestampsLength = timestamps.length;
      final midPt = (visibleTicks / 2).truncate();
      if (timestampsLength > visibleTicks) {
        leftLabelTimestamp = timestamps[timestamps.length - visibleTicks + 10];
        centerLabelTimestamp = timestamps[timestamps.length - midPt];
        rightLabelTimestamp = timestamps.last;
      } else if (timestampsLength > midPt) {
        centerLabelTimestamp = timestamps[timestamps.length - midPt];
        rightLabelTimestamp = timestamps.last;
      } else if (timestamps.isNotEmpty) {
        rightLabelTimestamp = timestamps.first;
      }
      return;
    }

    if (durationLabel == null && rightLabelTimestamp == null) {
      // No center label so start first label (right-side).
      rightLabelTimestamp = timestamp;
    } else if (durationLabel != null && centerLabelTimestamp == null) {
      // Need a center label are we at the duration we want for the
      // next tick label?
      final rightDT = DateTime.fromMillisecondsSinceEpoch(rightLabelTimestamp);
      final currentDT = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (currentDT.difference(rightDT).inSeconds >= durationLabel.inSeconds) {
        slideLabelsLeft();
        rightLabelTimestamp = timestamp;
      }
    } else if (durationLabel != null && leftLabelTimestamp == null) {
      // Need a left label are we at the duration we want for the
      // next tick label?
      final rightDT = DateTime.fromMillisecondsSinceEpoch(rightLabelTimestamp);
      final currentDT = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (currentDT.difference(rightDT).inSeconds >= durationLabel.inSeconds) {
        slideLabelsLeft();
        rightLabelTimestamp = timestamp;
      }
    }
  }

  void slideLabelsLeft() {
    // Left-side out of visible range. Slide center and right labels to
    // left-most and center. Need to eventually recompute right-most when
    // duration gap is met.
    leftLabelTimestamp = centerLabelTimestamp;
    centerLabelTimestamp = rightLabelTimestamp;
    rightLabelTimestamp = null;
  }

  // xCanvas coord for plotting data.
  double xCanvasChart;

  // Width of the canvas for plotting data (#).
  double canvasChartWidth;

  // Right-side padding after computing minPadding and max number of integral ticks for canvasChartWidth.
  double xPaddingRight;

  // yCanvas coord for plotting data.
  double yCanvasChart = 0;

  // yCanvas height for plotting data.
  double canvasChartHeight = 0;

  // X axis ticks, each timestamp is a tick on the X axis.
  final timestamps = <int>[];

  final traces = <Trace>[];

  ValueNotifier<TraceNotifier> get traceChanged => _traceNotifier;

  final _traceNotifier = ValueNotifier<TraceNotifier>(TraceNotifier(-1, -1));

  double _yMaxValue = 0.0;

  double get yMaxValue => _yMaxValue;

  AxisScale yScale = AxisScale(0, 0, 30);

  // TODO(terry): Could go smaller if the range is a subset of the trace being rendered.
  // Consider value notifier probably on the yScale.
  set yMaxValue(double value) {
    if (value > _yMaxValue) {
      _yMaxValue = value;
      yScale = AxisScale(0, yMaxValue, canvasChartHeight.toDouble());

      // TODO(terry): Redraw the YAxis ticks/labels.
    }
  }

  void resetYMaxValue(double value) {
    _yMaxValue = 0;
    yMaxValue = value;
  }

  double _fixedMinY;

  double _fixedMaxY;

  void setFixedYRange(double min, double max) {
    _fixedMinY = min;
    _fixedMaxY = max;
  }

  double get fixedMinY => _fixedMinY;

  double get fixedMaxY => _fixedMaxY;

  String title;

  displayDuration zoomDuration = displayDuration.live;

  static const oneMinuteInMs = 1000 * 60;

  void setXAxisZoomDuration(Duration duration) {
    if (duration == null) {
      // Display all items.
      tickWidth = canvasChartWidth / timestamps.length;
      zoomDuration = displayDuration.all;
    } else if (duration.inMinutes == 0) {
      tickWidth = 10.0; // Live
      zoomDuration = displayDuration.live;
    } else if (duration.inMinutes == 5 || duration.inMinutes == 15) {
      final firstDT = DateTime.fromMillisecondsSinceEpoch(timestamps.first);
      final lastDT = DateTime.fromMillisecondsSinceEpoch(timestamps.last);
      // Greater or equal to range we're zooming in on?
      if (lastDT.difference(firstDT).inMinutes >= duration.inMinutes) {
        // Grab the duration in minutes passed in.
        final startOfLastNMinutes = timestamps.reversed.firstWhere(
          (timestamp) {
            final currentDT = DateTime.fromMillisecondsSinceEpoch(timestamp);
            final diff = lastDT.difference(currentDT);
            if (diff.inMinutes >= duration.inMinutes) {
              return true;
            }

            return false;
          },
          orElse: () => null,
        );

        final ticksVisible =
            timestamps.length - timestamps.indexOf(startOfLastNMinutes);
        tickWidth = canvasChartWidth / ticksVisible;
      } else {
        // No but lets scale x-axis based on the last two timestamps diffs we have.
        // TODO(terry): Consider using all the data maybe average out the time between
        //              ticks.
        final length = timestamps.length;
        // Enough data (at least 2 points) to know how many ticks for the duration.
        if (length > 1) {
          final lastTS = DateTime.fromMillisecondsSinceEpoch(timestamps.last);
          final previousTS =
              DateTime.fromMillisecondsSinceEpoch(timestamps[length - 2]);
          final diffTS = lastTS.difference(previousTS);
          final ticksPerMinute = oneMinuteInMs / diffTS.inMilliseconds;
          final ticksVisible = ticksPerMinute * duration.inMinutes;
          tickWidth = canvasChartWidth / ticksVisible;
        }
      }

      zoomDuration = duration.inMinutes == 5
          ? displayDuration.fiveMinutes
          : displayDuration.fifteenMinutes;
    }

    // All tick labels need to be recompted.
    recomputeLabels(refresh: true);
  }

  void computeChartArea() {
    xCanvasChart = leftPadding;
    final width = size.width - leftPadding - rightPadding;
    // Compute max number of ticks visible on X-Axis.
    visibleTicks = (width / tickWidth).truncate();
    canvasChartWidth = visibleTicks.toDouble() * tickWidth;
    // Right-side padding after adjust for max ticks on width.
    xPaddingRight = width - canvasChartWidth;
    yCanvasChart = topPadding;
    canvasChartHeight = size.height - topPadding - bottomPadding;

    if (fixedMinY != null && fixedMaxY != null) {
      yScale = AxisScale(fixedMinY, fixedMaxY, canvasChartHeight.toDouble());
    } else {
      // TODO(terry): Better value than fixed amount?
      // Allocate a bit of slop to approach near top.
      yScale = AxisScale(0, yMaxValue, canvasChartHeight.toDouble() - 5);
    }
  }

  double xPositonToYCanvasCoord(double y) {
    final zeroPosition = xCanvasChart + canvasChartWidth;
    return zeroPosition - yScale?.tickFromValue(y);
  }

  double yPositonToYCanvasCoord(double y) {
    final zeroPosition = yCanvasChart + canvasChartHeight;
    return zeroPosition - yScale?.tickFromValue(y);
  }

  Trace trace(int index) {
    assert(index < traces.length);
    return traces[index];
  }

  int createTrace(
    ChartType chartType,
    PaintCharacteristics characteristics, {
    String name,
    List<Data> data,
  }) {
    final traceIndex = traces.length;

    final trace = Trace(chartType, characteristics);

    if (name != null) trace.name = name;
    if (data != null) trace.data.addAll(data);

    traces.add(trace);
    assert(trace == traces[traceIndex]);

    return traceIndex;
  }

  int get numberOfVisibleXAxisTicks => visibleTicks;

  /// If negative then total ticks collected < number of visible ticks to display.
  int get totalTimestampTicks => timestamps.length - numberOfVisibleXAxisTicks;

  int get leftVisibleIndex {
    final leftIndex = totalTimestampTicks;
    if (leftIndex > 0) return leftIndex;

    // Less ticks than total size of ticks to show.
    return numberOfVisibleXAxisTicks - timestamps.length;
  }

  bool isTimestampVisible(int timestamp, int timestampIndex) {
    final leftMostIndex = leftVisibleIndex;
    // totalTimestampTicks < 0 then still collecting ticks and haven't
    // collected more than numberOfVisibleXAxisTicks of data yet.
    return totalTimestampTicks > 0 ? timestampIndex >= leftMostIndex : true;
  }

  int normalizeTimestampIndex(int index) {
    if (isTimestampVisible(timestamps[index], index)) {
      final firstVisibleIndex = leftVisibleIndex;
      if (totalTimestampTicks < 0) {
        return index;
      } else if (index >= firstVisibleIndex) {
        return index - firstVisibleIndex;
      }
    }
    return -1;
  }

  int get xCoordLeftMostVisibleTimestamp {
    int indexOffset = xCanvasChart.toInt();
    final totalTimestamps = timestamps.length;
    final visibleCount = numberOfVisibleXAxisTicks;
    if (totalTimestamps < visibleCount) {
      final startIndex = visibleCount - totalTimestamps;
      indexOffset += (startIndex * tickWidth).toInt();
    }

    return indexOffset;
  }

  // -1 implies not visible.
  double timestampXCanvasCoord(int timestamp) {
    final index = timestamps.indexOf(timestamp);
    final visibleIndex = normalizeTimestampIndex(index);
    if (visibleIndex >= 0) {
      return (xCoordLeftMostVisibleTimestamp + (visibleIndex * tickWidth))
          .toDouble();
    } else {
      return -1;
    }
  }
}
