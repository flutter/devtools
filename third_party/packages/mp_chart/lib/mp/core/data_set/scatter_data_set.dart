import 'dart:ui';

import 'package:mp_chart/mp/core/data_interfaces/i_scatter_data_set.dart';
import 'package:mp_chart/mp/core/data_set/base_data_set.dart';
import 'package:mp_chart/mp/core/data_set/data_set.dart';
import 'package:mp_chart/mp/core/data_set/line_scatter_candle_radar_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/scatter_shape.dart';
import 'package:mp_chart/mp/core/render/chevron_down_shape_renderer.dart';
import 'package:mp_chart/mp/core/render/chevron_up_shape_renderer.dart';
import 'package:mp_chart/mp/core/render/circle_shape_renderer.dart';
import 'package:mp_chart/mp/core/render/cross_shape_renderer.dart';
import 'package:mp_chart/mp/core/render/i_shape_renderer.dart';
import 'package:mp_chart/mp/core/render/square_shape_renderer.dart';
import 'package:mp_chart/mp/core/render/triangle_shape_renderer.dart';
import 'package:mp_chart/mp/core/render/x_shape_renderer.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';

class ScatterDataSet extends LineScatterCandleRadarDataSet<Entry>
    implements IScatterDataSet {
  /// the size the scattershape will have, in density pixels
  double _shapeSize = 15;

  /// Renderer responsible for rendering this DataSet, default: square
  IShapeRenderer _shapeRenderer = SquareShapeRenderer();

  /// The radius of the hole in the shape (applies to Square, Circle and Triangle)
  /// - default: 0.0
  double _scatterShapeHoleRadius = 0;

  /// Color for the hole in the shape.
  /// Setting to `ColorUtils.COLOR_NONE` will behave as transparent.
  /// - default: ColorUtils.COLOR_NONE
  Color _scatterShapeHoleColor = ColorUtils.COLOR_NONE;

  ScatterDataSet(List<Entry> yVals, String label) : super(yVals, label);

  @override
  DataSet<Entry> copy1() {
    List<Entry> entries = List<Entry>();
    for (int i = 0; i < values.length; i++) {
      entries.add(values[i].copy());
    }
    ScatterDataSet copied = ScatterDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  @override
  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is ScatterDataSet) {
      var scatterDataSet = baseDataSet;
      scatterDataSet._shapeSize = _shapeSize;
      scatterDataSet._shapeRenderer = _shapeRenderer;
      scatterDataSet._scatterShapeHoleRadius = _scatterShapeHoleRadius;
      scatterDataSet._scatterShapeHoleColor = _scatterShapeHoleColor;
    }
  }

  /// Sets the size in density pixels the drawn scattershape will have. This
  /// only applies for non custom shapes.
  ///
  /// @param size
  void setScatterShapeSize(double size) {
    _shapeSize = size;
  }

  @override
  double getScatterShapeSize() {
    return _shapeSize;
  }

  /// Sets the ScatterShape this DataSet should be drawn with. This will search for an available IShapeRenderer and set this
  /// renderer for the DataSet.
  ///
  /// @param shape
  void setScatterShape(ScatterShape shape) {
    _shapeRenderer = getRendererForShape(shape);
  }

  /// Sets a  IShapeRenderer responsible for drawing this DataSet.
  /// This can also be used to set a custom IShapeRenderer aside from the default ones.
  ///
  /// @param shapeRenderer
  void setShapeRenderer(IShapeRenderer shapeRenderer) {
    _shapeRenderer = shapeRenderer;
  }

  @override
  IShapeRenderer getShapeRenderer() {
    return _shapeRenderer;
  }

  /// Sets the radius of the hole in the shape (applies to Square, Circle and Triangle)
  /// Set this to <= 0 to remove holes.
  ///
  /// @param holeRadius
  void setScatterShapeHoleRadius(double holeRadius) {
    _scatterShapeHoleRadius = holeRadius;
  }

  @override
  double getScatterShapeHoleRadius() {
    return _scatterShapeHoleRadius;
  }

  /// Sets the color for the hole in the shape.
  ///
  /// @param holeColor
  void setScatterShapeHoleColor(Color holeColor) {
    _scatterShapeHoleColor = holeColor;
  }

  @override
  Color getScatterShapeHoleColor() {
    return _scatterShapeHoleColor;
  }

  static IShapeRenderer getRendererForShape(ScatterShape shape) {
    switch (shape) {
      case ScatterShape.SQUARE:
        return SquareShapeRenderer();
      case ScatterShape.CIRCLE:
        return CircleShapeRenderer();
      case ScatterShape.TRIANGLE:
        return TriangleShapeRenderer();
      case ScatterShape.CROSS:
        return CrossShapeRenderer();
      case ScatterShape.X:
        return XShapeRenderer();
      case ScatterShape.CHEVRON_UP:
        return ChevronUpShapeRenderer();
      case ScatterShape.CHEVRON_DOWN:
        return ChevronDownShapeRenderer();
    }

    return null;
  }
}
