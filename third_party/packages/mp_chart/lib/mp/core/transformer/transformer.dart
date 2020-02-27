import 'package:flutter/rendering.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bubble_data_set.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_candle_data_set.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_line_data_set.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_scatter_data_set.dart';
import 'package:mp_chart/mp/core/entry/candle_entry.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/matrix4_utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';

class Transformer {
  /// matrix to map the values to the screen pixels
  Matrix4 _matrixValueToPx = Matrix4.identity();

  /// matrix for handling the different offsets of the chart
  Matrix4 _matrixOffset = Matrix4.identity();

  ViewPortHandler _viewPortHandler;

  Transformer(ViewPortHandler viewPortHandler) {
    this._viewPortHandler = viewPortHandler;
  }

  ViewPortHandler get viewPortHandler => _viewPortHandler;

  // ignore: unnecessary_getters_setters
  Matrix4 get matrixOffset => _matrixOffset;

  // ignore: unnecessary_getters_setters
  set matrixOffset(Matrix4 value) {
    _matrixOffset = value;
  }

  /// Prepares the matrix that Matrix4Utils.transforms values to pixels. Calculates the
  /// scale factors from the charts size and offsets.
  ///
  /// @param xChartMin
  /// @param deltaX
  /// @param deltaY
  /// @param yChartMin
  void prepareMatrixValuePx(
      double xChartMin, double deltaX, double deltaY, double yChartMin) {
    double scaleX = ((_viewPortHandler.contentWidth()) / deltaX);
    double scaleY = ((_viewPortHandler.contentHeight()) / deltaY);

    if (scaleX.isInfinite) {
      scaleX = 0;
    }
    if (scaleY.isInfinite) {
      scaleY = 0;
    }

    // setup all matrices
    _matrixValueToPx = Matrix4.identity();
    Matrix4Utils.postTranslate(_matrixValueToPx, -xChartMin, -yChartMin);
    Matrix4Utils.postScale(_matrixValueToPx, scaleX, -scaleY);
  }

  /// Prepares the matrix that contains all offsets.
  ///
  /// @param copyInverseed
  void prepareMatrixOffset(bool copyInverseed) {
    _matrixOffset = Matrix4.identity();

    // offset.postTranslate(mOffsetLeft, getHeight() - mOffsetBottom);

    if (!copyInverseed)
      Matrix4Utils.postTranslate(_matrixOffset, _viewPortHandler.offsetLeft(),
          _viewPortHandler.getChartHeight() - _viewPortHandler.offsetBottom());
    else {
      Matrix4Utils.postTranslate(_matrixOffset, _viewPortHandler.offsetLeft(),
          -_viewPortHandler.offsetTop());
      Matrix4Utils.postScale(_matrixOffset, 1.0, -1.0);
    }
  }

  List<double> _valuePointsForGenerateTransformedValuesScatter = List(1);

  /// Transforms an List of Entry into a double array containing the x and
  /// y values Matrix4Utils.transformed with all matrices for the SCATTERCHART.
  ///
  /// @param data
  /// @return
  List<double> generateTransformedValuesScatter(
      IScatterDataSet data, double phaseX, double phaseY, int from, int to) {
    int count = (((to - from) * phaseX + 1) * 2).toInt();
    count = count % 2 == 0 ? count : count - 1;

    if (_valuePointsForGenerateTransformedValuesScatter.length != count) {
      _valuePointsForGenerateTransformedValuesScatter = List(count);
    }
    List<double> valuePoints = _valuePointsForGenerateTransformedValuesScatter;

    for (int j = 0; j < count; j += 2) {
      Entry e = data.getEntryForIndex(j ~/ 2 + from);

      if (e != null) {
        valuePoints[j] = e.x;
        valuePoints[j + 1] = e.y * phaseY;
      } else {
        valuePoints[j] = 0;
        valuePoints[j + 1] = 0;
      }
    }

    Matrix4Utils.mapPoints(getValueToPixelMatrix(), valuePoints);

    return valuePoints;
  }

  List<double> _valuePointsForGenerateTransformedValuesBubble = List(1);

  /// Transforms an List of Entry into a double array containing the x and
  /// y values Matrix4Utils.transformed with all matrices for the BUBBLECHART.
  ///
  /// @param data
  /// @return
  List<double> generateTransformedValuesBubble(
      IBubbleDataSet data, double phaseY, int from, int to) {
    final int count =
        (to - from + 1) * 2; // (int) Math.ceil((to - from) * phaseX) * 2;

    if (_valuePointsForGenerateTransformedValuesBubble.length != count) {
      _valuePointsForGenerateTransformedValuesBubble = List(count);
    }
    List<double> valuePoints = _valuePointsForGenerateTransformedValuesBubble;

    for (int j = 0; j < count; j += 2) {
      Entry e = data.getEntryForIndex(j ~/ 2 + from);

      if (e != null) {
        valuePoints[j] = e.x;
        valuePoints[j + 1] = e.y * phaseY;
      } else {
        valuePoints[j] = 0;
        valuePoints[j + 1] = 0;
      }
    }

    Matrix4Utils.mapPoints(getValueToPixelMatrix(), valuePoints);

    return valuePoints;
  }

