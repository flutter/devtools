import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_line_data_set.dart';
import 'package:mp_chart/mp/core/data_set/base_data_set.dart';
import 'package:mp_chart/mp/core/data_set/data_set.dart';
import 'package:mp_chart/mp/core/data_set/line_radar_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/mode.dart';
import 'package:mp_chart/mp/core/fill_formatter/default_fill_formatter.dart';
import 'package:mp_chart/mp/core/fill_formatter/i_fill_formatter.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class LineDataSet extends LineRadarDataSet<Entry> implements ILineDataSet {
  /// Drawing mode for this line dataset
  ///*/
  Mode _mode = Mode.LINEAR;

  /// List representing all colors that are used for the circles
  List<Color> _circleColors;

  /// the color of the inner circles
  Color _circleHoleColor = ColorUtils.WHITE;

  /// the radius of the circle-shaped value indicators
  double _circleRadius = 8;

  /// the hole radius of the circle-shaped value indicators
  double _circleHoleRadius = 4;

  /// sets the intensity of the cubic lines
  double _cubicIntensity = 0.2;

  /// the path effect of this DataSet that makes dashed lines possible
  DashPathEffect _dashPathEffect;

  /// formatter for customizing the position of the fill-line
  IFillFormatter _fillFormatter = DefaultFillFormatter();

  /// if true, drawing circles is enabled
  bool _draw = true;

  bool mDrawCircleHole = true;

  LineDataSet(List<Entry> yVals, String label) : super(yVals, label) {
    // _circleRadius = Utils.convertDpToPixel(4f);
    // mLineWidth = Utils.convertDpToPixel(1f);

    if (_circleColors == null) {
      _circleColors = List();
    }
    _circleColors.clear();

    // default colors
    // mColors.add(Color.rgb(192, 255, 140));
    // mColors.add(Color.rgb(255, 247, 140));
    _circleColors.add(Color.fromARGB(255, 140, 234, 255));
  }

  @override
  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is LineDataSet) {
      var lineDataSet = baseDataSet;
      lineDataSet._circleColors = _circleColors;
      lineDataSet._circleHoleColor = _circleHoleColor;
      lineDataSet._circleHoleRadius = _circleHoleRadius;
      lineDataSet._circleRadius = _circleRadius;
      lineDataSet._cubicIntensity = _cubicIntensity;
      lineDataSet._dashPathEffect = _dashPathEffect;
      lineDataSet.mDrawCircleHole = mDrawCircleHole;
      lineDataSet._draw = mDrawCircleHole;
      lineDataSet._fillFormatter = _fillFormatter;
      lineDataSet._mode = _mode;
    }
  }

  /// Returns the drawing mode for this line dataset
  ///
  /// @return
  @override
  Mode getMode() {
    return _mode;
  }

  /// Returns the drawing mode for this LineDataSet
  ///
  /// @return
  void setMode(Mode mode) {
    _mode = mode;
  }

  /// Sets the intensity for cubic lines (if enabled). Max = 1f = very cubic,
  /// Min = 0.05f = low cubic effect, Default: 0.2f
  ///
  /// @param intensity
  void setCubicIntensity(double intensity) {
    if (intensity > 1) intensity = 1;
    if (intensity < 0.05) intensity = 0.05;

    _cubicIntensity = intensity;
  }

  @override
  double getCubicIntensity() {
    return _cubicIntensity;
  }

  /// Sets the radius of the drawn circles.
  /// Default radius = 4f, Min = 1f
  ///
  /// @param radius
  void setCircleRadius(double radius) {
    if (radius >= 1) {
      _circleRadius = Utils.convertDpToPixel(radius);
    }
  }

  @override
  double getCircleRadius() {
    return _circleRadius;
  }

  /// Sets the hole radius of the drawn circles.
  /// Default radius = 2f, Min = 0.5f
  ///
  /// @param holeRadius
  void setCircleHoleRadius(double holeRadius) {
    if (holeRadius >= 0.5) {
      _circleHoleRadius = Utils.convertDpToPixel(holeRadius);
    }
  }

  @override
  double getCircleHoleRadius() {
    return _circleHoleRadius;
  }

  /// sets the size (radius) of the circle shpaed value indicators,
  /// default size = 4f
  /// <p/>
  /// This method is deprecated because of unclarity. Use setCircleRadius instead.
  ///
  /// @param size
  void setCircleSize(double size) {
    setCircleRadius(size);
  }

  /// This function is deprecated because of unclarity. Use getCircleRadius instead.
  double getCircleSize() {
    return getCircleRadius();
  }

  /// Enables the line to be drawn in dashed mode, e.g. like this
  /// "- - - - - -". THIS ONLY WORKS IF HARDWARE-ACCELERATION IS TURNED OFF.
  /// Keep in mind that hardware acceleration boosts performance.
  ///
  /// @param lineLength  the length of the line pieces
  /// @param spaceLength the length of space in between the pieces
  /// @param phase       offset, in degrees (normally, use 0)
  void enableDashedLine(double lineLength, double spaceLength, double phase) {
    _dashPathEffect = DashPathEffect(lineLength, spaceLength, phase);
  }

  /// Disables the line to be drawn in dashed mode.
  void disableDashedLine() {
    _dashPathEffect = null;
  }

  @override
  bool isDashedLineEnabled() {
    return _dashPathEffect == null ? false : true;
  }

  @override
  DashPathEffect getDashPathEffect() {
    return _dashPathEffect;
  }

  set dashPathEffect(DashPathEffect value) {
    _dashPathEffect = value;
  }

  /// set this to true to enable the drawing of circle indicators for this
  /// DataSet, default true
  ///
  /// @param enabled
  void setDrawCircles(bool enabled) {
    this._draw = enabled;
  }

  @override
  bool isDrawCirclesEnabled() {
    return _draw;
  }

  @override
  bool isDrawCubicEnabled() {
    return _mode == Mode.CUBIC_BEZIER;
  }

  @override
  bool isDrawSteppedEnabled() {
    return _mode == Mode.STEPPED;
  }

  /** ALL CODE BELOW RELATED TO CIRCLE-COLORS */

  /// returns all colors specified for the circles
  ///
  /// @return
  List<Color> getCircleColors() {
    return _circleColors;
  }

  @override
  Color getCircleColor(int index) {
    return _circleColors[index];
  }

  @override
  int getCircleColorCount() {
    return _circleColors.length;
  }

  /// Sets the colors that should be used for the circles of this DataSet.
  /// Colors are reused as soon as the number of Entries the DataSet represents
  /// is higher than the size of the colors array. Make sure that the colors
  /// are already prepared (by calling getResources().getColor(...)) before
  /// adding them to the DataSet.
  ///
  /// @param colors
  void setCircleColors(List<Color> colors) {
    _circleColors = colors;
  }

  /// Sets the one and ONLY color that should be used for this DataSet.
  /// Internally, this recreates the colors array and adds the specified color.
  ///
  /// @param color
  void setCircleColor(Color color) {
    resetCircleColors();
    _circleColors.add(color);
  }

  /// resets the circle-colors array and creates a  one
  void resetCircleColors() {
    if (_circleColors == null) {
      _circleColors = List();
    }
    _circleColors.clear();
  }

  /// Sets the color of the inner circle of the line-circles.
  ///
  /// @param color
  void setCircleHoleColor(Color color) {
    _circleHoleColor = color;
  }

  @override
  Color getCircleHoleColor() {
    return _circleHoleColor;
  }

  /// Set this to true to allow drawing a hole in each data circle.
  ///
  /// @param enabled
  void setDrawCircleHole(bool enabled) {
    mDrawCircleHole = enabled;
  }

  @override
  bool isDrawCircleHoleEnabled() {
    return mDrawCircleHole;
  }

  /// Sets a custom IFillFormatter to the chart that handles the position of the
  /// filled-line for each DataSet. Set this to null to use the default logic.
  ///
  /// @param formatter
  void setFillFormatter(IFillFormatter formatter) {
    if (formatter == null)
      _fillFormatter = DefaultFillFormatter();
    else
      _fillFormatter = formatter;
  }

  @override
  IFillFormatter getFillFormatter() {
    return _fillFormatter;
  }

  @override
  DataSet<Entry> copy1() {
    List<Entry> entries = List();
    for (int i = 0; i < values.length; i++) {
      entries.add(Entry(
          x: values[i].x,
          y: values[i].y,
          icon: values[i].mIcon,
          data: values[i].mData));
    }
    LineDataSet copied = LineDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  @override
  String toString() {
    return '${super.toString()}\nLineDataSet{_mode: $_mode,\n _circleColors: $_circleColors,\n _circleHoleColor: $_circleHoleColor,\n _circleRadius: $_circleRadius,\n _circleHoleRadius: $_circleHoleRadius,\n _cubicIntensity: $_cubicIntensity,\n _dashPathEffect: $_dashPathEffect,\n _fillFormatter: $_fillFormatter,\n _draw: $_draw,\n mDrawCircleHole: $mDrawCircleHole}';
  }
}
