import 'dart:ui';

import 'package:mp_chart/mp/core/data_interfaces/i_pie_data_set.dart';
import 'package:mp_chart/mp/core/data_set/base_data_set.dart';
import 'package:mp_chart/mp/core/data_set/data_set.dart';
import 'package:mp_chart/mp/core/entry/pie_entry.dart';
import 'package:mp_chart/mp/core/enums/value_position.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class PieDataSet extends DataSet<PieEntry> implements IPieDataSet {
  /// the space in pixels between the chart-slices, default 0f
  double _sliceSpace = 0;
  bool _automaticallyDisableSliceSpacing = false;

  /// indicates the selection distance of a pie slice
  double _shift = 18;

  ValuePosition _xValuePosition = ValuePosition.INSIDE_SLICE;
  ValuePosition _yValuePosition = ValuePosition.INSIDE_SLICE;
  bool _usingSliceColorAsValueLineColor = false;
  Color _valueLineColor = Color(0xff000000);
  double _valueLineWidth = 1.0;
  double _valueLinePart1OffsetPercentage = 75.0;
  double _valueLinePart1Length = 0.3;
  double _valueLinePart2Length = 0.4;
  bool _valueLineVariableLength = true;

  PieDataSet(List<PieEntry> yVals, String label) : super(yVals, label);

  @override
  DataSet<PieEntry> copy1() {
    List<PieEntry> entries = List();
    for (int i = 0; i < values.length; i++) {
      entries.add(values[i].copy());
    }
    PieDataSet copied = PieDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
  }

  @override
  void calcMinMax1(PieEntry e) {
    if (e == null) return;
    calcMinMaxY1(e);
  }

  /// Sets the space that is left out between the piechart-slices in dp.
  /// Default: 0 --> no space, maximum 20f
  ///
  /// @param spaceDp
  void setSliceSpace(double spaceDp) {
    if (spaceDp > 20) spaceDp = 20;
    if (spaceDp < 0) spaceDp = 0;

    _sliceSpace = Utils.convertDpToPixel(spaceDp);
  }

  @override
  double getSliceSpace() {
    return _sliceSpace;
  }

  /// When enabled, slice spacing will be 0.0 when the smallest value is going to be
  /// smaller than the slice spacing itself.
  ///
  /// @param autoDisable
  void setAutomaticallyDisableSliceSpacing(bool autoDisable) {
    _automaticallyDisableSliceSpacing = autoDisable;
  }

  /// When enabled, slice spacing will be 0.0 when the smallest value is going to be
  /// smaller than the slice spacing itself.
  ///
  /// @return
  @override
  bool isAutomaticallyDisableSliceSpacingEnabled() {
    return _automaticallyDisableSliceSpacing;
  }

  /// sets the distance the highlighted piechart-slice of this DataSet is
  /// "shifted" away from the center of the chart, default 12f
  ///
  /// @param shift
  void setSelectionShift(double shift) {
    _shift = Utils.convertDpToPixel(shift);
  }

  @override
  double getSelectionShift() {
    return _shift;
  }

  @override
  ValuePosition getXValuePosition() {
    return _xValuePosition;
  }

  void setXValuePosition(ValuePosition xValuePosition) {
    this._xValuePosition = xValuePosition;
  }

  @override
  ValuePosition getYValuePosition() {
    return _yValuePosition;
  }

  void setYValuePosition(ValuePosition yValuePosition) {
    this._yValuePosition = yValuePosition;
  }

  /// When valuePosition is OutsideSlice, use slice colors as line color if true
  @override
  bool isUsingSliceColorAsValueLineColor() {
    return _usingSliceColorAsValueLineColor;
  }

  void setUsingSliceColorAsValueLineColor(
      bool usingSliceColorAsValueLineColor) {
    this._usingSliceColorAsValueLineColor = usingSliceColorAsValueLineColor;
  }

  /// When valuePosition is OutsideSlice, indicates line color
  @override
  Color getValueLineColor() {
    return _valueLineColor;
  }

  void setValueLineColor(Color valueLineColor) {
    this._valueLineColor = valueLineColor;
  }

  /// When valuePosition is OutsideSlice, indicates line width
  @override
  double getValueLineWidth() {
    return _valueLineWidth;
  }

  void setValueLineWidth(double valueLineWidth) {
    this._valueLineWidth = valueLineWidth;
  }

  /// When valuePosition is OutsideSlice, indicates offset as percentage out of the slice size
  @override
  double getValueLinePart1OffsetPercentage() {
    return _valueLinePart1OffsetPercentage;
  }

  void setValueLinePart1OffsetPercentage(
      double valueLinePart1OffsetPercentage) {
    this._valueLinePart1OffsetPercentage = valueLinePart1OffsetPercentage;
  }

  /// When valuePosition is OutsideSlice, indicates length of first half of the line
  @override
  double getValueLinePart1Length() {
    return _valueLinePart1Length;
  }

  void setValueLinePart1Length(double valueLinePart1Length) {
    this._valueLinePart1Length = valueLinePart1Length;
  }

  /// When valuePosition is OutsideSlice, indicates length of second half of the line
  @override
  double getValueLinePart2Length() {
    return _valueLinePart2Length;
  }

  void setValueLinePart2Length(double valueLinePart2Length) {
    this._valueLinePart2Length = valueLinePart2Length;
  }

  /// When valuePosition is OutsideSlice, this allows variable line length
  @override
  bool isValueLineVariableLength() {
    return _valueLineVariableLength;
  }

  void setValueLineVariableLength(bool valueLineVariableLength) {
    this._valueLineVariableLength = valueLineVariableLength;
  }
}
