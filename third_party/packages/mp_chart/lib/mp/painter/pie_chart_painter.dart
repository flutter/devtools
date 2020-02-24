import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/axis/x_axis.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/data/pie_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_pie_data_set.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/functions.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/highlight/pie_highlighter.dart';
import 'package:mp_chart/mp/core/legend/legend.dart';
import 'package:mp_chart/mp/core/marker/i_marker.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/render/legend_renderer.dart';
import 'package:mp_chart/mp/core/render/pie_chart_renderer.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/painter/pie_redar_chart_painter.dart';

class PieChartPainter extends PieRadarChartPainter<PieData> {
  /// flag indicating if entry labels should be drawn or not
  final bool _drawEntryLabels; // = true

  /// if true, the white hole inside the chart will be drawn
  final bool _drawHole; //  = true

  /// if true, the hole will see-through to the inner tips of the slices
  final bool _drawSlicesUnderHole; // = false

  /// if true, the values inside the piechart are drawn as percent values
  final bool _usePercentValues; // = false

  /// if true, the slices of the piechart are rounded
  final bool _drawRoundedSlices; // = false

  /// variable for the text that is drawn in the center of the pie-chart
  final String _centerText; // = ""

  /// indicates the size of the hole in the center of the piechart, default:
  /// radius / 2
  final double _holeRadiusPercent; // = 50

  /// the radius of the transparent circle next to the chart-hole in the center
  final double _transparentCircleRadiusPercent; //= 55

  /// if enabled, centertext is drawn
  final bool _drawCenterText; // = true

  final double _centerTextRadiusPercent; // = 100.0

  final double _maxAngle; // = 360

  /// Minimum angle to draw slices, this only works if there is enough room for all slices to have
  /// the minimum angle, default 0f.
  final double _minAngleForSlices; // = 0

  //////////////////////////

  /// rect object that represents the bounds of the piechart, needed for
  /// drawing the circle
  Rect _circleBox = Rect.zero;

  /// array that holds the width of each pie-slice in degrees
  List<double> _drawAngles = List(1);

  /// array that holds the absolute angle in degrees of each slice
  List<double> _absoluteAngles = List(1);

  /// Hole color
  Color _holeColor;

  MPPointF _centerTextOffset;

  TypeFace _centerTextTypeface;
  TypeFace _entryLabelTypeface;

