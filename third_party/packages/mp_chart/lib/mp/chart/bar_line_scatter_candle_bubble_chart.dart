import 'package:flutter/widgets.dart';
import 'package:mp_chart/mp/chart/chart.dart';
import 'package:mp_chart/mp/chart/horizontal_bar_chart.dart';
import 'package:mp_chart/mp/controller/bar_line_scatter_candle_bubble_controller.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/highlight_utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';

abstract class BarLineScatterCandleBubbleChart<
    C extends BarLineScatterCandleBubbleController> extends Chart<C> {
  const BarLineScatterCandleBubbleChart(C controller) : super(controller);
}

class BarLineScatterCandleBubbleState<T extends BarLineScatterCandleBubbleChart>
    extends ChartState<T> {
  IDataSet _closestDataSetToTouch;

  Highlight lastHighlighted;
  double _curX = 0.0;
  double _curY = 0.0;
  double _scaleX = -1.0;
  double _scaleY = -1.0;
  bool _isZoom = false;

  MPPointF _getTrans(double x, double y) {
    ViewPortHandler vph = widget.controller.painter.viewPortHandler;

    double xTrans = x - vph.offsetLeft();
    double yTrans = 0.0;

    /// check if axis is inverted
    if (_inverted()) {
      yTrans = -(y - vph.offsetTop());
    } else {
      yTrans = -(widget.controller.painter.getMeasuredHeight() -
          y -
          vph.offsetBottom());
    }

    return MPPointF.getInstance1(xTrans, yTrans);
  }

  bool _inverted() {
    var res = (_closestDataSetToTouch == null &&
            widget.controller.painter.isAnyAxisInverted()) ||
        (_closestDataSetToTouch != null &&
            widget.controller.painter
                .isInverted(_closestDataSetToTouch.getAxisDependency()));
    return res;
  }

  @override
  void onTapDown(TapDownDetails detail) {
    _curX = detail.localPosition.dx;
    _curY = detail.localPosition.dy;
    _closestDataSetToTouch = widget.controller.painter.getDataSetByTouchPoint(
        detail.localPosition.dx, detail.localPosition.dy);
  }

  @override
  void onDoubleTap() {
    if (widget.controller.painter.doubleTapToZoomEnabled &&
        widget.controller.painter.getData().getEntryCount() > 0) {
      MPPointF trans = _getTrans(_curX, _curY);
      widget.controller.painter.zoom(
          widget.controller.painter.scaleXEnabled ? 1.4 : 1,
          widget.controller.painter.scaleYEnabled ? 1.4 : 1,
          trans.x,
          trans.y);
      setStateIfNotDispose();
      MPPointF.recycleInstance(trans);
    }
  }

  @override
  void onScaleEnd(ScaleEndDetails detail) {
    if (_isZoom) {
      _isZoom = false;
    }
    _scaleX = -1.0;
    _scaleY = -1.0;
  }

  @override
  void onScaleStart(ScaleStartDetails detail) {
    _curX = detail.localFocalPoint.dx;
    _curY = detail.localFocalPoint.dy;
  }

  @override
  void onScaleUpdate(ScaleUpdateDetails detail) {
    if (_scaleX == -1.0 && _scaleY == -1.0) {
      _scaleX = detail.horizontalScale;
      _scaleY = detail.verticalScale;
      return;
    }

    if (_scaleX == detail.horizontalScale && _scaleY == detail.verticalScale) {
      if (_isZoom) {
        return;
      }

      var dx = detail.localFocalPoint.dx - _curX;
      var dy = detail.localFocalPoint.dy - _curY;
      if (widget.controller.painter.dragYEnabled &&
          widget.controller.painter.dragXEnabled) {
        if (_inverted()) {
          /// if there is an inverted horizontalbarchart
          if (widget is HorizontalBarChart) {
            dx = -dx;
          } else {
            dy = -dy;
          }
        }
        widget.controller.painter.translate(dx, dy);
        setStateIfNotDispose();
      } else {
        if (widget.controller.painter.dragXEnabled) {
          if (_inverted()) {
            /// if there is an inverted horizontalbarchart
            if (widget is HorizontalBarChart) {
              dx = -dx;
            } else {
              dy = -dy;
            }
          }
          widget.controller.painter.translate(dx, 0.0);
          setStateIfNotDispose();
        } else if (widget.controller.painter.dragYEnabled) {
          if (_inverted()) {
            /// if there is an inverted horizontalbarchart
            if (widget is HorizontalBarChart) {
              dx = -dx;
            } else {
              dy = -dy;
            }
          }
          widget.controller.painter.translate(0.0, dy);
          setStateIfNotDispose();
        }
      }
      _curX = detail.localFocalPoint.dx;
      _curY = detail.localFocalPoint.dy;
    } else {
      var scaleX = detail.horizontalScale / _scaleX;
      var scaleY = detail.verticalScale / _scaleY;

      if (!_isZoom) {
        scaleX = detail.horizontalScale;
        scaleY = detail.verticalScale;
        _isZoom = true;
      }

      MPPointF trans = _getTrans(_curX, _curY);

      var h = widget.controller.painter.viewPortHandler;
      bool canZoomMoreX = false;
      bool canZoomMoreY = false;
      if (h != null) {
        canZoomMoreX = scaleX < 1 ? h.canZoomOutMoreX() : h.canZoomInMoreX();
        canZoomMoreY = scaleY < 1 ? h.canZoomOutMoreY() : h.canZoomInMoreY();
      }

      scaleX = (widget.controller.painter.scaleXEnabled && canZoomMoreX)
          ? scaleX
          : 1.0;
      scaleY = (widget.controller.painter.scaleYEnabled && canZoomMoreY)
          ? scaleY
          : 1.0;

      if (canZoomMoreX && canZoomMoreY) {
        widget.controller.painter.zoom(scaleX, scaleY, trans.x, trans.y);
        setStateIfNotDispose();
      } else {
        if (canZoomMoreX) {
          widget.controller.painter.zoom(scaleX, 1.0, trans.x, trans.y);
          setStateIfNotDispose();
        }
        if (canZoomMoreY) {
          widget.controller.painter.zoom(1.0, scaleY, trans.x, trans.y);
          setStateIfNotDispose();
        }
      }
      MPPointF.recycleInstance(trans);
    }
    _scaleX = detail.horizontalScale;
    _scaleY = detail.verticalScale;
    _curX = detail.localFocalPoint.dx;
    _curY = detail.localFocalPoint.dy;
  }

  @override
  void onSingleTapUp(TapUpDetails detail) {
    if (widget.controller.painter.highLightPerTapEnabled) {
      Highlight h = widget.controller.painter.getHighlightByTouchPoint(
          detail.localPosition.dx, detail.localPosition.dy);
      lastHighlighted = HighlightUtils.performHighlight(
          widget.controller.painter, h, lastHighlighted);
      setStateIfNotDispose();
    } else {
      lastHighlighted = null;
    }
  }

  @override
  void updatePainter() {
    if (widget.controller.painter.getData() != null &&
        widget.controller.painter.getData().dataSets != null &&
        widget.controller.painter.getData().dataSets.length > 0)
      widget.controller.painter.highlightValue6(lastHighlighted, false);
  }
}
