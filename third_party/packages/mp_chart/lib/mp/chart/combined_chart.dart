import 'package:flutter/widgets.dart';
import 'package:mp_chart/mp/chart/bar_line_scatter_candle_bubble_chart.dart';
import 'package:mp_chart/mp/chart/chart.dart';
import 'package:mp_chart/mp/controller/combined_chart_controller.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/touch_listener.dart';
import 'package:mp_chart/mp/core/utils/highlight_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:optimized_gesture_detector/details.dart';
import 'package:optimized_gesture_detector/direction.dart';

class CombinedChart
    extends BarLineScatterCandleBubbleChart<CombinedChartController> {
  const CombinedChart(CombinedChartController controller) : super(controller);
}

class CombinedChartState extends ChartState<CombinedChart> {
  @override
  void updatePainter() {
    widget.controller.painter.highlightValue6(_lastHighlighted, false);
  }

  IDataSet _closestDataSetToTouch;

  double _curX = 0.0;
  double _curY = 0.0;
  double _scale = -1.0;

  Highlight _lastHighlighted;

  MPPointF _getTrans(double x, double y) {
    return Utils.local2Chart(widget.controller, x, y, inverted: _inverted());
  }

  MPPointF _getTouchValue(
      TouchValueType type, double screenX, double screenY, double localX, localY) {
    if (type == TouchValueType.CHART) {
      return _getTrans(localX, localY);
    } else if (type == TouchValueType.SCREEN) {
      return MPPointF.getInstance1(screenX, screenY);
    } else {
      return MPPointF.getInstance1(localX, localY);
    }
  }

  bool _inverted() {
    return (_closestDataSetToTouch == null &&
            widget.controller.painter.isAnyAxisInverted()) ||
        (_closestDataSetToTouch != null &&
            widget.controller.painter
                .isInverted(_closestDataSetToTouch.getAxisDependency()));
  }

  @override
  void onTapDown(TapDownDetails details) {
    widget.controller.stopDeceleration();
    _curX = details.localPosition.dx;
    _curY = details.localPosition.dy;
    _closestDataSetToTouch = widget.controller.painter.getDataSetByTouchPoint(
        details.localPosition.dx, details.localPosition.dy);
    if(widget.controller.touchEventListener != null){
      var point = _getTouchValue(
          widget.controller.touchEventListener.valueType(),
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.localPosition.dx,
          details.localPosition.dy);
      widget.controller.touchEventListener.onTapDown(point.x, point.y);
    }
  }

  @override
  void onSingleTapUp(TapUpDetails details) {
    if (widget.controller.painter.highlightPerDragEnabled) {
      Highlight h = widget.controller.painter.getHighlightByTouchPoint(
          details.localPosition.dx, details.localPosition.dy);
      _lastHighlighted = HighlightUtils.performHighlight(
          widget.controller.painter, h, _lastHighlighted);
      setStateIfNotDispose();
    } else {
      _lastHighlighted = null;
    }
    if(widget.controller.touchEventListener != null){
      var point = _getTouchValue(
          widget.controller.touchEventListener.valueType(),
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.localPosition.dx,
          details.localPosition.dy);
      widget.controller.touchEventListener.onSingleTapUp(point.x, point.y);
    }
  }

  @override
  void onDoubleTapUp(TapUpDetails details) {
    widget.controller.stopDeceleration();
    if (widget.controller.painter.doubleTapToZoomEnabled &&
        widget.controller.painter.getData().getEntryCount() > 0) {
      MPPointF trans =
          _getTrans(details.localPosition.dx, details.localPosition.dy);
      widget.controller.painter.zoom(
          widget.controller.painter.scaleXEnabled ? 1.2 : 1,
          widget.controller.painter.scaleYEnabled ? 1.2 : 1,
          trans.x,
          trans.y);
      setStateIfNotDispose();
      MPPointF.recycleInstance(trans);
    }
    if(widget.controller.touchEventListener != null){
      var point = _getTouchValue(
          widget.controller.touchEventListener.valueType(),
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.localPosition.dx,
          details.localPosition.dy);
      widget.controller.touchEventListener.onDoubleTapUp(point.x, point.y);
    }
  }

