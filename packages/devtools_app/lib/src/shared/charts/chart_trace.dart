// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';

import 'chart_controller.dart';

class Data {
  Data(this.timestamp, this.y);

  final int timestamp;
  final double y;
}

/// Stores the count of number of same points collected @ timestamp.  Used for
/// ExtensionEvents to coallase multiple events to one plotted symbol.
class DataAggregate extends Data {
  DataAggregate(super.timestamp, super.y, this.count);

  final int count;
}

class PaintCharacteristics {
  PaintCharacteristics({
    required this.color,
    this.colorAggregate,
    this.symbol = ChartSymbol.ring,
    this.strokeWidth = 1,
    this.diameter = 1,
    this.concentricCenterColor = Colors.black,
    this.concentricCenterDiameter = 1,
    this.width = 1,
    this.height = 1,
    this.fixedMinY,
    this.fixedMaxY,
  });

  PaintCharacteristics.concentric({
    required this.color,
    this.colorAggregate,
    this.symbol = ChartSymbol.concentric,
    this.strokeWidth = 1,
    this.diameter = 1,
    this.concentricCenterColor = Colors.black,
    this.concentricCenterDiameter = 1,
    this.width = 1,
    this.height = 1,
    this.fixedMinY,
    this.fixedMaxY,
  });

  /// If specified Y scale is computed and min value is fixed.
  /// Will assert if new data point is less than min specified.
  double? fixedMinY;

  /// If specified Y scale is computed and max value is fixed.
  /// Will assert if new data point is more than max specified.
  double? fixedMaxY;

  /// Primary color.
  Color color;

  /// Center circle color.
  Color concentricCenterColor;

  /// Center circle size.
  double concentricCenterDiameter;

  /// Color to use if count > 1.
  ///
  /// See [DataAggregate.count].
  Color? colorAggregate;

  ChartSymbol symbol;

  double strokeWidth;

  /// Used for disc or ring (circle).
  double diameter;

  /// Height and Width used for square or triangle.
  double height;

  double width;
}

class Trace {
  Trace(this.controller, this._chartType, this.characteristics) {
    final minY = characteristics.fixedMinY ?? 0.0;
    final maxY = characteristics.fixedMaxY ?? 0.0;
    yAxis = AxisScale(minY, maxY, 30);
  }

  final ChartController controller;

  final ChartType _chartType;

  final PaintCharacteristics characteristics;

  /// All traces, stacked == true, are aligned to previous stacked trace.
  /// E.g., Trace 1, 2, and 3 are all stacked,
  ///
  /// |         /'''''''''\      /     <--- Trace 3
  /// |        /           \    /
  /// |-------/             \  /
  /// | /\      _______      \/
  /// |/  \____/       \
  /// | ___/'''''''\    \  /''''''     <--- Trace 2 (lowest Y is zero)
  /// |/            \____\/_____/''    <--- Trace 1
  /// -------------------------------
  late bool stacked;

  String? name;

  double dataYMax = 0;

  final _data = <Data>[];

  Path? get symbolPath {
    if (_symbolPath != null) return _symbolPath;

    switch (characteristics.symbol) {
      case ChartSymbol.filledSquare:
      case ChartSymbol.square:
        _symbolPath = _createSquare();
        break;
      case ChartSymbol.filledTriangle:
      case ChartSymbol.triangle:
        _symbolPath = _createTriangle();
        break;
      case ChartSymbol.filledTriangleDown:
      case ChartSymbol.triangleDown:
        _symbolPath = _createTriangleDown();
        break;
      default:
        _symbolPath = null;
    }

    return _symbolPath;
  }

  /// Path to draw symbol.
  Path? _symbolPath;

  // TODO(terry): Consider UnmodifiableListView if data is loaded from offline file (not live).
  List<Data> get data => _data;

  void addAllData(List<Data> data) {
    _data.addAll(data);
    controller.dirty = true;
  }

  ChartType get chartType => _chartType;

  AxisScale? yAxis;

  void clearData() {
    _data.clear();
    controller.dirty = true;
  }

  void addDatum(Data datum) {
    _data.add(datum);
    controller.dirty = true;

    if (characteristics.fixedMaxY != null) {
      assert(
        datum.y <= characteristics.fixedMaxY!,
        'y=${datum.y} fixedMaxY=${characteristics.fixedMaxY}',
      );
    } else if (datum.y > dataYMax) {
      dataYMax = datum.y.toDouble();
      yAxis = AxisScale(0, dataYMax, 30);
    }

    if (datum.y > controller.yMaxValue) {
      controller.yMaxValue = datum.y;
    }

    // New data has arrived notify listeners this data needs to be plotted.
    // TODO(polina-c): should we use stream instead notifier?
    // https://github.com/flutter/devtools/pull/5301#discussion_r1126792303
    controller.traceChanged.value = TraceNotifier();
  }

