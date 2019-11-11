import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/matrix4_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class ViewPortHandler {
  /// matrix used for touch events
  final Matrix4 _matrixTouch = Matrix4.identity();

  /// this rectangle defines the area in which graph values can be drawn
  Rect _contentRect = Rect.zero;

  double _chartWidth = 0;
  double _chartHeight = 0;

  /// minimum scale value on the y-axis
  double _minScaleY = 1;

  /// maximum scale value on the y-axis
  double _maxScaleY = 1000;

  /// minimum scale value on the x-axis
  double _minScaleX = 1;

  /// maximum scale value on the x-axis
  double _maxScaleX = 1000;

  /// contains the current scale factor of the x-axis
  double _scaleX = 1;

  /// contains the current scale factor of the y-axis
  double _scaleY = 1;

  /// current translation (drag distance) on the x-axis
  double _transX = 0;

  /// current translation (drag distance) on the y-axis
  double _transY = 0;

  /// offset that allows the chart to be dragged over its bounds on the x-axis
  double _transOffsetX = 0;

  /// offset that allows the chart to be dragged over its bounds on the x-axis
  double _transOffsetY = 0;

  /// Constructor - don't forget calling setChartDimens(...)
  ViewPortHandler();

  Matrix4 get matrixTouch => _matrixTouch;

  Rect get contentRect => _contentRect;

  /// Sets the width and height of the chart.
  ///
  /// @param width
  /// @param height
  void setChartDimens(double width, double height) {
    double offsetLeft = this.offsetLeft();
    double offsetTop = this.offsetTop();
    double offsetRight = this.offsetRight();
    double offsetBottom = this.offsetBottom();

    _chartHeight = height;
    _chartWidth = width;

    restrainViewPort(offsetLeft, offsetTop, offsetRight, offsetBottom);
  }

  bool hasChartDimens() {
    if (_chartHeight > 0 && _chartWidth > 0)
      return true;
    else
      return false;
  }

  void restrainViewPort(double offsetLeft, double offsetTop, double offsetRight,
      double offsetBottom) {
    _contentRect = Rect.fromLTRB(offsetLeft, offsetTop,
        _chartWidth - offsetRight, _chartHeight - offsetBottom);
  }

  double offsetLeft() {
    return _contentRect.left;
  }

  double offsetRight() {
    return _chartWidth - _contentRect.right;
  }

  double offsetTop() {
    return _contentRect.top;
  }

  double offsetBottom() {
    return _chartHeight - _contentRect.bottom;
  }

  double contentTop() {
    return _contentRect.top;
  }

  double contentLeft() {
    return _contentRect.left;
  }

  double contentRight() {
    return _contentRect.right;
  }

  double contentBottom() {
    return _contentRect.bottom;
  }

  double contentWidth() {
    return _contentRect.width;
  }

  double contentHeight() {
    return _contentRect.height;
  }

  double chartWidth() => _chartWidth;

  double chartHeight() => _chartHeight;

  Rect getContentRect() {
    return _contentRect;
  }

  MPPointF getContentCenter() {
    return MPPointF.getInstance1(
        _contentRect.center.dx, _contentRect.center.dy);
  }

  double getChartHeight() {
    return _chartHeight;
  }

  double getChartWidth() {
    return _chartWidth;
  }

  /// Returns the smallest extension of the content rect (width or height).
  ///
  /// @return
  double getSmallestContentExtension() {
    return min(_contentRect.width, _contentRect.height);
  }

  /**
   * ################ ################ ################ ################
   */
  /** CODE BELOW THIS RELATED TO SCALING AND GESTURES */

  /// Zooms in by 1.4f, x and y are the coordinates (in pixels) of the zoom
  /// center.
  ///
  /// @param x
  /// @param y
  Matrix4 zoomIn1(double x, double y) {
    Matrix4 save = Matrix4.identity();
    zoomIn2(x, y, save);
    return save;
  }

  void zoomIn2(double x, double y, Matrix4 outputMatrix) {
    _matrixTouch.copyInto(outputMatrix);
    Matrix4Utils.postScaleByPoint(outputMatrix, 1.4, 1.4, x, y);
  }

  /// Zooms out by 0.7f, x and y are the coordinates (in pixels) of the zoom
  /// center.
  Matrix4 zoomOut1(double x, double y) {
    Matrix4 save = Matrix4.identity();
    zoomOut2(x, y, save);
    return save;
  }

  void zoomOut2(double x, double y, Matrix4 outputMatrix) {
    _matrixTouch.copyInto(outputMatrix);
    Matrix4Utils.postScaleByPoint(outputMatrix, 0.7, 0.7, x, y);
  }

  /// Zooms out to original size.
  /// @param outputMatrix
  void resetZoom(Matrix4 outputMatrix) {
    _matrixTouch.copyInto(outputMatrix);
    Matrix4Utils.postScaleByPoint(outputMatrix, 1.0, 1.0, 0.0, 0.0);
  }

  /// Post-scales by the specified scale factors.
  ///
  /// @param scaleX
  /// @param scaleY
  /// @return
  Matrix4 zoom1(double scaleX, double scaleY) {
    Matrix4 save = Matrix4.identity();
    zoom2(scaleX, scaleY, save);
    return save;
  }

  void zoom2(double scaleX, double scaleY, Matrix4 outputMatrix) {
    _matrixTouch.copyInto(outputMatrix);
    Matrix4Utils.postScale(outputMatrix, scaleX, scaleY);
  }

  /// Post-scales by the specified scale factors. x and y is pivot.
  ///
  /// @param scaleX
  /// @param scaleY
  /// @param x
  /// @param y
  /// @return
  Matrix4 zoom3(double scaleX, double scaleY, double x, double y) {
    Matrix4 save = Matrix4.identity();
    zoom4(scaleX, scaleY, x, y, save);
    return save;
  }

  void zoom4(
      double scaleX, double scaleY, double x, double y, Matrix4 outputMatrix) {
    _matrixTouch.copyInto(outputMatrix);
    Matrix4Utils.postScaleByPoint(outputMatrix, scaleX, scaleY, x, y);
  }

  /// Sets the scale factor to the specified values.
  ///
  /// @param scaleX
  /// @param scaleY
  /// @return
  Matrix4 setZoom1(double scaleX, double scaleY) {
    Matrix4 save = Matrix4.identity();
    setZoom2(scaleX, scaleY, save);
    return save;
  }

  void setZoom2(double scaleX, double scaleY, Matrix4 outputMatrix) {
    _matrixTouch.copyInto(outputMatrix);
    Matrix4Utils.setScale(outputMatrix, scaleX, scaleY);
  }

  /// Sets the scale factor to the specified values. x and y is pivot.
  ///
  /// @param scaleX
  /// @param scaleY
  /// @param x
  /// @param y
  /// @return
  Matrix4 setZoom3(double scaleX, double scaleY, double x, double y) {
    Matrix4 save = Matrix4.identity();
    save.add(_matrixTouch);
    Matrix4Utils.setScaleByPoint(save, scaleX, scaleY, x, y);
    return save;
  }

  List<double> valsBufferForFitScreen = List(16);

  /// Resets all zooming and dragging and makes the chart fit exactly it's
  /// bounds.
  Matrix4 fitScreen1() {
    Matrix4 save = Matrix4.identity();
    fitScreen2(save);
    return save;
  }

  /// Resets all zooming and dragging and makes the chart fit exactly it's
  /// bounds.  Output Matrix is available for those who wish to cache the object.
  void fitScreen2(Matrix4 outputMatrix) {
    _minScaleX = 1;
    _minScaleY = 1;

    _matrixTouch.copyInto(outputMatrix);

    outputMatrix
      ..storage[3] = 0
      ..storage[7] = 0
      ..storage[0] = 1
      ..storage[5] = 1;
    List<double> vals = valsBufferForFitScreen;
    for (int i = 0; i < 16; i++) {
      vals[i] = outputMatrix.storage[i];
    }
  }

  /// Post-translates to the specified points.  Less Performant.
  ///
  /// @param transformedPts
  /// @return
  Matrix4 translate1(List<double> transformedPts) {
    Matrix4 save = Matrix4.identity();
    translate2(transformedPts, save);
    return save;
  }

  /// Post-translates to the specified points.  Output matrix allows for caching objects.
  ///
  /// @param transformedPts
  /// @return
  void translate2(final List<double> transformedPts, Matrix4 outputMatrix) {
    _matrixTouch.copyInto(outputMatrix);
    final double x = transformedPts[0] - offsetLeft();
    final double y = transformedPts[1] - offsetTop();
    Matrix4Utils.postTranslate(outputMatrix, -x, -y);
  }

  Matrix4 mCenterViewPortMatrixBuffer = Matrix4.identity();

  /// Centers the viewport around the specified position (x-index and y-value)
  /// in the chart. Centering the viewport outside the bounds of the chart is
  /// not possible. Makes most sense in combination with the
  /// setScaleMinima(...) method.
  ///
  /// @param transformedPts the position to center view viewport to
  /// @param view
  /// @return save
  void centerViewPort(final List<double> transformedPts) {
    mCenterViewPortMatrixBuffer = Matrix4.identity();
    Matrix4 save = mCenterViewPortMatrixBuffer;
    _matrixTouch.copyInto(save);

    final double x = transformedPts[0] - offsetLeft();
    final double y = transformedPts[1] - offsetTop();

    Matrix4Utils.postTranslate(save, -x, -y);

    refresh(save);
  }

  List<double> matrixBuffer = List(16);

  /// call this method to refresh the graph with a given matrix
  ///
  /// @param newMatrix
  /// @return
  Matrix4 refresh(Matrix4 newMatrix) {
    newMatrix.copyInto(_matrixTouch);
    // make sure scale and translation are within their bounds
    limitTransAndScale(_matrixTouch, _contentRect);
    _matrixTouch.copyInto(newMatrix);
    return newMatrix;
  }

  /// limits the maximum scale and X translation of the given matrix
  ///
  /// @param matrix
  void limitTransAndScale(Matrix4 matrix, Rect content) {
    for (int i = 0; i < 16; i++) {
      matrixBuffer[i] = matrix.storage[i];
    }

    double curTransX = matrixBuffer[12];
    double curScaleX = matrixBuffer[0];

    double curTransY = matrixBuffer[13];
    double curScaleY = matrixBuffer[5];

    // min scale-x is 1f
    _scaleX = min(max(_minScaleX, curScaleX), _maxScaleX);

    // min scale-y is 1f
    _scaleY = min(max(_minScaleY, curScaleY), _maxScaleY);

    double width = 0;
    double height = 0;

    if (content != null) {
      width = content.width;
      height = content.height;
    }

    double maxTransX = -width * (_scaleX - 1);
    _transX = min(max(curTransX, maxTransX - _transOffsetX), _transOffsetX);

    double maxTransY = height * (_scaleY - 1);
    _transY = max(min(curTransY, maxTransY + _transOffsetY), -_transOffsetY);

    matrixBuffer[12] = _transX;
    matrixBuffer[0] = _scaleX;

    matrixBuffer[13] = _transY;
    matrixBuffer[5] = _scaleY;

    for (int i = 0; i < 16; i++) {
      matrix.storage[i] = matrixBuffer[i];
    }
  }

  /// Sets the minimum scale factor for the x-axis
  ///
  /// @param xScale
  void setMinimumScaleX(double xScale) {
    if (xScale < 1) xScale = 1;
    _minScaleX = xScale;
    limitTransAndScale(_matrixTouch, _contentRect);
  }

  /// Sets the maximum scale factor for the x-axis
  ///
  /// @param xScale
  void setMaximumScaleX(double xScale) {
    if (xScale == 0) xScale = double.maxFinite;
    _maxScaleX = xScale;
    limitTransAndScale(_matrixTouch, _contentRect);
  }

  /// Sets the minimum and maximum scale factors for the x-axis
  ///
  /// @param minScaleX
  /// @param maxScaleX
  void setMinMaxScaleX(double minScaleX, double maxScaleX) {
    if (minScaleX < 1) minScaleX = 1;

    if (maxScaleX == 0) maxScaleX = double.maxFinite;

    _minScaleX = minScaleX;
    _maxScaleX = maxScaleX;
    limitTransAndScale(_matrixTouch, _contentRect);
  }

  /// Sets the minimum scale factor for the y-axis
  ///
  /// @param yScale
  void setMinimumScaleY(double yScale) {
    if (yScale < 1) yScale = 1;
    _minScaleY = yScale;
    limitTransAndScale(_matrixTouch, _contentRect);
  }

  /// Sets the maximum scale factor for the y-axis
  ///
  /// @param yScale
  void setMaximumScaleY(double yScale) {
    if (yScale == 0) yScale = double.maxFinite;
    _maxScaleY = yScale;
    limitTransAndScale(_matrixTouch, _contentRect);
  }

  void setMinMaxScaleY(double minScaleY, double maxScaleY) {
    if (minScaleY < 1) minScaleY = 1;

    if (maxScaleY == 0) maxScaleY = double.maxFinite;

    _minScaleY = minScaleY;
    _maxScaleY = maxScaleY;
    limitTransAndScale(_matrixTouch, _contentRect);
  }

  /// Returns the charts-touch matrix used for translation and scale on touch.
  ///
  /// @return
  Matrix4 getMatrixTouch() {
    return _matrixTouch;
  }

  /**
   * ################ ################ ################ ################
   */

  /// BELOW METHODS FOR BOUNDS CHECK

  bool isInBoundsX(double x) {
    return isInBoundsLeft(x) && isInBoundsRight(x);
  }

  bool isInBoundsY(double y) {
    return isInBoundsTop(y) && isInBoundsBottom(y);
  }

  bool isInBounds(double x, double y) {
    return isInBoundsX(x) && isInBoundsY(y);
  }

  bool isInBoundsLeft(double x) {
    if (x == null) return false;
    return _contentRect.left <= x + 1;
  }

  bool isInBoundsRight(double x) {
    if (x == null) return false;
    x = ((x * 100.0).toInt()) / 100.0;
    return _contentRect.right >= x - 1;
  }

  bool isInBoundsTop(double y) {
    if (y == null) return false;
    return _contentRect.top <= y;
  }

  bool isInBoundsBottom(double y) {
    if (y == null) return false;
    y = ((y * 100.0).toInt()) / 100.0;
    return _contentRect.bottom >= y;
  }

  /// returns the current x-scale factor
  double getScaleX() {
    return _scaleX;
  }

  /// returns the current y-scale factor
  double getScaleY() {
    return _scaleY;
  }

  double getMinScaleX() {
    return _minScaleX;
  }

  double getMaxScaleX() {
    return _maxScaleX;
  }

  double getMinScaleY() {
    return _minScaleY;
  }

  double getMaxScaleY() {
    return _maxScaleY;
  }

  /// Returns the translation (drag / pan) distance on the x-axis
  ///
  /// @return
  double getTransX() {
    return _transX;
  }

  /// Returns the translation (drag / pan) distance on the y-axis
  ///
  /// @return
  double getTransY() {
    return _transY;
  }

  /// if the chart is fully zoomed out, return true
  ///
  /// @return
  bool isFullyZoomedOut() {
    return isFullyZoomedOutX() && isFullyZoomedOutY();
  }

  /// Returns true if the chart is fully zoomed out on it's y-axis (vertical).
  ///
  /// @return
  bool isFullyZoomedOutY() {
    return !(_scaleY > _minScaleY || _minScaleY > 1);
  }

  /// Returns true if the chart is fully zoomed out on it's x-axis
  /// (horizontal).
  ///
  /// @return
  bool isFullyZoomedOutX() {
    return !(_scaleX > _minScaleX || _minScaleX > 1);
  }

  /// Set an offset in dp that allows the user to drag the chart over it's
  /// bounds on the x-axis.
  ///
  /// @param offset
  void setDragOffsetX(double offset) {
    _transOffsetX = Utils.convertDpToPixel(offset);
  }

  /// Set an offset in dp that allows the user to drag the chart over it's
  /// bounds on the y-axis.
  ///
  /// @param offset
  void setDragOffsetY(double offset) {
    _transOffsetY = Utils.convertDpToPixel(offset);
  }

  /// Returns true if both drag offsets (x and y) are zero or smaller.
  ///
  /// @return
  bool hasNoDragOffset() {
    return _transOffsetX <= 0 && _transOffsetY <= 0;
  }

  /// Returns true if the chart is not yet fully zoomed out on the x-axis
  ///
  /// @return
  bool canZoomOutMoreX() {
    return _scaleX > _minScaleX;
  }

  /// Returns true if the chart is not yet fully zoomed in on the x-axis
  ///
  /// @return
  bool canZoomInMoreX() {
    return _scaleX < _maxScaleX;
  }

  /// Returns true if the chart is not yet fully zoomed out on the y-axis
  ///
  /// @return
  bool canZoomOutMoreY() {
    return _scaleY > _minScaleY;
  }

  /// Returns true if the chart is not yet fully zoomed in on the y-axis
  ///
  /// @return
  bool canZoomInMoreY() {
    return _scaleY < _maxScaleY;
  }
}

class HorizontalViewPortHandler extends ViewPortHandler {}
