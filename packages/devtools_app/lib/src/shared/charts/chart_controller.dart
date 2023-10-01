// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../primitives/utils.dart';
import 'chart_trace.dart';

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
    this.displayXAxis = true,
    this.displayXLabels = true,
    this.displayYLabels = true,
    this.name,
    List<int>? sharedLabelimestamps,
  }) {
    // TODO(terry): Compute dynamically based on X-axis labels text height.
    bottomPadding = !displayXLabels ? 0.0 : 40.0;

    if (sharedLabelimestamps != null) {
      labelTimestamps = sharedLabelimestamps;
      _labelsShared = true;
    }
  }

  /// Used for debugging to determine which chart.
  final String? name;

  // Total size of area to display the chart (includes title, axis, labels, etc.).
  Size? size;

  /// Spacing for title iff title != null.
  double topPadding = 0.0;

  // TODO(terry): Compute dynamically based on Y-axis label text width.
  final leftPadding = 50.0;

  /// Computed minimum right padding.
  int rightPadding = 25;

  /// Space for X-Axis labels and tick marks;
  double bottomPadding = 40.0;

  double get tickWidth => _tickWidth;

  double _tickWidth = 10.0;

  /// Number of ticks visible (on the X-axis);
  late int visibleXAxisTicks;

  /// If true the X axis line is rendered, if false then both the X axis line
  /// is not rendered and the labels and ticks are also not rendered.
  final bool displayXAxis;

  /// If true render the labels and ticks on the X axis, if displayXAxis is
  /// false then the labels and ticks are not rendered.
  final bool displayXLabels;

  final bool displayYLabels;

  /// xCanvas coord for plotting data.
  double xCanvasChart = 0;

  /// Width of the canvas for plotting data (#).
  late double canvasChartWidth;

  /// Right-side padding after computing minPadding and max number of integral ticks for canvasChartWidth.
  late double xPaddingRight;

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

  final _traceNotifier = ValueNotifier<TraceNotifier>(TraceNotifier());

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

  double? _fixedMinY;

  double? _fixedMaxY;

  void setFixedYRange(double min, double max) {
    _fixedMinY = min;
    _fixedMaxY = max;
  }

  double? get fixedMinY => _fixedMinY;

  double? get fixedMaxY => _fixedMaxY;

  String get title => _title;

  String _title = '';

  set title(String value) {
    // TODO(terry): Compute dynamically based on title text height.
    topPadding = value.isNotEmpty ? 20.0 : 0.0;
    _title = value;
  }

  final tapLocation = ValueNotifier<TapLocation?>(null);

  /// zoomDuration values of:
  ///     null implies all
  ///     Duration() imples live (default)
  ///     Duration(minutes: 5) implies 5 minute interval
  Duration? _zoomDuration = const Duration();

  Duration? get zoomDuration => _zoomDuration;

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

  set zoomDuration(Duration? duration) {
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
        final startOfLastNMinutes =
            // We need this cast to be able to return null if nothing is found.
            // ignore: unnecessary_cast
            timestamps.reversed.firstWhereOrNull((timestamp) {
          final currentDT = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final diff = lastDT.difference(currentDT);
          if (diff.inMinutes >= duration.inMinutes) {
            return true;
          }

          return false;
        });

        final ticksVisible = startOfLastNMinutes != null
            ? timestampsLength - timestamps.indexOf(startOfLastNMinutes)
            : timestampsLength + 1;
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
    final rightMostLabelDT =
        DateTime.fromMillisecondsSinceEpoch(rightLabelTimestamp);
    final rightMostTimestampDT =
        DateTime.fromMillisecondsSinceEpoch(timestamps.last);

    final nSeconds =
        rightMostTimestampDT.difference(rightMostLabelDT).inSeconds;

    if (nSeconds >= labelInterval) {
      late int foundTimestamp;
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
    final width = size!.width - leftPadding - rightPadding;
    // Compute max number of ticks visible on X-Axis.
    visibleXAxisTicks = (width / tickWidth).truncate();
    canvasChartWidth = visibleXAxisTicks.toDouble() * tickWidth;
    // Right-side padding after adjust for max ticks on width.
    xPaddingRight = width - canvasChartWidth;
    yCanvasChart = topPadding;
    canvasChartHeight = size!.height - topPadding - bottomPadding;

    if (fixedMinY != null && fixedMaxY != null) {
      yScale = AxisScale(fixedMinY!, fixedMaxY!, canvasChartHeight.toDouble());
    } else {
      // TODO(terry): Better value than fixed amount?
      // Allocate a bit of slop to approach near top.
      yScale = AxisScale(0, yMaxValue, canvasChartHeight.toDouble() - 5);
    }
  }

  double get zeroYPosition => yCanvasChart + canvasChartHeight;

  double yPosition(double y) => yScale.tickFromValue(y);

  // Returns a negative value, the value is subtracted from zeroPosition to
  // return the real canvas coord (adjusted from Y-axis zero location in the
  // chart).
  double yPositionToYCanvasCoord(double y) => -yPosition(y);

  Trace trace(int index) {
    assert(index < traces.length);
    return traces[index];
  }

  int createTrace(
    ChartType chartType,
    PaintCharacteristics characteristics, {
    String? name,
    bool stacked = false,
    List<Data>? data,
  }) {
    final traceIndex = traces.length;

    final trace = Trace(this, chartType, characteristics);

    // Stacked only supported for line charts.
    assert((stacked && chartType == ChartType.line) || !stacked);
    trace.stacked = stacked;

    if (name != null) trace.name = name;
    if (data != null) trace.addAllData(data);

    traces.add(trace);
    assert(trace == traces[traceIndex]);

    return traceIndex;
  }

  /// If negative then total ticks collected < number of visible ticks to display.
  int get totalTimestampTicks => timestampsLength - visibleXAxisTicks;

  int get leftVisibleIndex {
    final leftIndex = totalTimestampTicks;
    if (leftIndex > 0) return leftIndex;

    // Less ticks than total size of ticks to show.
    return visibleXAxisTicks - timestampsLength;
  }

  bool _isTimestampVisible(int timestampIndex) {
    final leftMostIndex = leftVisibleIndex;
    // totalTimestampTicks < 0 then still collecting ticks and haven't
    // collected more than visibleXAxisTicks of data yet.
    return totalTimestampTicks > 0 ? timestampIndex >= leftMostIndex : true;
  }

  int normalizeTimestampIndex(int index) {
    if (_isTimestampVisible(index)) {
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
    if (timestampsLength > visibleXAxisTicks) {
      index = timestampsLength - visibleXAxisTicks;
    }

    return index;
  }

  /// X coordinate of left most visible datum. The timestampXCanvasCoord
  /// returns a zero based X-coord this X-coord must be translated by the
  /// value of this getter.
  double get xCoordLeftMostVisibleTimestamp {
    double indexOffset = xCanvasChart;
    if (timestampsLength < visibleXAxisTicks) {
      final startIndex = visibleXAxisTicks - timestampsLength;
      indexOffset += startIndex * tickWidth;
    }

    return indexOffset;
  }

  /// Returns a 0 based X-coordinate, this coordinate is not yet translated
  /// to the coordinates of the rendered chart. Returns -1 if timestamp not
  /// visible.
  double timestampToXCanvasCoord(int timestamp) {
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

  int? xCoordToTimestamp(double xCoord) {
    final index = xCoordToTimestampIndex(xCoord);
    return timestamps.safeGet(index);
  }

  int xCoordToTimestampIndex(double xCoord) {
    final firstVisibleIndex = leftVisibleIndex;
    final index = (xCoord - leftPadding) ~/ tickWidth;

    int timestampedIndex;

    if (totalTimestampTicks < 0) {
      // Not enough items plotted on x-axis.
      timestampedIndex = index + totalTimestampTicks;
    } else if (index >= firstVisibleIndex) {
      timestampedIndex = index - firstVisibleIndex;
    } else {
      timestampedIndex = index + firstVisibleIndex;
    }

    // If index is left side, negative, that has yet to have any data
    // return the first timestamp.
    return timestampedIndex >= 0 ? timestampedIndex : 0;
  }
}

/// Location (index to the data & timestamp of the plotted values) where the user
/// clicked in a chart.
class TapLocation {
  /// When tap occurs, in a chart, pass the timestamp and index to the clicked data.
  TapLocation(this.tapDownDetails, this.timestamp, this.index);

  /// Copy of TapLocation w/o the detail, implies not where tap occurred
  /// but the multiple charts tied to the same timeline should be hilighted
  /// (selection point).
  TapLocation.copy(TapLocation original)
      : tapDownDetails = null,
        timestamp = original.timestamp,
        index = original.index;

  final TapDownDetails? tapDownDetails;

  /// Timestamp of the closest item in the x-axis timeseries.
  final int? timestamp;

  /// Index of the data point in the timeseries.
  final int index;
}