  PieChartPainter(
      PieData data,
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
      double rotationAngle,
      double rawRotationAngle,
      bool rotateEnabled,
      double minOffset,
      bool drawEntryLabels,
      bool drawHole,
      bool drawSlicesUnderHole,
      bool usePercentValues,
      bool drawRoundedSlices,
      String centerText,
      double centerTextOffsetX,
      double centerTextOffsetY,
      TypeFace entryLabelTypeface,
      TypeFace centerTextTypeface,
      double holeRadiusPercent,
      double transparentCircleRadiusPercent,
      bool drawCenterText,
      double centerTextRadiusPercent,
      double maxAngle,
      double minAngleForSlices,
      Color backgroundColor,
      Color holeColor)
      : _drawEntryLabels = drawEntryLabels,
        _drawHole = drawHole,
        _drawSlicesUnderHole = drawSlicesUnderHole,
        _usePercentValues = usePercentValues,
        _drawRoundedSlices = drawRoundedSlices,
        _centerText = centerText,
        _holeRadiusPercent = holeRadiusPercent,
        _transparentCircleRadiusPercent = transparentCircleRadiusPercent,
        _drawCenterText = drawCenterText,
        _centerTextRadiusPercent = centerTextRadiusPercent,
        _maxAngle = maxAngle,
        _centerTextOffset =
            MPPointF.getInstance1(centerTextOffsetX, centerTextOffsetY),
        _minAngleForSlices = minAngleForSlices,
        _centerTextTypeface = centerTextTypeface,
        _entryLabelTypeface = entryLabelTypeface,
        _holeColor = holeColor,
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
            rotationAngle,
            rawRotationAngle,
            rotateEnabled,
            minOffset,
            backgroundColor);

  @override
  void initDefaultWithData() {
    super.initDefaultWithData();
    renderer = PieChartRenderer(this, animator, viewPortHandler,
        centerTextTypeface: _centerTextTypeface,
        entryLabelTypeface: _entryLabelTypeface);
    highlighter = PieHighlighter(this);
  }

  @override
  void onPaint(Canvas canvas, Size size) {
    super.onPaint(canvas, size);
    renderer.drawData(canvas);

    if (valuesToHighlight()) {
      renderer.drawHighlighted(canvas, indicesToHighlight);
    }

    renderer.drawExtras(canvas);

    renderer.drawValues(canvas);

    legendRenderer.renderLegend(canvas);

    drawDescription(canvas, size);

    drawMarkers(canvas);
  }

  @override
  void calculateOffsets() {
    super.calculateOffsets();
    // prevent nullpointer when no data set
    if (getData() == null) return;

    double diameter = getDiameter();
    double radius = diameter / 2;

    MPPointF c = getCenterOffsets();

    double shift = (getData() as PieData).getDataSet().getSelectionShift();

    // create the circle box that will contain the pie-chart (the bounds of
    // the pie-chart)
    _circleBox = Rect.fromLTRB(c.x - radius + shift, c.y - radius + shift,
        c.x + radius - shift, c.y + radius - shift);

    MPPointF.recycleInstance(c);
  }

  @override
  void calcMinMax() {
    calcAngles();
  }

  @override
  List<double> getMarkerPosition(Highlight highlight) {
    MPPointF center = getCenterCircleBox();
    double r = getRadius();

    double off = r / 10 * 3.6;

    if (isDrawHoleEnabled()) {
      off = (r - (r / 100 * getHoleRadius())) / 2;
    }

    r -= off; // offset to keep things inside the chart

    double rotationAngle = getRotationAngle();

    int entryIndex = highlight.x.toInt();

    // offset needed to center the drawn text in the slice
    double offset = _drawAngles[entryIndex] / 2;

    // calculate the text position
    double x = (r *
            cos(((rotationAngle + _absoluteAngles[entryIndex] - offset) *
                    animator.getPhaseY()) /
                180 *
                pi) +
        center.x);
    double y = (r *
            sin((rotationAngle + _absoluteAngles[entryIndex] - offset) *
                animator.getPhaseY() /
                180 *
                pi) +
        center.y);

    MPPointF.recycleInstance(center);
    return List()..add(x)..add(y);
  }

  /// calculates the needed angles for the chart slices
  void calcAngles() {
    int entryCount = getData().getEntryCount();

    if (_drawAngles.length != entryCount) {
      _drawAngles = List(entryCount);
    } else {
      for (int i = 0; i < entryCount; i++) {
        _drawAngles[i] = 0;
      }
    }
    if (_absoluteAngles.length != entryCount) {
      _absoluteAngles = List(entryCount);
    } else {
      for (int i = 0; i < entryCount; i++) {
        _absoluteAngles[i] = 0;
      }
    }

    double yValueSum = (getData() as PieData).getYValueSum();

    List<IPieDataSet> dataSets = getData().dataSets;

    bool hasMinAngle =
        _minAngleForSlices != 0 && entryCount * _minAngleForSlices <= _maxAngle;
    List<double> minAngles = List(entryCount);

    int cnt = 0;
    double offset = 0;
    double diff = 0;

    for (int i = 0; i < getData().getDataSetCount(); i++) {
      IPieDataSet set = dataSets[i];

      for (int j = 0; j < set.getEntryCount(); j++) {
        double drawAngle =
            calcAngle2(set.getEntryForIndex(j).y.abs(), yValueSum);

        if (hasMinAngle) {
          double temp = drawAngle - _minAngleForSlices;
          if (temp <= 0) {
            minAngles[cnt] = _minAngleForSlices;
            offset += -temp;
          } else {
            minAngles[cnt] = drawAngle;
            diff += temp;
          }
        }

        _drawAngles[cnt] = drawAngle;

        if (cnt == 0) {
          _absoluteAngles[cnt] = _drawAngles[cnt];
        } else {
          _absoluteAngles[cnt] = _absoluteAngles[cnt - 1] + _drawAngles[cnt];
        }

        cnt++;
      }
    }

    if (hasMinAngle) {
      // Correct bigger slices by relatively reducing their angles based on the total angle needed to subtract
      // This requires that `entryCount * _minAngleForSlices <= _maxAngle` be true to properly work!
      for (int i = 0; i < entryCount; i++) {
        minAngles[i] -= (minAngles[i] - _minAngleForSlices) / diff * offset;
        if (i == 0) {
          _absoluteAngles[0] = minAngles[0];
        } else {
          _absoluteAngles[i] = _absoluteAngles[i - 1] + minAngles[i];
        }
      }

      _drawAngles = minAngles;
    }
  }

  /// Checks if the given index is set to be highlighted.
  ///
  /// @param index
  /// @return
  bool needsHighlight(int index) {
    // no highlight
    if (!valuesToHighlight()) return false;
    for (int i = 0; i < indicesToHighlight.length; i++)

      // check if the xvalue for the given dataset needs highlight
      if (indicesToHighlight[i].x.toInt() == index) return true;

    return false;
  }

  /// calculates the needed angle for a given value
  ///
  /// @param value
  /// @return
  double calcAngle1(double value) {
    return calcAngle2(value, (getData() as PieData).getYValueSum());
  }

  /// calculates the needed angle for a given value
  ///
  /// @param value
  /// @param yValueSum
  /// @return
  double calcAngle2(double value, double yValueSum) {
    return value / yValueSum * _maxAngle;
  }

  @override
  int getIndexForAngle(double angle) {
    // take the current angle of the chart into consideration
    double a = Utils.getNormalizedAngle(angle - getRotationAngle());

    for (int i = 0; i < _absoluteAngles.length; i++) {
      if (_absoluteAngles[i] > a) return i;
    }

    return -1; // return -1 if no index found
  }

  /// Returns the index of the DataSet this x-index belongs to.
  ///
  /// @param xIndex
  /// @return
  int getDataSetIndexForIndex(int xIndex) {
    List<IPieDataSet> dataSets = getData().dataSets;

    for (int i = 0; i < dataSets.length; i++) {
      if (dataSets[i].getEntryForXValue2(xIndex.toDouble(), double.nan) != null)
        return i;
    }

    return -1;
  }

  /// returns an integer array of all the different angles the chart slices
  /// have the angles in the returned array determine how much space (of 360°)
  /// each slice takes
  ///
  /// @return
  List<double> getDrawAngles() {
    return _drawAngles;
  }

  /// returns the absolute angles of the different chart slices (where the
  /// slices end)
  ///
  /// @return
  List<double> getAbsoluteAngles() {
    return _absoluteAngles;
  }

  /// Returns true if the inner tips of the slices are visible behind the hole,
  /// false if not.
  ///
  /// @return true if slices are visible behind the hole.
  bool isDrawSlicesUnderHoleEnabled() {
    return _drawSlicesUnderHole;
  }

  /// returns true if the hole in the center of the pie-chart is set to be
  /// visible, false if not
  ///
  /// @return
  bool isDrawHoleEnabled() {
    return _drawHole;
  }

  /// returns the text that is drawn in the center of the pie-chart
  ///
  /// @return
  String getCenterText() {
    return _centerText;
  }

  /// returns true if drawing the center text is enabled
  ///
  /// @return
  bool isDrawCenterTextEnabled() {
    return _drawCenterText;
  }

  @override
  double getRequiredLegendOffset() {
    // ignore: null_aware_before_operator
    var offset = legendRenderer.legendLabelPaint.text?.style?.fontSize * 2.0;
    return offset == null ? Utils.convertDpToPixel(9) : offset;
  }

  @override
  double getRequiredBaseOffset() {
    return 0;
  }

  @override
  double getRadius() {
    if (_circleBox == null)
      return 0;
    else
      return min(_circleBox.width / 2.0, _circleBox.height / 2.0);
  }

  /// returns the circlebox, the boundingbox of the pie-chart slices
  ///
  /// @return
  Rect getCircleBox() {
    return _circleBox;
  }

  /// returns the center of the circlebox
  ///
  /// @return
  MPPointF getCenterCircleBox() {
    return MPPointF.getInstance1(_circleBox.center.dx, _circleBox.center.dy);
  }

  /// Returns the offset on the x- and y-axis the center text has in dp.
  ///
  /// @return
  MPPointF getCenterTextOffset() {
    return MPPointF.getInstance1(_centerTextOffset.x, _centerTextOffset.y);
  }

  /// Returns the size of the hole radius in percent of the total radius.
  ///
  /// @return
  double getHoleRadius() {
    return _holeRadiusPercent;
  }

  double getTransparentCircleRadius() {
    return _transparentCircleRadiusPercent;
  }

  /// Returns true if drawing the entry labels is enabled, false if not.
  ///
  /// @return
  bool isDrawEntryLabelsEnabled() {
    return _drawEntryLabels;
  }

  /// Returns true if the chart is set to draw each end of a pie-slice
  /// "rounded".
  ///
  /// @return
  bool isDrawRoundedSlicesEnabled() {
    return _drawRoundedSlices;
  }

  /// Returns true if using percentage values is enabled for the chart.
  ///
  /// @return
  bool isUsePercentValuesEnabled() {
    return _usePercentValues;
  }

  /// the rectangular radius of the bounding box for the center text, as a percentage of the pie
  /// hole
  /// default 1.f (100%)
  double getCenterTextRadiusPercent() {
    return _centerTextRadiusPercent;
  }

  Color getHoleColor() {
    return _holeColor;
  }
}
