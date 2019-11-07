import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_line_scatter_candle_radar_data_set.dart';
import 'package:mp_chart/mp/core/data_set/bar_line_scatter_candle_bubble_data_set.dart';
import 'package:mp_chart/mp/core/data_set/base_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

abstract class LineScatterCandleRadarDataSet<T extends Entry>
    extends BarLineScatterCandleBubbleDataSet<T>
    implements ILineScatterCandleRadarDataSet<T> {
  bool _drawVerticalHighlightIndicator = true;
  bool _drawHorizontalHighlightIndicator = true;

  /// the width of the highlight indicator lines
  double _highlightLineWidth = 0.5;

  /// the path effect for dashed highlight-lines
  DashPathEffect _highlightDashPathEffect;

  /// the path effect for dashed highlight-lines
//   DashPathEffect mHighlightDashPathEffect = null;

  LineScatterCandleRadarDataSet(List<T> yVals, String label)
      : super(yVals, label) {
    _highlightLineWidth = Utils.convertDpToPixel(0.5);
  }

  /// Enables / disables the horizontal highlight-indicator. If disabled, the indicator is not drawn.
  /// @param enabled
  void setDrawHorizontalHighlightIndicator(bool enabled) {
    this._drawHorizontalHighlightIndicator = enabled;
  }

  /// Enables / disables the vertical highlight-indicator. If disabled, the indicator is not drawn.
  /// @param enabled
  void setDrawVerticalHighlightIndicator(bool enabled) {
    this._drawVerticalHighlightIndicator = enabled;
  }

  /// Enables / disables both vertical and horizontal highlight-indicators.
  /// @param enabled
  void setDrawHighlightIndicators(bool enabled) {
    setDrawVerticalHighlightIndicator(enabled);
    setDrawHorizontalHighlightIndicator(enabled);
  }

  @override
  bool isVerticalHighlightIndicatorEnabled() {
    return _drawVerticalHighlightIndicator;
  }

  @override
  bool isHorizontalHighlightIndicatorEnabled() {
    return _drawHorizontalHighlightIndicator;
  }

  /// Sets the width of the highlight line in dp.
  /// @param width
  void setHighlightLineWidth(double width) {
    _highlightLineWidth = Utils.convertDpToPixel(width);
  }

  @override
  double getHighlightLineWidth() {
    return _highlightLineWidth;
  }

  /// Enables the highlight-line to be drawn in dashed mode, e.g. like this "- - - - - -"
  ///
  /// @param lineLength the length of the line pieces
  /// @param spaceLength the length of space inbetween the line-pieces
  /// @param phase offset, in degrees (normally, use 0)
  void enableDashedHighlightLine(
      double lineLength, double spaceLength, double phase) {
    _highlightDashPathEffect = DashPathEffect(lineLength, spaceLength, phase);
  }

  /// Disables the highlight-line to be drawn in dashed mode.
  void disableDashedHighlightLine() {
    _highlightDashPathEffect = null;
  }

  /// Returns true if the dashed-line effect is enabled for highlight lines, false if not.
  /// Default: disabled
  ///
  /// @return
  bool isDashedHighlightLineEnabled() {
    return _highlightDashPathEffect == null ? false : true;
  }

  @override
  DashPathEffect getDashPathEffectHighlight() {
    return _highlightDashPathEffect;
  }

  set highlightDashPathEffect(DashPathEffect value) {
    _highlightDashPathEffect = value;
  }

  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is LineScatterCandleRadarDataSet) {
      var lineScatterCandleRadarDataSet = baseDataSet;
      lineScatterCandleRadarDataSet._drawHorizontalHighlightIndicator =
          _drawHorizontalHighlightIndicator;
      lineScatterCandleRadarDataSet._drawVerticalHighlightIndicator =
          _drawVerticalHighlightIndicator;
      lineScatterCandleRadarDataSet._highlightLineWidth = _highlightLineWidth;
      lineScatterCandleRadarDataSet._highlightDashPathEffect =
          _highlightDashPathEffect;
    }
  }

  @override
  String toString() {
    return '${super.toString()}\nLineScatterCandleRadarDataSet{\n_drawVerticalHighlightIndicator: $_drawVerticalHighlightIndicator,\n _drawHorizontalHighlightIndicator: $_drawHorizontalHighlightIndicator,\n _highlightLineWidth: $_highlightLineWidth}';
  }
}