  /// Draw square centered on [x,y] point (*).
  ///  0_____    .___.
  ///            |   |
  ///            | * |
  ///            !___!
  ///
  Path _createSquare() {
    if (_symbolPath == null) {
      _symbolPath = Path();

      _symbolPath!.addRect(
        Rect.fromLTWH(
          0,
          0,
          characteristics.width,
          characteristics.height,
        ),
      );

      _symbolPath!.close();
    }

    return _symbolPath!;
  }

  /// Draw triangle centered on [x,y] point (*).
  ///  0____    .
  ///          / \
  ///         / * \
  ///       ./_____\.
  ///
  Path _createTriangle() {
    if (_symbolPath == null) {
      final width = characteristics.width;
      final height = characteristics.height;

      _symbolPath = Path();

      // Top point.
      _symbolPath!.moveTo(width / 2, 0);
      // Diagonal line from top point to bottom right-side.
      _symbolPath!.lineTo(width, height);
      // Horizontal line from bottom right-side to bottom left-side.
      _symbolPath!.lineTo(0, height);

      // Closing path finishes left-side diagonal line from bottom-left corner
      // to top point.
      _symbolPath!.close();
    }

    return _symbolPath!;
  }

  // Draw triangle centered on [x,y] point (*).
  //  0 _____  ._______.
  //            \     /
  //             \ * /
  //              \ /
  //               `
  Path _createTriangleDown() {
    if (_symbolPath == null) {
      final width = characteristics.width;
      final height = characteristics.height;

      _symbolPath = Path();

      // Straight horizontal line to top-right corner (moveTo starts at 0,0).
      _symbolPath!.lineTo(width, 0);
      // Diagonal right-side line to bottom tip point.
      _symbolPath!.lineTo(width / 2, height);

      // Closing path finishes left-side diagonal line from bottom tip point to
      // top-left corner.
      _symbolPath!.close();
    }

    return _symbolPath!;
  }
}

class TraceNotifier {
  TraceNotifier();
}

enum ChartType {
  symbol,
  line,
}

enum ChartSymbol {
  ring, // Lined circle
  disc, // Filled circle
  concentric, // outer ring and inner disc
  square, // Lined square
  filledSquare, // Filled square
  triangle, // Lined triangle
  filledTriangle,
  triangleDown, // Lined triangle points down
  filledTriangleDown,

  dashedLine,
}

double log10(num x) => log(x) / ln10;

class AxisScale {
  factory AxisScale(double minPoint, double maxPoint, double maxTicks) {
    final range = _niceNum(maxPoint, false);
    final double tickSpacing;
    final double exponent;
    final double fraction;
    if (range != 0) {
      tickSpacing = range / (maxTicks - 1);
      (:exponent, :fraction) = _exponentFraction(range);
    } else {
      tickSpacing = 1;
      exponent = 0;
      fraction = 0;
    }
    return AxisScale._(
      minPoint: minPoint,
      maxPoint: maxPoint,
      maxTicks: maxTicks,
      tickSpacing: tickSpacing,
      labelUnitExponent: exponent,
      labelTicks: fraction,
    );
  }

  AxisScale._({
    required this.minPoint,
    required this.maxPoint,
    required this.maxTicks,
    required this.tickSpacing,
    required this.labelUnitExponent,
    required this.labelTicks,
  });

  final double minPoint, maxPoint;

  final double maxTicks;

  final double tickSpacing;

  /// Unit for the label (exponent) e.g., 6 = 10^6.
  final double labelUnitExponent;

  /// Number of labels.
  final double labelTicks;

  static ({double exponent, double fraction}) _exponentFraction(double range) {
    assert(range != 0);

    final exponent = log10(range).floor().toDouble();
    final fraction = range / pow(10, exponent);

    return (exponent: exponent, fraction: fraction.roundToDouble());
  }

  /// Produce a whole number for the Y-axis scale and its unit using
  /// the exponent. Goal is to compute the range of values for min, max
  /// and exponent (our unit of measurement e.g., K, M, B, etc.). The axis
  /// labels are displayed in 1s, 10s and 100s e.g., 10M, 50M, 100M or
  /// 1B, 2B, 3B.
  ///
  /// @param round if false, chunks the whole number to keep more available
  /// space above the max Y value highpoint to handle future bigger data
  /// values w/o having to rescale too quickly e.g., over 3e+3 displays:
  ///    10K, 20K, 30K, 40K, 50K
  /// This allows new data points >30K to be plotted w/o having to
  /// re-layout new Y-axis scale.
  static double _niceNum(double range, bool round) {
    if (range == 0) return 0;

    // Exponent of range.
    final exponent = log10(range).floor().toDouble();
    // Fractional part of range.
    final fraction = range / pow(10, exponent);
    // Nice, rounded fraction.
    final niceFraction = round
        ? fraction.roundToDouble()
        : switch (fraction) {
            <= 1 => 1.0,
            <= 2 => 2.0,
            <= 3 => 3.0,
            <= 5 => 5.0,
            <= 7 => 7.0,
            _ => 10.0,
          };

    return niceFraction * pow(10, exponent);
  }

  double tickFromValue(double value) =>
      (value / tickSpacing).truncateToDouble();
}
