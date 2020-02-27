import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_line_scatter_candle_radar_data_set.dart';
import 'package:mp_chart/mp/core/render/bar_line_scatter_candle_bubble_renderer.dart';
import 'package:mp_chart/mp/core/view_port.dart';

abstract class LineScatterCandleRadarRenderer
    extends BarLineScatterCandleBubbleRenderer {
  /// path that is used for drawing highlight-lines (drawLines(...) cannot be used because of dashes)
  Path _highlightLinePath = Path();

  LineScatterCandleRadarRenderer(
      Animator animator, ViewPortHandler viewPortHandler)
      : super(animator, viewPortHandler);

  /// Draws vertical & horizontal highlight-lines if enabled.
  ///
  /// @param c
  /// @param x x-position of the highlight line intersection
  /// @param y y-position of the highlight line intersection
  /// @param set the currently drawn dataset
  void drawHighlightLines(
      Canvas c, double x, double y, ILineScatterCandleRadarDataSet set) {
    // set color and stroke-width
    highlightPaint
      ..color = set.getHighLightColor()
      ..strokeWidth = set.getHighlightLineWidth();

    // draw vertical highlight lines
    if (set.isVerticalHighlightIndicatorEnabled()) {
      // create vertical path
      _highlightLinePath.reset();
      _highlightLinePath.moveTo(x, viewPortHandler.contentTop());
      _highlightLinePath.lineTo(x, viewPortHandler.contentBottom());

      if (set.getDashPathEffectHighlight() != null) {
        _highlightLinePath = set
            .getDashPathEffectHighlight()
            .convert2DashPath(_highlightLinePath);
      }
      c.drawPath(_highlightLinePath, highlightPaint);
    }

    // draw horizontal highlight lines
    if (set.isHorizontalHighlightIndicatorEnabled()) {
      // create horizontal path
      _highlightLinePath.reset();
      _highlightLinePath.moveTo(viewPortHandler.contentLeft(), y);
      _highlightLinePath.lineTo(viewPortHandler.contentRight(), y);

      if (set.getDashPathEffectHighlight() != null) {
        _highlightLinePath = set
            .getDashPathEffectHighlight()
            .convert2DashPath(_highlightLinePath);
      }
      c.drawPath(_highlightLinePath, highlightPaint);
    }
  }
}
