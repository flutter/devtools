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
    @required this.color,
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

  final _data = <Data>[];

  // TODO(terry): Consider UnmodifiableListView if data is loaded from offline file (not live).
  List<Data> get data => _data;

  void addAllData(List<Data> data) {
    _data.addAll(data);
    controller.dirty = true;
  }

  ChartType get chartType => _chartType;

  AxisScale yAxis;

  void clearData() {
    _data.clear();
    controller.dirty = true;
  }

  void addDatum(Data datum) {
    _data.add(datum);
    controller.dirty = true;

    if (characteristics.fixedMaxY != null) {
      assert(
        datum.y <= characteristics.fixedMaxY,
        'y=${datum.y} fixedMaxY=${characteristics.fixedMaxY}',
      );
    } else if (datum.y > dataYMax) {
      dataYMax = datum.y.toDouble();
      yAxis = AxisScale(0, dataYMax, 30);
    }

    if (datum.y > controller?.yMaxValue) {
      controller?.yMaxValue = datum.y;
    }

    final traceIndex = controller.traceIndex(this);

    // New data has arrived notify listeners this data needs to be plotted.
    controller.traceChanged.value = TraceNotifier(traceIndex, data.length - 1);
  }
}

class TraceNotifier {
  TraceNotifier(this.traceIndex, this.dataIndex);

  /// Index of the trace that just changed, see ChartController field traces.
  final int traceIndex;

  /// Index of the datum that that changed for the Trace's data field (see
  /// Trace's data field).
  final int dataIndex;
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

  double get tickSpacing => _tickSpacing;

  double _tickSpacing;

  double get computedMin => _computedMin;
  double get computedMax => _computedMax;

  double _computedMin, _computedMax;

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

  double _calculateMin() => (minPoint / _tickSpacing).floor() * _tickSpacing;

  double _calculateMax() => (maxPoint / _tickSpacing).ceil() * _tickSpacing;

  Map _exponentFraction(double range) {
    if (range == 0) return {};

    final exponent = (log10(range)).floor().toDouble();
    final fraction = range / pow(10, exponent);

    return {'exponent': exponent, 'fraction': fraction};
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
      else if (fraction <= 5)
        niceFraction = 5;
      else if (fraction <= 7)
        niceFraction = 7;
      else if (fraction <= 10) niceFraction = 10;
    }

    return niceFraction * pow(10, exponent);
  }

  double tickFromValue(double value) =>
      (value / tickSpacing).truncateToDouble();
}
