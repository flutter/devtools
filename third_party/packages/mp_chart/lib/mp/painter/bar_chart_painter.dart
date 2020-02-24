import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/axis/x_axis.dart';
import 'package:mp_chart/mp/core/axis/y_axis.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/data/bar_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bar_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/bar_data_provider.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/entry/bar_entry.dart';
import 'package:mp_chart/mp/core/enums/axis_dependency.dart';
import 'package:mp_chart/mp/core/functions.dart';
import 'package:mp_chart/mp/core/highlight/bar_highlighter.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/legend/legend.dart';
import 'package:mp_chart/mp/core/marker/i_marker.dart';
import 'package:mp_chart/mp/core/render/bar_chart_renderer.dart';
import 'package:mp_chart/mp/core/render/legend_renderer.dart';
import 'package:mp_chart/mp/core/render/x_axis_renderer.dart';
import 'package:mp_chart/mp/core/render/y_axis_renderer.dart';
import 'package:mp_chart/mp/core/chart_trans_listener.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/painter/bar_line_chart_painter.dart';

class BarChartPainter extends BarLineChartBasePainter<BarData>
    implements BarDataProvider {
  /// flag that indicates whether the highlight should be full-bar oriented, or single-value?
  final bool _highlightFullBarEnabled;

  /// if set to true, all values are drawn above their bars, instead of below their top
  final bool _drawValueAboveBar;

  /// if set to true, a grey area is drawn behind each bar that indicates the maximum value
  final bool _drawBarShadow;

  final bool _fitBars;

  BarChartPainter(
      BarData data,
      Animator animator,
      ViewPortHandler viewPortHandler,
      double maxHighlightDistance,
      bool highLightPerTapEnabled,
      double extraLeftOffset,
      double extraTopOffset,
      double extraRightOffset,
      double extraBottomOffset,
      IMarker marker,
      Description desc,
      bool drawMarkers,
      Color infoBgColor,
      TextPainter infoPainter,
      TextPainter descPainter,
      XAxis xAxis,
      Legend legend,
      LegendRenderer legendRenderer,
      DataRendererSettingFunction rendererSettingFunction,
      OnChartValueSelectedListener selectedListener,
      int maxVisibleCount,
      bool autoScaleMinMaxEnabled,
      bool pinchZoomEnabled,
      bool doubleTapToZoomEnabled,
      bool highlightPerDragEnabled,
      bool dragXEnabled,
      bool dragYEnabled,
      bool scaleXEnabled,
      bool scaleYEnabled,
      Paint gridBackgroundPaint,
      Paint backgroundPaint,
      Paint borderPaint,
      bool drawGridBackground,
      bool drawBorders,
      bool clipValuesToContent,
      double minOffset,
      bool keepPositionOnRotation,
      OnDrawListener drawListener,
      YAxis axisLeft,
      YAxis axisRight,
      YAxisRenderer axisRendererLeft,
      YAxisRenderer axisRendererRight,
      Transformer leftAxisTransformer,
      Transformer rightAxisTransformer,
      XAxisRenderer xAxisRenderer,
      Matrix4 zoomMatrixBuffer,
      bool customViewPortEnabled,
      bool highlightFullBarEnabled,
      bool drawValueAboveBar,
      bool drawBarShadow,
      bool fitBars,
      ChartTransListener chartTransListener)
      : _highlightFullBarEnabled = highlightFullBarEnabled,
        _drawValueAboveBar = drawValueAboveBar,
        _drawBarShadow = drawBarShadow,
        _fitBars = fitBars,
        super(
            data,
            animator,
            viewPortHandler,
            maxHighlightDistance,
            highLightPerTapEnabled,
            extraLeftOffset,
            extraTopOffset,
            extraRightOffset,
            extraBottomOffset,
            marker,
            desc,
            drawMarkers,
            infoBgColor,
            infoPainter,
            descPainter,
            xAxis,
            legend,
            legendRenderer,
            rendererSettingFunction,
            selectedListener,
            maxVisibleCount,
            autoScaleMinMaxEnabled,
            pinchZoomEnabled,
            doubleTapToZoomEnabled,
            highlightPerDragEnabled,
            dragXEnabled,
            dragYEnabled,
            scaleXEnabled,
            scaleYEnabled,
            gridBackgroundPaint,
            borderPaint,
            drawGridBackground,
            drawBorders,
            clipValuesToContent,
            minOffset,
            keepPositionOnRotation,
            drawListener,
            axisLeft,
            axisRight,
            axisRendererLeft,
            axisRendererRight,
            leftAxisTransformer,
            rightAxisTransformer,
            xAxisRenderer,
            zoomMatrixBuffer,
            customViewPortEnabled,
            backgroundPaint,
            chartTransListener);

  @override
  void initDefaultWithData() {
    super.initDefaultWithData();
    highlighter = BarHighlighter(this);
    renderer = BarChartRenderer(this, animator, viewPortHandler);
    xAxis?.spaceMin = (0.5);
    xAxis?.spaceMax = (0.5);
  }

  @override
  void calcMinMax() {
    if (_fitBars) {
      xAxis.calculate(getBarData().xMin - getBarData().barWidth / 2.0,
          getBarData().xMax + getBarData().barWidth / 2.0);
    } else {
      xAxis.calculate(getBarData().xMin, getBarData().xMax);
    }

    // calculate axis range (min / max) according to provided data
    axisLeft.calculate(getBarData().getYMin2(AxisDependency.LEFT),
        getBarData().getYMax2(AxisDependency.LEFT));
    axisRight.calculate(getBarData().getYMin2(AxisDependency.RIGHT),
        getBarData().getYMax2(AxisDependency.RIGHT));
  }

  /// Returns the Highlight object (contains x-index and DataSet index) of the selected value at the given touch
  /// point
  /// inside the BarChart.
  ///
  /// @param x
  /// @param y
  /// @return
  @override
  Highlight getHighlightByTouchPoint(double x, double y) {
    if (getBarData() == null) {
      return null;
    } else {
      Highlight h = highlighter.getHighlight(x, y);
      if (h == null || !isHighlightFullBarEnabled()) return h;

      // For isHighlightFullBarEnabled, remove stackIndex
      return Highlight(
          x: h.x,
          y: h.y,
          xPx: h.xPx,
          yPx: h.yPx,
          dataSetIndex: h.dataSetIndex,
          stackIndex: -1,
          axis: h.axis);
    }
  }

  /// The passed outputRect will be assigned the values of the bounding box of the specified Entry in the specified DataSet.
  /// The rect will be assigned Float.MIN_VALUE in all locations if the Entry could not be found in the charts data.
  ///
  /// @param e
  /// @return
  Rect getBarBounds(BarEntry e) {
    Rect bounds = Rect.zero;

    IBarDataSet set = getBarData().getDataSetForEntry(e);

    if (set == null) {
      bounds = Rect.fromLTRB(double.minPositive, double.minPositive,
          double.minPositive, double.minPositive);
      return bounds;
    }

    double y = e.y;
    double x = e.x;

    double barWidth = getBarData().barWidth;

    double left = x - barWidth / 2.0;
    double right = x + barWidth / 2.0;
    double top = y >= 0 ? y : 0;
    double bottom = y <= 0 ? y : 0;

    bounds = Rect.fromLTRB(left, top, right, bottom);

    return getTransformer(set.getAxisDependency()).rectValueToPixel(bounds);
  }

  /// returns true if drawing values above bars is enabled, false if not
  ///
  /// @return
  bool isDrawValueAboveBarEnabled() {
    return _drawValueAboveBar;
  }

  /// returns true if drawing shadows (maxvalue) for each bar is enabled, false if not
  ///
  /// @return
  bool isDrawBarShadowEnabled() {
    return _drawBarShadow;
  }

  /// @return true the highlight operation is be full-bar oriented, false if single-value
  @override
  bool isHighlightFullBarEnabled() {
    return _highlightFullBarEnabled;
  }

  /// Highlights the value at the given x-value in the given DataSet. Provide
  /// -1 as the dataSetIndex to undo all highlighting.
  ///
  /// @param x
  /// @param dataSetIndex
  /// @param stackIndex   the index inside the stack - only relevant for stacked entries
  void highlightValue(double x, int dataSetIndex, int stackIndex) {
    highlightValue6(
        Highlight(x: x, dataSetIndex: dataSetIndex, stackIndex: stackIndex),
        false);
  }

  /// Groups all BarDataSet objects this data object holds together by modifying the x-value of their entries.
  /// Previously set x-values of entries will be overwritten. Leaves space between bars and groups as specified
  /// by the parameters.
  /// Calls notifyDataSetChanged() afterwards.
  ///
  /// @param fromX      the starting point on the x-axis where the grouping should begin
  /// @param groupSpace the space between groups of bars in values (not pixels) e.g. 0.8f for bar width 1f
  /// @param barSpace   the space between individual bars in values (not pixels) e.g. 0.1f for bar width 1f
  void groupBars(double fromX, double groupSpace, double barSpace) {
    if (getBarData() == null) {
      throw Exception(
          "You need to set data for the chart before grouping bars.");
    } else {
      getBarData().groupBars(fromX, groupSpace, barSpace);
    }
  }

  @override
  BarData getBarData() {
    return getData();
  }
}
