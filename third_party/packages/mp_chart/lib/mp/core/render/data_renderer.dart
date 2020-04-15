import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/chart_interface.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/render/renderer.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

abstract class DataRenderer extends Renderer {
  /// the animator object used to perform animations on the chart data
  Animator _animator;

  /// main paint object used for rendering
  Paint _renderPaint;

  /// paint used for highlighting values
  Paint _highlightPaint;

  Paint _drawPaint;

  TextPainter _valuePaint;

  DataRenderer(Animator animator, ViewPortHandler viewPortHandler)
      : super(viewPortHandler) {
    this._animator = animator;

    _renderPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    _drawPaint = Paint();

    _valuePaint = PainterUtils.create(_valuePaint, null,
        Color.fromARGB(255, 63, 63, 63), Utils.convertDpToPixel(9));

    _highlightPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..color = Color.fromARGB(255, 255, 187, 115);
  }

  bool isDrawingValuesAllowed(ChartInterface chart) {
    return chart.getData().getEntryCount() <
        chart.getMaxVisibleCount() * viewPortHandler.getScaleX();
  }

  // ignore: unnecessary_getters_setters
  TextPainter get valuePaint => _valuePaint;

  // ignore: unnecessary_getters_setters
  set valuePaint(TextPainter value) {
    _valuePaint = value;
  }

  // ignore: unnecessary_getters_setters
  Paint get highlightPaint => _highlightPaint;

  Paint get renderPaint => _renderPaint;

  Animator get animator => _animator;

  Paint get drawPaint => _drawPaint;

  // ignore: unnecessary_getters_setters
  set highlightPaint(Paint value) {
    _highlightPaint = value;
  }

  /// Applies the required styling (provided by the DataSet) to the value-paint
  /// object.
  ///
  /// @param set
  void applyValueTextStyle(IDataSet set) {
    _valuePaint = PainterUtils.create(_valuePaint, null,
        Color.fromARGB(255, 63, 63, 63), Utils.convertDpToPixel(9),
        fontFamily: set?.getValueTypeface()?.fontFamily,
        fontWeight: set?.getValueTypeface()?.fontWeight);
  }

  /// Initializes the buffers used for rendering with a  size. Since this
  /// method performs memory allocations, it should only be called if
  /// necessary.
  void initBuffers();

  /// Draws the actual data in form of lines, bars, ... depending on Renderer subclass.
  ///
  /// @param c
  void drawData(Canvas c);

  /// Loops over all Entrys and draws their values.
  ///
  /// @param c
  void drawValues(Canvas c);

  /// Draws the value of the given entry by using the provided IValueFormatter.
  ///
  /// @param c         canvas
  /// @param valueText label to draw
  /// @param x         position
  /// @param y         position
  /// @param color
  void drawValue(Canvas c, String valueText, double x, double y, Color color);

  /// Draws any kind of additional information (e.g. line-circles).
  ///
  /// @param c
  void drawExtras(Canvas c);

  /// Draws all highlight indicators for the values that are currently highlighted.
  ///
  /// @param c
  /// @param indices the highlighted values
  void drawHighlighted(Canvas c, List<Highlight> indices);
}
