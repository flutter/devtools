// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

import '../../../../primitives/utils.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/utils.dart';
import '../../../../ui/colors.dart';
import '../../performance_controller.dart';
import 'frame_analysis_model.dart';

class FramePieCharts extends StatefulWidget {
  const FramePieCharts({
    Key? key,
    required this.frameAnalysis,
  }) : super(key: key);

  final FrameAnalysis frameAnalysis;

  @override
  State<FramePieCharts> createState() => _FramePieChartsState();
}

class _FramePieChartsState extends State<FramePieCharts>
    with ProvidedControllerMixin<PerformanceController, FramePieCharts> {
  late FrameAnalysis frameAnalysis;

  late List<charts.Series<_ChartSlice, int>> uiPhaseData;

  late List<charts.Series<_ChartSlice, int>> rasterPhaseData;

  @override
  void didUpdateWidget(FramePieCharts oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initChartData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
    _initChartData();
  }

  void _initChartData() {
    frameAnalysis = widget.frameAnalysis;
    final displayRefreshRate = controller.displayRefreshRate.value;
    _initUiData(displayRefreshRate);
    _initRasterData(displayRefreshRate);
  }

  void _initUiData(double displayRefreshRate) {
    final isUiJanky = frameAnalysis.frame.isUiJanky(displayRefreshRate);
    final uiData = [
      frameAnalysis.buildPhase,
      frameAnalysis.layoutPhase,
      frameAnalysis.paintPhase,
    ].map((phase) => _ChartSlice(phase.title, phase.duration)).toList();

    uiPhaseData = [
      _createPieChartSeries(
        id: 'ui',
        data: uiData,
        outsideLabelColor: Theme.of(context).colorScheme.chartTextColor,
        insideLabelStyleFn: (phase, index) {
          const color = Colors.black;
          final insideLabelColor = charts.Color(
            r: color.red,
            g: color.green,
            b: color.blue,
            a: color.alpha,
          );
          return charts.TextStyleSpec(color: insideLabelColor);
        },
        colorFn: (phase, index) {
          final pallete = isUiJanky
              ? [
                  uiJankColor,
                  Colors.orange[300],
                  Colors.orange[100],
                ]
              : [
                  mainUiColor,
                  Colors.blueAccent[100],
                  Colors.blue[100],
                ];
          assert(pallete.length == uiData.length);
          final color = pallete[index!]!;
          return charts.Color(
            r: color.red,
            g: color.green,
            b: color.blue,
            a: color.alpha,
          );
        },
      ),
    ];
  }

  void _initRasterData(double displayRefreshRate) {
    final isRasterJanky = frameAnalysis.frame.isRasterJanky(displayRefreshRate);

    final frame = frameAnalysis.frame;
    final rasterData = frame.hasShaderTime
        ? [
            _ChartSlice(
              'Other raster',
              frame.rasterTime - frame.shaderDuration,
            ),
            _ChartSlice('Shader compilation', frame.shaderDuration),
          ]
        : [
            _ChartSlice('Raster', frame.rasterTime),
          ];

    rasterPhaseData = [
      _createPieChartSeries(
        id: 'raster',
        data: rasterData,
        outsideLabelColor: Theme.of(context).colorScheme.chartTextColor,
        colorFn: (phase, index) {
          final rasterColor = isRasterJanky ? rasterJankColor : mainRasterColor;
          final pallete = <Color>[
            rasterColor,
            if (frame.hasShaderTime) shaderCompilationColor.background,
          ];
          final color = pallete[index!];
          return charts.Color(
            r: color.red,
            g: color.green,
            b: color.blue,
            a: color.alpha,
          );
        },
      ),
    ];
  }

  charts.Series<_ChartSlice, int> _createPieChartSeries({
    required String id,
    required List<_ChartSlice> data,
    required charts.Color Function(_ChartSlice, int?) colorFn,
    required Color outsideLabelColor,
    charts.TextStyleSpec Function(_ChartSlice, int?)? insideLabelStyleFn,
  }) {
    return charts.Series<_ChartSlice, int>(
      id: id,
      domainFn: (slice, index) => index ?? data.indexOf(slice),
      measureFn: (slice, _) => slice.duration.inMicroseconds,
      data: data,
      colorFn: colorFn,
      labelAccessorFn: (slice, _) =>
          '${slice.title}: ${msText(slice.duration, allowZeroValues: false)}',
      insideLabelStyleAccessorFn: insideLabelStyleFn,
      outsideLabelStyleAccessorFn: (slice, _) {
        final color = charts.Color(
          r: outsideLabelColor.red,
          g: outsideLabelColor.green,
          b: outsideLabelColor.blue,
          a: outsideLabelColor.alpha,
        );
        return charts.TextStyleSpec(color: color);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: _PieChart(
            title: 'UI',
            data: uiPhaseData,
            hasData: frameAnalysis.hasUiData,
          ),
        ),
        Flexible(
          child: _PieChart(
            title: 'Raster',
            data: rasterPhaseData,
            hasData: frameAnalysis.hasRasterData,
          ),
        ),
      ],
    );
  }
}

class _PieChart extends StatelessWidget {
  const _PieChart({
    Key? key,
    required this.title,
    required this.data,
    required this.hasData,
  }) : super(key: key);

  final String title;

  final List<charts.Series<_ChartSlice, int>> data;

  final bool hasData;

  @override
  Widget build(BuildContext context) {
    if (hasData) {
      return charts.PieChart<int>(
        data,
        animate: true,
        defaultRenderer: charts.ArcRendererConfig(
          arcRendererDecorators: [charts.ArcLabelDecorator()],
        ),
      );
    }

    return _EmptyPie(title: title);
  }
}

class _EmptyPie extends StatelessWidget {
  const _EmptyPie({Key? key, required this.title}) : super(key: key);

  /// Margin for the [Container] to make this "empty pie" appear to be the same
  /// size as the other [PieChart] that will be its sibling.
  static const _pieMargin = 20.0;

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      margin: const EdgeInsets.all(_pieMargin),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.chartAccentColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text('$title data not available'),
    );
  }
}

class _ChartSlice {
  _ChartSlice(this.title, this.duration);

  final String title;

  final Duration duration;
}
