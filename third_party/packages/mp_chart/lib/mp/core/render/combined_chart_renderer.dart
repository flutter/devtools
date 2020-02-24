import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/data/chart_data.dart';
import 'package:mp_chart/mp/core/data/combined_data.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/render/bar_chart_renderer.dart';
import 'package:mp_chart/mp/core/render/bubble_chart_renderer.dart';
import 'package:mp_chart/mp/core/render/candle_stick_chart_renderer.dart';
import 'package:mp_chart/mp/core/render/data_renderer.dart';
import 'package:mp_chart/mp/core/render/line_chart_renderer.dart';
import 'package:mp_chart/mp/core/render/scatter_chart_renderer.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/painter/combined_chart_painter.dart';
import 'package:mp_chart/mp/painter/painter.dart';

class CombinedChartRenderer extends DataRenderer {
  /// all rederers for the different kinds of data this combined-renderer can draw
  List<DataRenderer> _renderers = List<DataRenderer>();

  ChartPainter _painter;

  CombinedChartRenderer(CombinedChartPainter chart, Animator animator,
      ViewPortHandler viewPortHandler)
      : super(animator, viewPortHandler) {
    _painter = chart;
    createRenderers();
  }

  /// Creates the renderers needed for this combined-renderer in the required order. Also takes the DrawOrder into
  /// consideration.
  void createRenderers() {
    _renderers.clear();

    CombinedChartPainter chart = (_painter as CombinedChartPainter);
    if (chart == null) return;

    List<DrawOrder> orders = chart.getDrawOrder();

    for (DrawOrder order in orders) {
      switch (order) {
        case DrawOrder.BAR:
          if (chart.getBarData() != null)
            _renderers.add(BarChartRenderer(chart, animator, viewPortHandler));
          break;
        case DrawOrder.BUBBLE:
          if (chart.getBubbleData() != null)
            _renderers
                .add(BubbleChartRenderer(chart, animator, viewPortHandler));
          break;
        case DrawOrder.LINE:
          if (chart.getLineData() != null)
            _renderers.add(LineChartRenderer(chart, animator, viewPortHandler));
          break;
        case DrawOrder.CANDLE:
          if (chart.getCandleData() != null)
            _renderers.add(
                CandleStickChartRenderer(chart, animator, viewPortHandler));
          break;
        case DrawOrder.SCATTER:
          if (chart.getScatterData() != null)
            _renderers
                .add(ScatterChartRenderer(chart, animator, viewPortHandler));
          break;
      }
    }
  }

  @override
  void initBuffers() {
    for (DataRenderer renderer in _renderers) renderer.initBuffers();
  }

  @override
  void drawData(Canvas c) {
    for (DataRenderer renderer in _renderers) renderer.drawData(c);
  }

  @override
  void drawValue(Canvas c, String valueText, double x, double y, Color color) {}

  @override
  void drawValues(Canvas c) {
    for (DataRenderer renderer in _renderers) renderer.drawValues(c);
  }

  @override
  void drawExtras(Canvas c) {
    for (DataRenderer renderer in _renderers) renderer.drawExtras(c);
  }

  List<Highlight> mHighlightBuffer = List<Highlight>();

  @override
  void drawHighlighted(Canvas c, List<Highlight> indices) {
    ChartPainter chart = _painter;
    if (chart == null) return;

    for (DataRenderer renderer in _renderers) {
      ChartData data;

      if (renderer is BarChartRenderer)
        data = renderer.provider.getBarData();
      else if (renderer is LineChartRenderer)
        data = renderer.provider.getLineData();
      else if (renderer is CandleStickChartRenderer)
        data = renderer.porvider.getCandleData();
      else if (renderer is ScatterChartRenderer)
        data = renderer.provider.getScatterData();
      else if (renderer is BubbleChartRenderer)
        data = renderer.provider.getBubbleData();

      int dataIndex = data == null
          ? -1
          : (chart.getData() as CombinedData).getAllData().indexOf(data);

      mHighlightBuffer.clear();

      for (Highlight h in indices) {
        if (h.dataIndex == dataIndex || h.dataIndex == -1)
          mHighlightBuffer.add(h);
      }

      renderer.drawHighlighted(c, mHighlightBuffer);
    }
  }

  /// Returns the sub-renderer object at the specified index.
  ///
  /// @param index
  /// @return
  DataRenderer getSubRenderer(int index) {
    if (index >= _renderers.length || index < 0)
      return null;
    else
      return _renderers[index];
  }

  /// Returns all sub-renderers.
  ///
  /// @return
  List<DataRenderer> getSubRenderers() {
    return _renderers;
  }

  void setSubRenderers(List<DataRenderer> renderers) {
    this._renderers = renderers;
  }
}
