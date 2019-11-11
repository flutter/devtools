import 'dart:ui';

import 'package:mp_chart/mp/core/data_interfaces/i_scatter_data_set.dart';
import 'package:mp_chart/mp/core/render/i_shape_renderer.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class TriangleShapeRenderer implements IShapeRenderer {
  Path _trianglePathBuffer = Path();

  @override
  void renderShape(
      Canvas c,
      IScatterDataSet dataSet,
      ViewPortHandler viewPortHandler,
      double posX,
      double posY,
      Paint renderPaint) {
    final double shapeSize = dataSet.getScatterShapeSize();
    final double shapeHalf = shapeSize / 2;
    final double shapeHoleSizeHalf =
        Utils.convertDpToPixel(dataSet.getScatterShapeHoleRadius());
    final double shapeHoleSize = shapeHoleSizeHalf * 2.0;
    final double shapeStrokeSize = (shapeSize - shapeHoleSize) / 2.0;

    final Color shapeHoleColor = dataSet.getScatterShapeHoleColor();

    renderPaint.style = PaintingStyle.fill;

    // create a triangle path
    Path tri = _trianglePathBuffer;
    tri.reset();

    tri.moveTo(posX, posY - shapeHalf);
    tri.lineTo(posX + shapeHalf, posY + shapeHalf);
    tri.lineTo(posX - shapeHalf, posY + shapeHalf);

    if (shapeSize > 0.0) {
      tri.lineTo(posX, posY - shapeHalf);

      tri.moveTo(posX - shapeHalf + shapeStrokeSize,
          posY + shapeHalf - shapeStrokeSize);
      tri.lineTo(posX + shapeHalf - shapeStrokeSize,
          posY + shapeHalf - shapeStrokeSize);
      tri.lineTo(posX, posY - shapeHalf + shapeStrokeSize);
      tri.lineTo(posX - shapeHalf + shapeStrokeSize,
          posY + shapeHalf - shapeStrokeSize);
    }

    tri.close();

    c.drawPath(tri, renderPaint);
    tri.reset();

    if (shapeSize > 0.0 && shapeHoleColor != ColorUtils.COLOR_NONE) {
      renderPaint.color = shapeHoleColor;

      tri.moveTo(posX, posY - shapeHalf + shapeStrokeSize);
      tri.lineTo(posX + shapeHalf - shapeStrokeSize,
          posY + shapeHalf - shapeStrokeSize);
      tri.lineTo(posX - shapeHalf + shapeStrokeSize,
          posY + shapeHalf - shapeStrokeSize);
      tri.close();

      c.drawPath(tri, renderPaint);
      tri.reset();
    }
  }
}