  List<double> _valuePointsForGenerateTransformedValuesLine = List(1);

  /// Transforms an List of Entry into a double array containing the x and
  /// y values Matrix4Utils.transformed with all matrices for the LINECHART.
  ///
  /// @param data
  /// @return
  List<double> generateTransformedValuesLine(
      ILineDataSet data, double phaseX, double phaseY, int min, int max) {
    final int count = ((((max - min) * phaseX) + 1).toInt() * 2);

    if (_valuePointsForGenerateTransformedValuesLine.length != count) {
      _valuePointsForGenerateTransformedValuesLine = List(count);
    }
    List<double> valuePoints = _valuePointsForGenerateTransformedValuesLine;

    for (int j = 0; j < count; j += 2) {
      Entry e = data.getEntryForIndex(j ~/ 2 + min);

      if (e != null) {
        valuePoints[j] = e.x;
        valuePoints[j + 1] = e.y * phaseY;
      } else {
        valuePoints[j] = 0;
        valuePoints[j + 1] = 0;
      }
    }

    Matrix4Utils.mapPoints(getValueToPixelMatrix(), valuePoints);

    return valuePoints;
  }

  List<double> _valuePointsForGenerateTransformedValuesCandle = List(1);

  /// Transforms an List of Entry into a double array containing the x and
  /// y values Matrix4Utils.transformed with all matrices for the CANDLESTICKCHART.
  ///
  /// @param data
  /// @return
  List<double> generateTransformedValuesCandle(
      ICandleDataSet data, double phaseX, double phaseY, int from, int to) {
    int count = (((to - from) * phaseX + 1) * 2).toInt();
    count = count % 2 == 0 ? count : count - 1;

    if (_valuePointsForGenerateTransformedValuesCandle.length != count) {
      _valuePointsForGenerateTransformedValuesCandle = List(count);
    }
    List<double> valuePoints = _valuePointsForGenerateTransformedValuesCandle;

    for (int j = 0; j < count; j += 2) {
      CandleEntry e = data.getEntryForIndex(j ~/ 2 + from);

      if (e != null) {
        valuePoints[j] = e.x;
        valuePoints[j + 1] = e.shadowHigh * phaseY;
      } else {
        valuePoints[j] = 0;
        valuePoints[j + 1] = 0;
      }
    }

    Matrix4Utils.mapPoints(getValueToPixelMatrix(), valuePoints);

    return valuePoints;
  }

  /// Transform an array of points with all matrices. VERY IMPORTANT: Keep
  /// matrix order "value-touch-offset" when Matrix4Utils.transforming.
  ///
  /// @param pts
  void pointValuesToPixel(List<double> pts) {
    Matrix4Utils.mapPoints(_matrixValueToPx, pts);
    Matrix4Utils.mapPoints(_viewPortHandler.getMatrixTouch(), pts);
    Matrix4Utils.mapPoints(_matrixOffset, pts);
  }

  /// Transform a rectangle with all matrices.
  ///
  /// @param r
  Rect rectValueToPixel(Rect r) {
    r = Matrix4Utils.mapRect(_matrixValueToPx, r);
    r = Matrix4Utils.mapRect(_viewPortHandler.getMatrixTouch(), r);
    r = Matrix4Utils.mapRect(_matrixOffset, r);
    return r;
  }

  /// Transform a rectangle with all matrices with potential animation phases.
  ///
  /// @param r
  /// @param phaseY
  Rect rectToPixelPhase(Rect r, double phaseY) {
    // multiply the height of the rect with the phase
    r = Rect.fromLTRB(r.left, r.top * phaseY, r.right, r.bottom * phaseY);

    r = Matrix4Utils.mapRect(_matrixValueToPx, r);
    r = Matrix4Utils.mapRect(_viewPortHandler.getMatrixTouch(), r);
    r = Matrix4Utils.mapRect(_matrixOffset, r);
    return r;
  }

  Rect rectToPixelPhaseHorizontal(Rect r, double phaseY) {
    // multiply the height of the rect with the phase
    r = Rect.fromLTRB(r.left * phaseY, r.top, r.right * phaseY, r.bottom);

    r = Matrix4Utils.mapRect(_matrixValueToPx, r);
    r = Matrix4Utils.mapRect(_viewPortHandler.getMatrixTouch(), r);
    r = Matrix4Utils.mapRect(_matrixOffset, r);
    return r;
  }

