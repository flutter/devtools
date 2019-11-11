import 'dart:ui';

import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_candle_data_set.dart';
import 'package:mp_chart/mp/core/data_set/base_data_set.dart';
import 'package:mp_chart/mp/core/data_set/data_set.dart';
import 'package:mp_chart/mp/core/data_set/line_scatter_candle_radar_data_set.dart';
import 'package:mp_chart/mp/core/entry/candle_entry.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class CandleDataSet extends LineScatterCandleRadarDataSet<CandleEntry>
    implements ICandleDataSet {
  /// the width of the shadow of the candle
  double _shadowWidth = 3;

  /// should the candle bars show?
  /// when false, only "ticks" will show
  /// <p/>
  /// - default: true
  bool _showCandleBar = true;

  /// the space between the candle entries, default 0.1f (10%)
  double _barSpace = 0.1;

  /// use candle color for the shadow
  bool _shadowColorSameAsCandle = false;

  /// paint style when open < close
  /// increasing candlesticks are traditionally hollow
  PaintingStyle _increasingPaintStyle = PaintingStyle.stroke;

  /// paint style when open > close
  /// descreasing candlesticks are traditionally filled
  PaintingStyle _decreasingPaintStyle = PaintingStyle.fill;

  /// color for open == close
  Color _neutralColor = ColorUtils.COLOR_SKIP;

  /// color for open < close
  Color _increasingColor = ColorUtils.COLOR_SKIP;

  /// color for open > close
  Color _decreasingColor = ColorUtils.COLOR_SKIP;

  /// shadow line color, set -1 for backward compatibility and uses default
  /// color
  Color _shadowColor = ColorUtils.COLOR_SKIP;

  CandleDataSet(List<CandleEntry> yVals, String label) : super(yVals, label);

  @override
  DataSet<CandleEntry> copy1() {
    List<CandleEntry> entries = List<CandleEntry>();
    for (int i = 0; i < values.length; i++) {
      entries.add(values[i].copy());
    }
    CandleDataSet copied = CandleDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is CandleDataSet) {
      var candleDataSet = baseDataSet;
      candleDataSet._shadowWidth = _shadowWidth;
      candleDataSet._showCandleBar = _showCandleBar;
      candleDataSet._barSpace = _barSpace;
      candleDataSet._shadowColorSameAsCandle = _shadowColorSameAsCandle;
      candleDataSet.setHighLightColor(getHighLightColor());
      candleDataSet._increasingPaintStyle = _increasingPaintStyle;
      candleDataSet._decreasingPaintStyle = _decreasingPaintStyle;
      candleDataSet._neutralColor = _neutralColor;
      candleDataSet._increasingColor = _increasingColor;
      candleDataSet._decreasingColor = _decreasingColor;
      candleDataSet._shadowColor = _shadowColor;
    }
  }

  @override
  void calcMinMax1(CandleEntry e) {
    if (e.shadowLow < getYMin()) yMin = e.shadowLow;

    if (e.shadowHigh > getYMax()) yMax = e.shadowHigh;

    calcMinMaxX1(e);
  }

  @override
  void calcMinMaxY1(CandleEntry e) {
    if (e.shadowHigh < getYMin()) yMin = e.shadowHigh;

    if (e.shadowHigh > getYMax()) yMax = e.shadowHigh;

    if (e.shadowLow < getYMin()) yMin = e.shadowLow;

    if (e.shadowLow > getYMax()) yMax = e.shadowLow;
  }

  /// Sets the space that is left out on the left and right side of each
  /// candle, default 0.1f (10%), max 0.45f, min 0f
  ///
  /// @param space
  void setBarSpace(double space) {
    if (space < 0) space = 0;
    if (space > 0.45) space = 0.45;

    _barSpace = space;
  }

  @override
  double getBarSpace() {
    return _barSpace;
  }

  /// Sets the width of the candle-shadow-line in pixels. Default 3f.
  ///
  /// @param width
  void setShadowWidth(double width) {
    _shadowWidth = Utils.convertDpToPixel(width);
  }

  @override
  double getShadowWidth() {
    return _shadowWidth;
  }

  /// Sets whether the candle bars should show?
  ///
  /// @param showCandleBar
  void setShowCandleBar(bool showCandleBar) {
    _showCandleBar = showCandleBar;
  }

  @override
  bool getShowCandleBar() {
    return _showCandleBar;
  }

  /** BELOW THIS COLOR HANDLING */

  /// Sets the one and ONLY color that should be used for this DataSet when
  /// open == close.
  ///
  /// @param color
  void setNeutralColor(Color color) {
    _neutralColor = color;
  }

  @override
  Color getNeutralColor() {
    return _neutralColor;
  }

  /// Sets the one and ONLY color that should be used for this DataSet when
  /// open <= close.
  ///
  /// @param color
  void setIncreasingColor(Color color) {
    _increasingColor = color;
  }

  @override
  Color getIncreasingColor() {
    return _increasingColor;
  }

  /// Sets the one and ONLY color that should be used for this DataSet when
  /// open > close.
  ///
  /// @param color
  void setDecreasingColor(Color color) {
    _decreasingColor = color;
  }

  @override
  Color getDecreasingColor() {
    return _decreasingColor;
  }

  @override
  PaintingStyle getIncreasingPaintStyle() {
    return _increasingPaintStyle;
  }

  /// Sets paint style when open < close
  ///
  /// @param paintStyle
  void setIncreasingPaintStyle(PaintingStyle paintStyle) {
    this._increasingPaintStyle = paintStyle;
  }

  @override
  PaintingStyle getDecreasingPaintStyle() {
    return _decreasingPaintStyle;
  }

  /// Sets paint style when open > close
  ///
  /// @param decreasingPaintStyle
  void setDecreasingPaintStyle(PaintingStyle decreasingPaintStyle) {
    this._decreasingPaintStyle = decreasingPaintStyle;
  }

  @override
  Color getShadowColor() {
    return _shadowColor;
  }

  /// Sets shadow color for all entries
  ///
  /// @param shadowColor
  void setShadowColor(Color shadowColor) {
    this._shadowColor = shadowColor;
  }

  @override
  bool getShadowColorSameAsCandle() {
    return _shadowColorSameAsCandle;
  }

  /// Sets shadow color to be the same color as the candle color
  ///
  /// @param shadowColorSameAsCandle
  void setShadowColorSameAsCandle(bool shadowColorSameAsCandle) {
    this._shadowColorSameAsCandle = shadowColorSameAsCandle;
  }

  @override
  DashPathEffect getDashPathEffectHighlight() {
    return null;
  }
}
