import 'package:flutter/rendering.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/matrix4_utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';

class TransformerHorizontalBarChart extends Transformer {
  TransformerHorizontalBarChart(ViewPortHandler viewPortHandler)
      : super(viewPortHandler);

  /// Prepares the matrix that contains all offsets.
  ///
  /// @param inverted
  void prepareMatrixOffset(bool inverted) {
    matrixOffset = Matrix4.identity();

    // offset.postTranslate(mOffsetLeft, getHeight() - mOffsetBottom);

    if (!inverted)
      Matrix4Utils.postTranslate(matrixOffset, viewPortHandler.offsetLeft(),
          viewPortHandler.getChartHeight() - viewPortHandler.offsetBottom());
    else {
      Matrix4Utils.setTranslate(
          matrixOffset,
          -(viewPortHandler.getChartWidth() - viewPortHandler.offsetRight()),
          viewPortHandler.getChartHeight() - viewPortHandler.offsetBottom());
      Matrix4Utils.postScale(matrixOffset, -1.0, 1.0);
    }

    // matrixOffset.set(offset);

    // matrixOffset.reset();
    //
    // matrixOffset.postTranslate(mOffsetLeft, getHeight() -
    // mOffsetBottom);
  }
}
