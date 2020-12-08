// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../auto_dispose.dart';

import 'chart_trace.dart';

/// Displays timestamp using locale's timezone HH:MM:SS, if isUtc is false.
/// @param isUTC - if true for testing, the UTC locale is used (instead of
/// the user's locale). Tests will then pass when run in any timezone. All
/// formatted timestamps are displayed using the UTC locale.
String prettyTimestamp(
  int timestamp, {
  bool isUtc = false,
}) {
  final timestampDT = DateTime.fromMillisecondsSinceEpoch(
    timestamp,
    isUtc: isUtc,
  );
  return intl.DateFormat.Hms().format(timestampDT); // HH:mm:ss
}

///_____________________________________________________________________
///
///                                       xPaddingRight
///                                       |
///   leftPadding          topPadding     |  rightPadding
///   |                    |              |  |
/// ==|====================|==============|==|=
/// " |                    V              |  |
/// " V ----------------------------------V  V
/// "   |
/// "   |
/// "   |
/// "   | ------ canvasChartWidth --------
/// "   |
/// "   |
/// "   ---------------------------------- <----- yCanvasChart
/// "   '  '  '  '  '  '  '  '  '  '  '  '    {-------- bottomPadding
/// "   ^                ^                     \
/// ====|================|======================
///     |                |
///     xCanvasChart     X-axis ticks
///_____________________________________________________________________
///
class ChartController extends DisposableController
    with AutoDisposeControllerMixin {
  ChartController({
    this.displayTopLine = true,
    this.displayXAxis = true,
    this.displayXLabels = true,
    this.displayYLabels = true,
    this.name,
    List<int> sharedLabelimestamps,
  }) {
    // TODO(terry): Compute dynamically based on X-axis lables text height.
    bottomPadding = !displayXLabels ? 0.0 : 40.0;

    if (sharedLabelimestamps != null) {
      labelTimestamps = sharedLabelimestamps;
      _labelsShared = true;
    }
  }

  /// Used for debugging to determine which chart.
  final String name;

  // Total size of area to display the chart (includes title, axis, labels, etc.).
  Size size;

  /// Spacing for title iff title != null.
  double topPadding = 0.0;

  // TODO(terry): Compute dynamically based on Y-axis lables text width.
  final leftPadding = 50.0;

  /// Computed minimum right padding.
  int rightPadding = 25;

  /// Space for X-Axis labels and tick marks;
  double bottomPadding = 40.0;

  double get tickWidth => _tickWidth;

  double _tickWidth = 10.0;

  /// Number of ticks visible (on the X-axis);
  int visibleTicks;

  // TODO(terry): For now three labels.  Need better mechanism, some number of labels
  //              based on x-axis zoom factor and default unit to display for labels e.g.,
  //              live take the duration (visible) and divide by some nice unit e.g., 10/20
  //              seconds, 5 minute show 1 minute units, 15 minutes show 5 minute units, width
  //              of the window, etc.
  final List<int> _xAxisLabeledTimestamps = [null, null, null];

  int getLabelsCount() => _xAxisLabeledTimestamps.length;

  int getLabeledIndexByTimestamp(int timestamp) =>
      _xAxisLabeledTimestamps.indexOf(timestamp);

  int getLabelTimestampByIndex(int index) => _xAxisLabeledTimestamps[index];

  /// If false displays top horizontal line of chart.
  final bool displayTopLine;

  /// If true the X axis line is rendered, if false then both the X axis line
  /// is not rendered and the labels and ticks are also not rendered.
  final bool displayXAxis;

  /// If true render the labels and ticks on the X axis, if displayXAxis is
  /// false then the labels and ticks are not rendered.
  final bool displayXLabels;

  final bool displayYLabels;

  /// xCanvas coord for plotting data.
  double xCanvasChart;

  /// Width of the canvas for plotting data (#).
  double canvasChartWidth;

  /// Right-side padding after computing minPadding and max number of integral ticks for canvasChartWidth.
  double xPaddingRight;

  /// yCanvas coord for plotting data.
  double yCanvasChart = 0;

  /// yCanvas height for plotting data.
  double canvasChartHeight = 0;

  bool get isDirty => dirty;

  bool dirty = false;

  // TODO(terry): Consider timestamps returning UnmodifiableListView
  //              if loaded from a file (not live).
  List<int> get timestamps => _timestamps;

  /// X axis ticks, each timestamp is a tick on the X axis.
  final _timestamps = <int>[];

  void addTimestamp(int timestamp) {
    _timestamps.add(timestamp);
    dirty = true;
  }

  void timestampsClear() {
    _timestamps.clear();
    dirty = true;
  }

  int get timestampsLength => _timestamps.length;

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

  String get title => _title;

  String _title;

  set title(String value) {
    // TODO(terry): Compute dynamically based on title text height.
    topPadding = value != null ? 20.0 : 0.0;
    _title = value;
  }

  /// zoomDuration values of:
  ///     null implies all
  ///     Duration() imples live (default)
  ///     Duration(minutes: 5) implies 5 minute interval
  Duration _zoomDuration = const Duration();

  Duration get zoomDuration => _zoomDuration;

  static const oneMinuteInMs = 1000 * 60;

  bool get isZoomAll => _zoomDuration == null;

  /// Label is displayed every N seconds, default is 20 seconds
  /// for live view.  See computeLabelInterval method.
  int labelInterval = labelsLiveSeconds;

  /// List of timestamps where a label is displayed.  First in the left-most
  /// label (which will eventually scroll out of view and be replaced).
  var labelTimestamps = <int>[];

  bool get isLabelsShared => _labelsShared;

  /// If true signals that labels are compute from another controller.
  var _labelsShared = false;

  void computeZoomRatio() {
    // Check if ready to start computations?
    if (size == null) return;

    if (isZoomAll) {
      _tickWidth = canvasChartWidth / timestampsLength;
    }
  }

  set zoomDuration(Duration duration) {
    if (duration == null) {
      // Display all items.
    } else if (duration.inMinutes == 0) {
      _tickWidth = 10.0; // Live
    } else if (timestamps.isNotEmpty && duration.inMinutes > 0) {
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
            timestampsLength - timestamps.indexOf(startOfLastNMinutes);
        _tickWidth = canvasChartWidth / ticksVisible;
      } else {
        // No but lets scale x-axis based on the last two timestamps diffs we have.
        // TODO(terry): Consider using all the data maybe average out the time between
        //              ticks.
        final length = timestampsLength;
        // Enough data (at least 2 points) to know how many ticks for the duration.
        if (length > 1) {
          final lastTS = DateTime.fromMillisecondsSinceEpoch(timestamps.last);
          final previousTS =
              DateTime.fromMillisecondsSinceEpoch(timestamps[length - 2]);
          final diffTS = lastTS.difference(previousTS);
          final ticksPerMinute = oneMinuteInMs / diffTS.inMilliseconds;
          final ticksVisible = ticksPerMinute * duration.inMinutes;
          _tickWidth = canvasChartWidth / ticksVisible;
        }
      }
    }

    _zoomDuration = duration;
    computeZoomRatio();

    // All tick labels need to be recompted.
    computeChartArea();
    computeLabelInterval();

    dirty = true;
  }

  /// Label rate unit in seconds. Default label every 20 seconds for live view.
  static const labelsLiveSeconds = 20;
  static const labelsFifteenSeconds = 15;
  static const labelsThirtySeconds = 30;
  static const labelsOneMinute = 60;
  static const labelsTwoMinutes = 120;
  static const labelsOneHour = 60 * 60;
  static const labelsFourHours = 60 * 60 * 4;
  static const labelsTwelveHours = 60 * 60 * 12;

  void computeLabelInterval() {
    if (zoomDuration == null && timestamps.isNotEmpty) {
      final firstDT = DateTime.fromMillisecondsSinceEpoch(timestamps.first);
      final lastDT = DateTime.fromMillisecondsSinceEpoch(timestamps.last);
      final totalDuration = lastDT.difference(firstDT);
      final totalHours = totalDuration.inHours;
      if (totalHours == 0) {
        final totalMinutes = totalDuration.inMinutes;
        if (totalMinutes == 0) {
          labelInterval = labelsThirtySeconds;
        } else if (totalMinutes < 10) {
          labelInterval = labelsOneMinute;
        } else {
          labelInterval = labelsTwoMinutes;
        }
      } else if (totalHours > 0 && totalHours < 8) {
        labelInterval = labelsOneHour;
      } else if (totalHours < 24) {
        labelInterval = labelsFourHours;
      } else {
        labelInterval = labelsTwelveHours;
      }
    } else {
      final rangeInMinutes = zoomDuration?.inMinutes;
      if (rangeInMinutes == null) return;
      switch (rangeInMinutes) {
        case 0: // Live
          labelInterval = labelsLiveSeconds;
          break;
        case 1: // 1 minute
          labelInterval = labelsFifteenSeconds;
          break;
        case 5: // 5 minute
          labelInterval = labelsOneMinute;
          break;
        case 10: // 10 minute
          labelInterval = labelsTwoMinutes;
          break;
        default:
          assert(false, 'Unexpected Duration $rangeInMinutes');
      }
    }

    buildLabelTimestamps(refresh: true);
  }

  void buildLabelTimestamps({refresh = false}) {
    if (isLabelsShared || timestamps.isEmpty) return;

    if (refresh) {
      labelTimestamps.clear();
      final leftMostTimestamp = leftMostVisibleTimestampIndex;
      final lastTimestamp = timestamps[leftMostTimestamp];
      labelTimestamps.add(lastTimestamp);
      var lastLabelDT = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
      for (var index = leftMostTimestamp; index < timestampsLength; index++) {
        final currentTimestamp = timestamps[index];
        final currentDT = DateTime.fromMillisecondsSinceEpoch(currentTimestamp);
        if (currentDT.difference(lastLabelDT).inSeconds >= labelInterval) {
          labelTimestamps.add(currentTimestamp);
          lastLabelDT = currentDT;
        }
      }

      return;
    }

    if (labelTimestamps.isEmpty) {
      labelTimestamps.add(timestamps.last);
    } else {
      // Check left label is it out of range?
      final leftEdge = leftMostVisibleTimestampIndex;
      // TODO(terry): Need to insure that more than one label may not be
      //              visible e.g., when panning the chart.
      if (labelTimestamps.first < timestamps[leftEdge]) {
        // Label is outside of visible range, remove the left label.
        labelTimestamps.removeAt(0);
      }
    }

    if (labelTimestamps.isEmpty) return;

    final rightLabelTimestamp = labelTimestamps.last;
    final rightMostLableDT =
        DateTime.fromMillisecondsSinceEpoch(rightLabelTimestamp);
    final rightMostTimestampDT =
        DateTime.fromMillisecondsSinceEpoch(timestamps.last);

    final nSeconds =
        rightMostTimestampDT.difference(rightMostLableDT).inSeconds;

    if (nSeconds >= labelInterval) {
      int foundTimestamp;
      if (nSeconds == labelInterval) {
        foundTimestamp = timestamps.last;
      } else {
        // Find the interval that's closest to the next interval.
        final startIndex = timestamps.indexOf(rightLabelTimestamp);
        for (var index = startIndex; index < timestampsLength; index++) {
          foundTimestamp = timestamps[index];
          final nextDT = DateTime.fromMillisecondsSinceEpoch(foundTimestamp);
          final secsDiff = nextDT.difference(rightMostTimestampDT).inSeconds;
          if (secsDiff >= labelInterval) break;
        }
      }
      assert(foundTimestamp != null);
      labelTimestamps.add(foundTimestamp);
    }
  }

  /// Clear all data in the chart.
  void reset() {
    for (var trace in traces) {
      trace.clearData();
    }
    timestampsClear();
    labelTimestamps.clear();
  }

  /// Override to load data from another source e.g., live, offline, etc.
  void setupData() {}

  void computeChartArea() {
    // Check if ready to start computations?
    if (size == null) return;

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

  double get zeroYPosition => yCanvasChart + canvasChartHeight;

  double yPositon(double y) => yScale?.tickFromValue(y);

  // Returns a negative value, the value is subtracted from zeroPosition to
  // return the real canvas coord (adjusted from Y-axis zero location in the
  // chart).
  double yPositonToYCanvasCoord(double y) => -yPositon(y);

  Trace trace(int index) {
    assert(index < traces.length);
    return traces[index];
  }

  int traceIndex(Trace trace) => traces.indexOf(trace);

  int createTrace(
    ChartType chartType,
    PaintCharacteristics characteristics, {
    String name,
    List<Data> data,
  }) {
    final traceIndex = traces.length;

    final trace = Trace(this, chartType, characteristics);

    if (name != null) trace.name = name;
    if (data != null) trace.addAllData(data);

    traces.add(trace);
    assert(trace == traces[traceIndex]);

    return traceIndex;
  }

  int get numberOfVisibleXAxisTicks => visibleTicks;

  /// If negative then total ticks collected < number of visible ticks to display.
  int get totalTimestampTicks => timestampsLength - numberOfVisibleXAxisTicks;

  int get leftVisibleIndex {
    final leftIndex = totalTimestampTicks;
    if (leftIndex > 0) return leftIndex;

    // Less ticks than total size of ticks to show.
    return numberOfVisibleXAxisTicks - timestampsLength;
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

  /// Return timestamps index of the left most visible datum.
  int get leftMostVisibleTimestampIndex {
    var index = 0;
    if (timestampsLength > numberOfVisibleXAxisTicks) {
      index = timestampsLength - numberOfVisibleXAxisTicks;
    }

    return index;
  }

  /// X coordinate of left most visible datum. The timestampXCanvasCoord
  /// returns a zero based X-coord this X-coord must be translated by the
  /// value of this getter.
  double get xCoordLeftMostVisibleTimestamp {
    double indexOffset = xCanvasChart;
    if (timestampsLength < numberOfVisibleXAxisTicks) {
      final startIndex = numberOfVisibleXAxisTicks - timestampsLength;
      indexOffset += startIndex * tickWidth;
    }

    return indexOffset;
  }

  /// Returns a 0 based X-coordinate, this coordinate is not yet translated
  /// to the coordinates of the rendered chart. Returns -1 if timestamp not
  /// visible.
  double timestampXCanvasCoord(int timestamp) {
    final index = timestamps.indexOf(timestamp);
    if (index >= 0) {
      // Valid index.
      final visibleIndex = normalizeTimestampIndex(index);
      if (visibleIndex >= 0) {
        return (visibleIndex * tickWidth).toDouble();
      }
    }
    return -1;
  }
}
