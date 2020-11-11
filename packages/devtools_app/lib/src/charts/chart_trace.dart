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

class PaintCharacteristics {
  PaintCharacteristics({
    this.color = Colors.black,
    this.symbol = ChartSymbol.ring,
    this.strokeWidth = 1,
    this.diameter = 1,
    this.fixedMinY,
    this.fixedMaxY,
  });

  /// If specified Y scale is computed and min value is fixed.
  /// Will assert if new data point is less than min specified.
  double fixedMinY;

  /// If specified Y scale is computed and max value is fixed.
  /// Will assert if new data point is more than max specified.
  double fixedMaxY;

  Color color;

  ChartSymbol symbol;

  double strokeWidth;

  double diameter;
}

class Trace {
  Trace(this.controller, this._chartType, this.characteristics) {
    double minY = characteristics.fixedMinY;
    minY ??= 0.0;

    double maxY = characteristics.fixedMaxY;
    maxY ??= 0.0;

    yAxis = AxisScale(minY, maxY, 30);
  }

  final ChartController controller;

  final ChartType _chartType;

  final PaintCharacteristics characteristics;

  String name;

  double dataYMax = 0;

  final data = <Data>[];

  ChartType get chartType => _chartType;

  AxisScale yAxis;

  void addDatum(Data datum) {
    data.add(datum);

    if (characteristics.fixedMaxY != null) {
      assert(
        datum.y <= characteristics.fixedMaxY,
        'y=${datum.y} fixedMaxY=${characteristics.fixedMaxY}',
      );
    } else if (datum.y > dataYMax) {
      dataYMax = datum.y.toDouble();
      yAxis = AxisScale(0, dataYMax, 30);
    }

    if (datum.y > controller?.yMaxValue) controller?.yMaxValue = datum.y;

    final traceIndex = controller.traceIndex(this);

    // New data has arrived notify listeners this data needs to be plotted.
    controller.traceChanged.value = TraceNotifier(traceIndex, data.length - 1);
  }
}

class TraceNotifier {
  TraceNotifier(this.traceIndex, this.dataIndex);

  int traceIndex;
  int dataIndex;
}

enum ChartType {
  symbol,
  line,
}

enum ChartSymbol {
  ring,
  disc,
  square,
  triangle,
  dashedLine,
}

double log10(num x) => log(x) / ln10;

class AxisScale {
  AxisScale(this.minPoint, this.maxPoint, this.maxTicks) {
    _calculate();
  }

  final double minPoint, maxPoint;

  final double maxTicks;

  double _computedMin, _computedMax;

  double _tickSpacing;

  double get tickSpacing => _tickSpacing;
  double get computedMin => _computedMin;
  double get computedMax => _computedMax;

  double _range;

  /// Unit for the label (exponent) e.g., 6 = 10^6
  double labelUnitExponent;

  /// Number of lables.
  double labelTicks;

  void _calculate() {
    _range = _niceNum(maxPoint, false);
    if (_range != 0) {
      _tickSpacing = _range / (maxTicks - 1);
      _computedMin = _calculateMin();
      _computedMax = _calculateMax();
      final exponentFraction = _exponentFraction(_range);
      labelUnitExponent = exponentFraction['exponent'];
      labelTicks = exponentFraction['fraction'].roundToDouble();
    } else {
      _tickSpacing = 1;
      _computedMin = 0;
      _computedMax = 0;
      labelUnitExponent = 0;
      labelTicks = 0;
    }
  }

  double _calculateMin() {
    final floored = (minPoint / _tickSpacing).floor();
    return floored * _tickSpacing;
  }

  double _calculateMax() {
    final ceiled = (maxPoint / _tickSpacing).ceil();
    return ceiled * _tickSpacing;
  }

  Map _exponentFraction(double range) {
    if (range == 0) return {};

    final exponent = (log10(range)).floor().toDouble();
    final fraction = range / pow(10, exponent);

    return {'exponent': exponent, 'fraction': fraction};
  }

  double _niceNum(double range, bool round) {
    if (range == 0) return 0;

    double exponent; // exponent of range
    double fraction; // fractional part of range
    double niceFraction; // nice, rounded fraction

    exponent = (log10(range)).floor().toDouble();
    fraction = range / pow(10, exponent);

    if (round) {
      niceFraction = fraction.roundToDouble();
    } else {
      if (fraction <= 1)
        niceFraction = 1;
      else if (fraction <= 2)
        niceFraction = 2;
      else if (fraction <= 3)
        niceFraction = 3;
      else if (fraction <= 4)
        niceFraction = 4;
      else if (fraction <= 5)
        niceFraction = 5;
      else if (fraction <= 6)
        niceFraction = 6;
      else if (fraction <= 7)
        niceFraction = 7;
      else
        niceFraction = 10;
    }

    return niceFraction * pow(10, exponent);
  }

  int tickFromValue(double value) => (value / tickSpacing).truncate();
}
