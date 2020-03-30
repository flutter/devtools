import 'dart:ui';

import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/enums/legend_form.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';

class LegendEntry {
  LegendEntry.empty();

  LegendEntry(
      String label,
      LegendForm form,
      double formSize,
      double formLineWidth,
      DashPathEffect formLineDashEffect,
      Color formColor) {
    this._label = label;
    this._form = form;
    this._formSize = formSize;
    this._formLineWidth = formLineWidth;
    this.formLineDashEffect = formLineDashEffect;
    this._formColor = formColor;
  }

  /// The legend entry text.
  /// A `null` label will start a group.
  String _label;

  /// The form to draw for this entry.
  ///
  /// `NONE` will avoid drawing a form, and any related space.
  /// `EMPTY` will avoid drawing a form, but keep its space.
  /// `DEFAULT` will use the Legend's default.
  LegendForm _form = LegendForm.DEFAULT;

  /// Form size will be considered except for when .None is used
  ///
  /// Set as NaN to use the legend's default
  double _formSize = double.nan;

  /// Line width used for shapes that consist of lines.
  ///
  /// Set as NaN to use the legend's default
  double _formLineWidth = double.nan;

  /// Line dash path effect used for shapes that consist of lines.
  ///
  /// Set to null to use the legend's default
  DashPathEffect formLineDashEffect;

  /// The color for drawing the form
  Color _formColor = ColorUtils.COLOR_NONE;

  // ignore: unnecessary_getters_setters
  String get label => _label;

  // ignore: unnecessary_getters_setters
  set label(String value) {
    _label = value;
  }

  // ignore: unnecessary_getters_setters
  LegendForm get form => _form;

  // ignore: unnecessary_getters_setters
  set form(LegendForm value) {
    _form = value;
  }

  // ignore: unnecessary_getters_setters
  double get formSize => _formSize;

  // ignore: unnecessary_getters_setters
  set formSize(double value) {
    _formSize = value;
  }

  // ignore: unnecessary_getters_setters
  double get formLineWidth => _formLineWidth;

  // ignore: unnecessary_getters_setters
  set formLineWidth(double value) {
    _formLineWidth = value;
  }

  // ignore: unnecessary_getters_setters
  Color get formColor => _formColor;

  // ignore: unnecessary_getters_setters
  set formColor(Color value) {
    _formColor = value;
  }

  @override
  String toString() {
    return 'LegendEntry{_form: $_form,\n _formSize: $_formSize,\n _formLineWidth: $_formLineWidth}';
  }
}
