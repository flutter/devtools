import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';

abstract class CanvasUtils {
  static void drawLines(
      ui.Canvas canvas, List<double> pts, int offset, int count, ui.Paint paint,
      {DashPathEffect effect}) {
    if (effect == null) {
      for (int i = offset; i < count; i += 4) {
        canvas.drawLine(ui.Offset(pts[i], pts[i + 1]),
            ui.Offset(pts[i + 2], pts[i + 3]), paint);
      }
    } else {
      var path = Path();
      for (int i = offset; i < count; i += 4) {
        path.reset();
        path.moveTo(pts[i], pts[i + 1]);
        path.lineTo(pts[i + 2], pts[i + 3]);
        path = effect.convert2DashPath(path);
        canvas.drawPath(path, paint);
      }
    }
  }

  static void drawImage(ui.Canvas canvas, Offset position, ui.Image img,
      ui.Size dstSize, ui.Paint paint) {
    var imgSize = ui.Size(img.width.toDouble(), img.height.toDouble());

    FittedSizes sizes = applyBoxFit(BoxFit.contain, imgSize, dstSize);

    final ui.Rect inputRect = Alignment.center.inscribe(sizes.source,
        Rect.fromLTWH(0, 0, sizes.source.width, sizes.source.height));
    final ui.Rect outputRect = Alignment.center.inscribe(
        sizes.destination,
        Rect.fromLTWH(
            position.dx - dstSize.width / 2,
            position.dy - dstSize.height / 2,
            sizes.destination.width,
            sizes.destination.height));
    canvas.drawImageRect(img, inputRect, outputRect, paint);
  }
}