  @override
  void onMoveStart(OpsMoveStartDetails details) {
    widget.controller.stopDeceleration();
    _curX = details.localPoint.dx;
    _curY = details.localPoint.dy;
    if(widget.controller.touchEventListener != null){
      var point = _getTouchValue(
          widget.controller.touchEventListener.valueType(),
          details.globalPoint.dx,
          details.globalPoint.dy,
          details.localPoint.dx,
          details.localPoint.dy);
      widget.controller.touchEventListener.onMoveStart(point.x, point.y);
    }
  }

  @override
  void onMoveUpdate(OpsMoveUpdateDetails details) {
    var dx = details.localPoint.dx - _curX;
    var dy = details.localPoint.dy - _curY;
    if (widget.controller.painter.dragYEnabled &&
        widget.controller.painter.dragXEnabled) {
      if (_inverted()) {
        dy = -dy;
      }
      widget.controller.painter.translate(dx, dy);
      if(widget.controller.touchEventListener != null){
        var point = _getTouchValue(
            widget.controller.touchEventListener.valueType(),
            details.globalPoint.dx,
            details.globalPoint.dy,
            details.localPoint.dx,
            details.localPoint.dy);
        widget.controller.touchEventListener.onMoveUpdate(point.x, point.y);
      }
      setStateIfNotDispose();
    } else {
      if (widget.controller.painter.dragXEnabled) {
        widget.controller.painter.translate(dx, 0.0);
        if(widget.controller.touchEventListener != null){
          var point = _getTouchValue(
              widget.controller.touchEventListener.valueType(),
              details.globalPoint.dx,
              details.globalPoint.dy,
              details.localPoint.dx,
              details.localPoint.dy);
          widget.controller.touchEventListener.onMoveUpdate(point.x, point.y);
        }
        setStateIfNotDispose();
      } else if (widget.controller.painter.dragYEnabled) {
        if (_inverted()) {
          dy = -dy;
        }
        widget.controller.painter.translate(0.0, dy);
        if(widget.controller.touchEventListener != null){
          var point = _getTouchValue(
              widget.controller.touchEventListener.valueType(),
              details.globalPoint.dx,
              details.globalPoint.dy,
              details.localPoint.dx,
              details.localPoint.dy);
          widget.controller.touchEventListener.onMoveUpdate(point.x, point.y);
        }
        setStateIfNotDispose();
      }
    }
    _curX = details.localPoint.dx;
    _curY = details.localPoint.dy;
  }

  @override
  void onMoveEnd(OpsMoveEndDetails details) {
    widget.controller
      ..stopDeceleration()
      ..setDecelerationVelocity(details.velocity.pixelsPerSecond)
      ..computeScroll();
    if(widget.controller.touchEventListener != null){
      var point = _getTouchValue(
          widget.controller.touchEventListener.valueType(),
          details.globalPoint.dx,
          details.globalPoint.dy,
          details.localPoint.dx,
          details.localPoint.dy);
      widget.controller.touchEventListener.onMoveEnd(point.x, point.y);
    }
  }

  @override
  void onScaleEnd(OpsScaleEndDetails details) {
    _scale = -1.0;
    if(widget.controller.touchEventListener != null){
      var point = _getTouchValue(
          widget.controller.touchEventListener.valueType(),
          details.globalPoint.dx,
          details.globalPoint.dy,
          details.localPoint.dx,
          details.localPoint.dy);
      widget.controller.touchEventListener.onScaleEnd(point.x, point.y);
    }
  }

  @override
  void onScaleStart(OpsScaleStartDetails details) {
    widget.controller.stopDeceleration();
    _curX = details.localPoint.dx;
    _curY = details.localPoint.dy;
    if(widget.controller.touchEventListener != null){
      var point = _getTouchValue(
          widget.controller.touchEventListener.valueType(),
          details.globalPoint.dx,
          details.globalPoint.dy,
          details.localPoint.dx,
          details.localPoint.dy);
      widget.controller.touchEventListener.onScaleStart(point.x, point.y);
    }
  }

