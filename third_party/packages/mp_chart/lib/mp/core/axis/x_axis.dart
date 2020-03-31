import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/axis/axis_base.dart';
import 'package:mp_chart/mp/core/enums/x_axis_position.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class XAxis extends AxisBase {
  /// width of the x-axis labels in pixels - this is automatically
  /// calculated by the computeSize() methods in the renderers
  int _labelWidth = 1;

  /// height of the x-axis labels in pixels - this is automatically
  /// calculated by the computeSize() methods in the renderers
  int _labelHeight = 1;

  /// width of the (rotated) x-axis labels in pixels - this is automatically
  /// calculated by the computeSize() methods in the renderers
  int _labelRotatedWidth = 1;

  /// height of the (rotated) x-axis labels in pixels - this is automatically
  /// calculated by the computeSize() methods in the renderers
  int _labelRotatedHeight = 1;

  /// This is the angle for drawing the X axis labels (in degrees)
  double _labelRotationAngle = 0;

  /// if set to true, the chart will avoid that the first and last label entry
  /// in the chart "clip" off the edge of the chart
  bool _avoidFirstLastClipping = false;

  /// the position of the x-labels relative to the chart
  XAxisPosition _position = XAxisPosition.TOP;

  XAxis() : super() {
    yOffset = Utils.convertDpToPixel(4);
  }

  // ignore: unnecessary_getters_setters
  XAxisPosition get position => _position;

  // ignore: unnecessary_getters_setters
  set position(XAxisPosition value) {
    _position = value;
  }

  // ignore: unnecessary_getters_setters
  double get labelRotationAngle => _labelRotationAngle;

  // ignore: unnecessary_getters_setters
  set labelRotationAngle(double value) {
    _labelRotationAngle = value;
  }

  // ignore: unnecessary_getters_setters
  bool get avoidFirstLastClipping => _avoidFirstLastClipping;

  // ignore: unnecessary_getters_setters
  set avoidFirstLastClipping(bool value) {
    _avoidFirstLastClipping = value;
  }

  // ignore: unnecessary_getters_setters
  int get labelRotatedHeight => _labelRotatedHeight;

  // ignore: unnecessary_getters_setters
  set labelRotatedHeight(int value) {
    _labelRotatedHeight = value;
  }

  // ignore: unnecessary_getters_setters
  int get labelRotatedWidth => _labelRotatedWidth;

  // ignore: unnecessary_getters_setters
  set labelRotatedWidth(int value) {
    _labelRotatedWidth = value;
  }

  // ignore: unnecessary_getters_setters
  int get labelHeight => _labelHeight;

  // ignore: unnecessary_getters_setters
  set labelHeight(int value) {
    _labelHeight = value;
  }

  // ignore: unnecessary_getters_setters
  int get labelWidth => _labelWidth;

  // ignore: unnecessary_getters_setters
  set labelWidth(int value) {
    _labelWidth = value;
  }

  int getRequiredHeightSpace(TextPainter p) {
    p = PainterUtils.create(p, null, null, textSize);

    int height = Utils.calcTextHeight(p, "A");

    return height;
  }
}