  /// Transform a rectangle with all matrices with potential animation phases.
  ///
  /// @param r
  Rect rectValueToPixelHorizontal1(Rect r) {
    r = Matrix4Utils.mapRect(_matrixValueToPx, r);
    r = Matrix4Utils.mapRect(_viewPortHandler.getMatrixTouch(), r);
    r = Matrix4Utils.mapRect(_matrixOffset, r);
    return r;
  }

  /// Transform a rectangle with all matrices with potential animation phases.
  ///
  /// @param r
  /// @param phaseY
  Rect rectValueToPixelHorizontal2(Rect r, double phaseY) {
    // multiply the height of the rect with the phase
    r = Rect.fromLTRB(r.left * phaseY, r.top, r.right * phaseY, r.bottom);

    r = Matrix4Utils.mapRect(_matrixValueToPx, r);
    r = Matrix4Utils.mapRect(_viewPortHandler.getMatrixTouch(), r);
    r = Matrix4Utils.mapRect(_matrixOffset, r);
    return r;
  }

  /// Matrix4Utils.transforms multiple rects with all matrices
  ///
  /// @param rects
  void rectValuesToPixel(List<Rect> rects) {
    Matrix4 m = getValueToPixelMatrix();

    for (int i = 0; i < rects.length; i++)
      rects[i] = Matrix4Utils.mapRect(m, rects[i]);
  }

  Matrix4 _pixelToValueMatrixBuffer = Matrix4.identity();

  /// Transforms the given array of touch positions (pixels) (x, y, x, y, ...)
  /// into values on the chart.
  ///
  /// @param pixels
  void pixelsToValue(List<double> pixels) {
    _pixelToValueMatrixBuffer = Matrix4.identity();
    Matrix4 tmp = _pixelToValueMatrixBuffer;
    // copyInverse all matrixes to convert back to the original value
    tmp.copyInverse(_matrixOffset);
    Matrix4Utils.mapPoints(tmp, pixels);

    tmp.copyInverse(_viewPortHandler.getMatrixTouch());
    Matrix4Utils.mapPoints(tmp, pixels);

    tmp.copyInverse(_matrixValueToPx);
    Matrix4Utils.mapPoints(tmp, pixels);
  }

  /// buffer for performance
  List<double> _ptsBuffer = List(2);

  /// Returns a recyclable MPPointD instance.
  /// returns the x and y values in the chart at the given touch point
  /// (encapsulated in a MPPointD). This method Matrix4Utils.transforms pixel coordinates to
  /// coordinates / values in the chart. This is the opposite method to
  /// getPixelForValues(...).
  ///
  /// @param x
  /// @param y
  /// @return
  MPPointD getValuesByTouchPoint1(double x, double y) {
    MPPointD result = MPPointD.getInstance1(0, 0);
    getValuesByTouchPoint2(x, y, result);
    return result;
  }

  void getValuesByTouchPoint2(double x, double y, MPPointD outputPoint) {
    _ptsBuffer[0] = x;
    _ptsBuffer[1] = y;

    pixelsToValue(_ptsBuffer);

    outputPoint.x = _ptsBuffer[0];
    outputPoint.y = _ptsBuffer[1];
  }

  /// Returns a recyclable MPPointD instance.
  /// Returns the x and y coordinates (pixels) for a given x and y value in the chart.
  ///
  /// @param x
  /// @param y
  /// @return
  MPPointD getPixelForValues(double x, double y) {
    _ptsBuffer[0] = x;
    _ptsBuffer[1] = y;

    pointValuesToPixel(_ptsBuffer);

    double xPx = _ptsBuffer[0];
    double yPx = _ptsBuffer[1];

    return MPPointD.getInstance1(xPx, yPx);
  }

  Matrix4 getValueMatrix() {
    return _matrixValueToPx;
  }

  Matrix4 getOffsetMatrix() {
    return _matrixOffset;
  }

  Matrix4 _mBuffer1 = Matrix4.identity();

  Matrix4 getValueToPixelMatrix() {
    _matrixValueToPx.copyInto(_mBuffer1);
    Matrix4Utils.postConcat(_mBuffer1, _viewPortHandler.matrixTouch);
    Matrix4Utils.postConcat(_mBuffer1, _matrixOffset);
    return _mBuffer1;
  }

  Matrix4 _mBuffer2 = Matrix4.identity();

  Matrix4 getPixelToValueMatrix() {
    _mBuffer2.copyInverse(getValueToPixelMatrix());
    return _mBuffer2;
  }
}