  @override
  void onScaleUpdate(OpsScaleUpdateDetails details) {
    var pinchZoomEnabled = widget.controller.pinchZoomEnabled;
    var isYDirection = details.mainDirection == Direction.Y;
    if (_scale == -1.0) {
      if (pinchZoomEnabled) {
        _scale = details.scale;
      } else {
        _scale = isYDirection ? details.verticalScale : details.horizontalScale;
      }
      return;
    }

    var scale = 1.0;
    if (pinchZoomEnabled) {
      scale = details.scale / _scale;
    } else {
      scale = isYDirection
          ? details.verticalScale / _scale
          : details.horizontalScale / _scale;
    }

    MPPointF trans = _getTrans(_curX, _curY);
    var h = widget.controller.painter.viewPortHandler;
    scale = Utils.optimizeScale(scale);
    if (pinchZoomEnabled) {
      bool canZoomMoreX = scale < 1 ? h.canZoomOutMoreX() : h.canZoomInMoreX();
      bool canZoomMoreY = scale < 1 ? h.canZoomOutMoreY() : h.canZoomInMoreY();
      widget.controller.painter.zoom(
          canZoomMoreX ? scale : 1, canZoomMoreY ? scale : 1, trans.x, trans.y);
      if(widget.controller.touchEventListener != null){
        var point = _getTouchValue(
            widget.controller.touchEventListener.valueType(),
            details.globalFocalPoint.dx,
            details.globalFocalPoint.dy,
            details.localFocalPoint.dx,
            details.localFocalPoint.dy);
        widget.controller.touchEventListener.onScaleUpdate(point.x, point.y);
      }
      setStateIfNotDispose();
    } else {
      if (isYDirection) {
        if (widget.controller.painter.scaleYEnabled) {
          bool canZoomMoreY =
              scale < 1 ? h.canZoomOutMoreY() : h.canZoomInMoreY();
          widget.controller.painter
              .zoom(1, canZoomMoreY ? scale : 1, trans.x, trans.y);
          if(widget.controller.touchEventListener != null){
            var point = _getTouchValue(
                widget.controller.touchEventListener.valueType(),
                details.globalFocalPoint.dx,
                details.globalFocalPoint.dy,
                details.localFocalPoint.dx,
                details.localFocalPoint.dy);
            widget.controller.touchEventListener.onScaleUpdate(point.x, point.y);
          }
          setStateIfNotDispose();
        }
      } else {
        if (widget.controller.painter.scaleXEnabled) {
          bool canZoomMoreX =
              scale < 1 ? h.canZoomOutMoreX() : h.canZoomInMoreX();
          widget.controller.painter
              .zoom(canZoomMoreX ? scale : 1, 1, trans.x, trans.y);
          if(widget.controller.touchEventListener != null){
            var point = _getTouchValue(
                widget.controller.touchEventListener.valueType(),
                details.globalFocalPoint.dx,
                details.globalFocalPoint.dy,
                details.localFocalPoint.dx,
                details.localFocalPoint.dy);
            widget.controller.touchEventListener.onScaleUpdate(point.x, point.y);
          }
          setStateIfNotDispose();
        }
      }
    }
    setStateIfNotDispose();
    MPPointF.recycleInstance(trans);

    if (pinchZoomEnabled) {
      _scale = details.scale;
    } else {
      _scale = isYDirection ? details.verticalScale : details.horizontalScale;
    }
  }

  void onDragStart(LongPressStartDetails details) {
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener.valueType(),
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.localPosition.dx,
          details.localPosition.dy);
      widget.controller.touchEventListener.onDragStart(point.x, point.y);
    }
  }

  void onDragUpdate(LongPressMoveUpdateDetails details) {
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener.valueType(),
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.localPosition.dx,
          details.localPosition.dy);
      widget.controller.touchEventListener.onDragUpdate(point.x, point.y);
    }
  }

  void onDragEnd(LongPressEndDetails details) {
    if (widget.controller.touchEventListener != null) {
      var point = _getTouchValue(
          widget.controller.touchEventListener.valueType(),
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.localPosition.dx,
          details.localPosition.dy);
      widget.controller.touchEventListener.onDragEnd(point.x, point.y);
    }
  }
}
