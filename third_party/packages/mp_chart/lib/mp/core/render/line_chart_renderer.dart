import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/bounds.dart';
import 'package:mp_chart/mp/core/cache.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/data/line_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_line_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/line_data_provider.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/mode.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/render/line_radar_renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/canvas_utils.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class LineChartRenderer extends LineRadarRenderer {
  LineDataProvider _provider;

  /// paint for the inner circle of the value indicators
  Paint _circlePaintInner;

  /**
   * Bitmap object used for drawing the paths (otherwise they are too long if
   * rendered directly on the canvas)
   */
//   WeakReference<Bitmap> mDrawBitmap;

//  /**
//   * on this canvas, the paths are rendered, it is initialized with the
//   * pathBitmap
//   */
//  Canvas mBitmapCanvas;

  /// the bitmap configuration to be used
//   Bitmap.Config mBitmapConfig = Bitmap.Config.ARGB_8888;

  Path _cubicPath = Path();
  Path _cubicFillPath = Path();

  LineChartRenderer(LineDataProvider chart, ChartAnimator animator,
      ViewPortHandler viewPortHandler)
      : super(animator, viewPortHandler) {
    _provider = chart;

    _circlePaintInner = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = ColorUtils.WHITE;
  }

  LineDataProvider get provider => _provider;

  @override
  void initBuffers() {}

  @override
  void drawData(Canvas c) {
//    int width = viewPortHandler.getChartWidth().toInt();
//    int height = viewPortHandler.getChartHeight().toInt();

//    Bitmap drawBitmap = mDrawBitmap == null ? null : mDrawBitmap.get();
//
//    if (drawBitmap == null
//        || (drawBitmap.getWidth() != width)
//        || (drawBitmap.getHeight() != height)) {
//      if (width > 0 && height > 0) {
//        drawBitmap = Bitmap.createBitmap(width, height, mBitmapConfig);
//        mDrawBitmap =  WeakReference<>(drawBitmap);
//        mBitmapCanvas =  Canvas(drawBitmap);
//      } else
//        return;
//    }
//
//    drawBitmap.eraseColor(Color.TRANSPARENT);

    LineData lineData = _provider.getLineData();

    for (ILineDataSet set in lineData.dataSets) {
      if (set.isVisible()) drawDataSet(c, set);
    }
//    c.drawBitmap(drawBitmap, 0, 0, renderPaint);
  }

  void drawDataSet(Canvas c, ILineDataSet dataSet) {
    if (dataSet.getEntryCount() < 1) return;

    renderPaint..strokeWidth = dataSet.getLineWidth();

    switch (dataSet.getMode()) {
      case Mode.LINEAR:
      case Mode.STEPPED:
        drawLinear(c, dataSet);
        break;
      case Mode.CUBIC_BEZIER:
        drawCubicBezier(c, dataSet);
        break;
      case Mode.HORIZONTAL_BEZIER:
        drawHorizontalBezier(c, dataSet);
        break;
      default:
        drawLinear(c, dataSet);
    }
  }

  void drawHorizontalBezier(Canvas canvas, ILineDataSet dataSet) {
    double phaseY = animator.getPhaseY();
    Transformer trans = _provider.getTransformer(dataSet.getAxisDependency());

    xBounds.set(_provider, dataSet);

    List<double> list = List();

    if (xBounds.range >= 1) {
      Entry prev = dataSet.getEntryForIndex(xBounds.min);
      Entry cur = prev;
      // let the spline start
      _cubicPath.moveTo(cur.x, cur.y * phaseY);
      list.add(cur.x);
      list.add(cur.y * phaseY);

      for (int j = xBounds.min + 1; j <= xBounds.range + xBounds.min; j++) {
        prev = cur;
        cur = dataSet.getEntryForIndex(j);

        final double cpx = (prev.x) + (cur.x - prev.x) / 2.0;

        list.add(cpx);
        list.add(prev.y * phaseY);
        list.add(cpx);
        list.add(cur.y * phaseY);
        list.add(cur.x);
        list.add(cur.y * phaseY);
      }
    }

    renderPaint
      ..color = dataSet.getColor1()
      ..style = PaintingStyle.stroke;

    trans.pointValuesToPixel(list);

    _cubicPath.reset();
    if (dataSet.isDrawFilledEnabled()) {
      _cubicFillPath.reset();
    }
    _cubicPath.moveTo(list[0], list[1]);
    if (dataSet.isDrawFilledEnabled()) {
      _cubicFillPath.moveTo(list[0], list[1]);
    }

    int i = 2;
    for (int j = xBounds.min + 1; j <= xBounds.range + xBounds.min; j++) {
      _cubicPath.cubicTo(list[i], list[i + 1], list[i + 2], list[i + 3],
          list[i + 4], list[i + 5]);
      if (dataSet.isDrawFilledEnabled()) {
        _cubicFillPath.cubicTo(list[i], list[i + 1], list[i + 2], list[i + 3],
            list[i + 4], list[i + 5]);
      }
      i += 6;
    }

    // if filled is enabled, close the path
    if (dataSet.isDrawFilledEnabled()) {
      // create a  path, this is bad for performance
      drawCubicFill(canvas, dataSet, _cubicFillPath, trans, xBounds);
    }

    if (dataSet.getDashPathEffect() != null) {
      _cubicPath = dataSet.getDashPathEffect().convert2DashPath(_cubicPath);
    }
    canvas.drawPath(_cubicPath, renderPaint);
  }

  void drawCubicBezier(Canvas canvas, ILineDataSet dataSet) {
    double phaseY = animator.getPhaseY();

    Transformer trans = _provider.getTransformer(dataSet.getAxisDependency());

    xBounds.set(_provider, dataSet);

    double intensity = dataSet.getCubicIntensity();

    List<double> list = List();

    double x = 0.0;
    double y = 0.0;
    if (xBounds.range >= 1) {
      double prevDx = 0;
      double prevDy = 0;
      double curDx = 0;
      double curDy = 0;

      // Take an extra point from the left, and an extra from the right.
      // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
      // So in the starting `prev` and `cur`, go -2, -1
      // And in the `lastIndex`, add +1

      final int firstIndex = xBounds.min + 1;
      final int lastIndex = xBounds.min + xBounds.range;

      Entry prevPrev;
      Entry prev = dataSet.getEntryForIndex(max(firstIndex - 2, 0));
      Entry cur = dataSet.getEntryForIndex(max(firstIndex - 1, 0));
      Entry next = cur;
      int nextIndex = -1;

      if (cur == null) return;

      x = cur.x;
      y = cur.y;

      // let the spline start
      list.add(cur.x);
      list.add(cur.y * phaseY);

      for (int j = xBounds.min + 1; j <= xBounds.range + xBounds.min; j++) {
        prevPrev = prev;
        prev = cur;
        cur = nextIndex == j ? next : dataSet.getEntryForIndex(j);

        nextIndex = j + 1 < dataSet.getEntryCount() ? j + 1 : j;
        next = dataSet.getEntryForIndex(nextIndex);

        prevDx = (cur.x - prevPrev.x) * intensity;
        prevDy = (cur.y - prevPrev.y) * intensity;
        curDx = (next.x - prev.x) * intensity;
        curDy = (next.y - prev.y) * intensity;

        list.add(prev.x + prevDx);
        list.add((prev.y + prevDy) * phaseY);
        list.add(cur.x - curDx);
        list.add((cur.y - curDy) * phaseY);
        list.add(cur.x);
        list.add(cur.y * phaseY);
      }
    }

    if (list.length <= 0) {
      return;
    }

    renderPaint
      ..color = dataSet.getColor1()
      ..style = PaintingStyle.stroke;

    trans.pointValuesToPixel(list);

    _cubicPath.reset();
    if (dataSet.isDrawFilledEnabled()) {
      _cubicFillPath.reset();
    }
    _cubicPath.moveTo(list[0], list[1]);
    if (dataSet.isDrawFilledEnabled()) {
      _cubicFillPath.moveTo(list[0], list[1]);
    }

    int i = 2;
    for (int j = xBounds.min + 1; j <= xBounds.range + xBounds.min; j++) {
      _cubicPath.cubicTo(list[i], list[i + 1], list[i + 2], list[i + 3],
          list[i + 4], list[i + 5]);
      if (dataSet.isDrawFilledEnabled()) {
        _cubicFillPath.cubicTo(list[i], list[i + 1], list[i + 2], list[i + 3],
            list[i + 4], list[i + 5]);
      }
      i += 6;
    }

    // if filled is enabled, close the path
    if (dataSet.isDrawFilledEnabled()) {
      drawCubicFill(canvas, dataSet, _cubicFillPath, trans, xBounds);
    }

    if (dataSet.getDashPathEffect() != null) {
      _cubicPath = dataSet.getDashPathEffect().convert2DashPath(_cubicPath);
    }
    canvas.drawPath(_cubicPath, renderPaint);
  }

  void drawCubicFill(Canvas c, ILineDataSet dataSet, Path spline,
      Transformer trans, XBounds bounds) {
    double fillMin =
        dataSet.getFillFormatter().getFillLinePosition(dataSet, _provider);

    List<double> list = List();
    list.add(dataSet.getEntryForIndex(bounds.min + bounds.range).x);
    list.add(fillMin);
    list.add(dataSet.getEntryForIndex(bounds.min).x);
    list.add(fillMin);

    trans.pointValuesToPixel(list);

    spline.lineTo(list[0], list[1]);
    spline.lineTo(list[2], list[3]);
    spline.close();

//    final Drawable drawable = dataSet.getFillDrawable();
//    if (drawable != null) {
//      drawFilledPath(c, spline, drawable);
//    } else {

    drawFilledPath2(
        c, spline, dataSet.getFillColor().value, dataSet.getFillAlpha());

//    }
  }

  List<double> mLineBuffer = List(4);

  /// Draws a normal line.
  ///
  /// @param c
  /// @param dataSet
  void drawLinear(Canvas canvas, ILineDataSet dataSet) {
    int entryCount = dataSet.getEntryCount();

    final bool isDrawSteppedEnabled = dataSet.getMode() == Mode.STEPPED;
    final int pointsPerEntryPair = isDrawSteppedEnabled ? 4 : 2;

    Transformer trans = _provider.getTransformer(dataSet.getAxisDependency());

    double phaseY = animator.getPhaseY();

    renderPaint..style = PaintingStyle.stroke;

//    Canvas canvas = null;
//
//    // if the data-set is dashed, draw on bitmap-canvas
//    if (dataSet.isDashedLineEnabled()) {
//      canvas = mBitmapCanvas;
//    } else {
//      canvas = c;
//    }

    xBounds.set(_provider, dataSet);

    // if drawing filled is enabled
    if (dataSet.isDrawFilledEnabled() && entryCount > 0) {
      drawLinearFill(canvas, dataSet, trans, xBounds);
    }

    // more than 1 color
    if (dataSet.getColors().length > 1) {
      if (mLineBuffer.length <= pointsPerEntryPair * 2)
        mLineBuffer = List(pointsPerEntryPair * 4);

      for (int j = xBounds.min; j <= xBounds.range + xBounds.min; j++) {
        Entry e = dataSet.getEntryForIndex(j);
        if (e == null) continue;

        mLineBuffer[0] = e.x;
        mLineBuffer[1] = e.y * phaseY;

        if (j < xBounds.max) {
          e = dataSet.getEntryForIndex(j + 1);

          if (e == null) break;

          if (isDrawSteppedEnabled) {
            mLineBuffer[2] = e.x;
            mLineBuffer[3] = mLineBuffer[1];
            mLineBuffer[4] = mLineBuffer[2];
            mLineBuffer[5] = mLineBuffer[3];
            mLineBuffer[6] = e.x;
            mLineBuffer[7] = e.y * phaseY;
          } else {
            mLineBuffer[2] = e.x;
            mLineBuffer[3] = e.y * phaseY;
          }
        } else {
          mLineBuffer[2] = mLineBuffer[0];
          mLineBuffer[3] = mLineBuffer[1];
        }

        trans.pointValuesToPixel(mLineBuffer);

        if (!viewPortHandler.isInBoundsRight(mLineBuffer[0])) break;

        // make sure the lines don't do shitty things outside
        // bounds
        if (!viewPortHandler.isInBoundsLeft(mLineBuffer[2]) ||
            (!viewPortHandler.isInBoundsTop(mLineBuffer[1]) &&
                !viewPortHandler.isInBoundsBottom(mLineBuffer[3]))) continue;

        // get the color that is set for this line-segment
        renderPaint..color = dataSet.getColor2(j);

        CanvasUtils.drawLines(
            canvas, mLineBuffer, 0, pointsPerEntryPair * 2, renderPaint,
            effect: dataSet.getDashPathEffect());
      }
    } else {
      // only one color per dataset

      if (mLineBuffer.length <
          max((entryCount) * pointsPerEntryPair, pointsPerEntryPair) * 2)
        mLineBuffer = List(
            max((entryCount) * pointsPerEntryPair, pointsPerEntryPair) * 4);

      Entry e1, e2;

      e1 = dataSet.getEntryForIndex(xBounds.min);

      if (e1 != null) {
        int j = 0;
        for (int x = xBounds.min; x <= xBounds.range + xBounds.min; x++) {
          e1 = dataSet.getEntryForIndex(x == 0 ? 0 : (x - 1));
          e2 = dataSet.getEntryForIndex(x);

          if (e1 == null || e2 == null) continue;

          mLineBuffer[j++] = e1.x;
          mLineBuffer[j++] = e1.y * phaseY;

          if (isDrawSteppedEnabled) {
            mLineBuffer[j++] = e2.x;
            mLineBuffer[j++] = e1.y * phaseY;
            mLineBuffer[j++] = e2.x;
            mLineBuffer[j++] = e1.y * phaseY;
          }

          mLineBuffer[j++] = e2.x;
          mLineBuffer[j++] = e2.y * phaseY;
        }

        if (j > 0) {
          trans.pointValuesToPixel(mLineBuffer);

          final int size = max((xBounds.range + 1) * pointsPerEntryPair,
                  pointsPerEntryPair) *
              2;

          renderPaint..color = dataSet.getColor1();

          CanvasUtils.drawLines(canvas, mLineBuffer, 0, size, renderPaint,
              effect: dataSet.getDashPathEffect());
        }
      }
    }
  }

  Path _generateFilledPathBuffer = Path();

  /// Draws a filled linear path on the canvas.
  ///
  /// @param c
  /// @param dataSet
  /// @param trans
  /// @param bounds
  void drawLinearFill(
      Canvas c, ILineDataSet dataSet, Transformer trans, XBounds bounds) {
    final Path filled = _generateFilledPathBuffer;

    final int startingIndex = bounds.min;
    final int endingIndex = bounds.range + bounds.min;
    final int indexInterval = 128;

    int currentStartIndex = 0;
    int currentEndIndex = indexInterval;
    int iterations = 0;

    // Doing this iteratively in order to avoid OutOfMemory errors that can happen on large bounds sets.
    do {
      currentStartIndex = startingIndex + (iterations * indexInterval);
      currentEndIndex = currentStartIndex + indexInterval;
      currentEndIndex =
          currentEndIndex > endingIndex ? endingIndex : currentEndIndex;

      if (currentStartIndex <= currentEndIndex) {
        generateFilledPath(
            dataSet, currentStartIndex, currentEndIndex, filled, trans);

//        trans.pathValueToPixel(filled);

//        final Drawable drawable = dataSet.getFillDrawable();
//        if (drawable != null) {
//
//          drawFilledPath(c, filled, drawable);
//        } else {

        drawFilledPath2(
            c, filled, dataSet.getFillColor().value, dataSet.getFillAlpha());
//        }
      }

      iterations++;
    } while (currentStartIndex <= currentEndIndex);
  }

  /// Generates a path that is used for filled drawing.
  ///
  /// @param dataSet    The dataset from which to read the entries.
  /// @param startIndex The index from which to start reading the dataset
  /// @param endIndex   The index from which to stop reading the dataset
  /// @param outputPath The path object that will be assigned the chart data.
  /// @return
  void generateFilledPath(final ILineDataSet dataSet, final int startIndex,
      final int endIndex, final Path outputPath, final Transformer trans) {
    final double fillMin =
        dataSet.getFillFormatter().getFillLinePosition(dataSet, _provider);
    final double phaseY = animator.getPhaseY();
    final bool isDrawSteppedEnabled = dataSet.getMode() == Mode.STEPPED;

    List<double> points = List();
    final Path filled = outputPath;
    filled.reset();

    final Entry entry = dataSet.getEntryForIndex(startIndex);

    points.add(entry.x);
    points.add(fillMin);
    points.add(entry.x);
    points.add(entry.y * phaseY);
//    filled.moveTo(entry.x, fillMin);
//    filled.lineTo(entry.x, entry.y * phaseY);

    // create a  path
    Entry currentEntry;
    Entry previousEntry = entry;
    for (int x = startIndex + 1; x <= endIndex; x++) {
      currentEntry = dataSet.getEntryForIndex(x);

      if (isDrawSteppedEnabled) {
        points.add(currentEntry.x);
        points.add(previousEntry.y * phaseY);
//        filled.lineTo(currentEntry.x, previousEntry.y * phaseY);
      }

      points.add(currentEntry.x);
      points.add(currentEntry.y * phaseY);
//      filled.lineTo(currentEntry.x, currentEntry.y * phaseY);

      previousEntry = currentEntry;
    }

    // close up
    if (currentEntry != null) {
      points.add(currentEntry.x);
      points.add(fillMin);
//      filled.lineTo(currentEntry.x, fillMin);
    }

    trans.pointValuesToPixel(points);
    if (points.length > 2) {
      filled.moveTo(points[0], points[1]);
      for (int i = 2; i < points.length; i += 2) {
        filled.lineTo(points[i], points[i + 1]);
      }
    }

    filled.close();
  }

  @override
  void drawValues(Canvas c) {
    if (isDrawingValuesAllowed(_provider)) {
      List<ILineDataSet> dataSets = _provider.getLineData().dataSets;

      for (int i = 0; i < dataSets.length; i++) {
        ILineDataSet dataSet = dataSets[i];

        if (!shouldDrawValues(dataSet) || dataSet.getEntryCount() < 1) continue;

        // apply the text-styling defined by the DataSet
        applyValueTextStyle(dataSet);

        Transformer trans =
            _provider.getTransformer(dataSet.getAxisDependency());

        // make sure the values do not interfear with the circles
        int valOffset = (dataSet.getCircleRadius() * 1.75).toInt();

        if (!dataSet.isDrawCirclesEnabled()) valOffset = valOffset ~/ 2;

        xBounds.set(_provider, dataSet);

        List<double> positions = trans.generateTransformedValuesLine(
            dataSet,
            animator.getPhaseX(),
            animator.getPhaseY(),
            xBounds.min,
            xBounds.max);
        ValueFormatter formatter = dataSet.getValueFormatter();

        MPPointF iconsOffset = MPPointF.getInstance3(dataSet.getIconsOffset());
        iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
        iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

        for (int j = 0; j < positions.length; j += 2) {
          double x = positions[j];
          double y = positions[j + 1];

          if (!viewPortHandler.isInBoundsRight(x)) break;

          if (!viewPortHandler.isInBoundsLeft(x) ||
              !viewPortHandler.isInBoundsY(y)) continue;

          Entry entry = dataSet.getEntryForIndex(j ~/ 2 + xBounds.min);

          if (dataSet.isDrawValuesEnabled()) {
            drawValue(c, formatter.getPointLabel(entry), x, y - valOffset,
                dataSet.getValueTextColor2(j ~/ 2));
          }

          if (entry.mIcon != null && dataSet.isDrawIconsEnabled()) {
            CanvasUtils.drawImage(
                c,
                Offset(x + iconsOffset.x, y + iconsOffset.y),
                entry.mIcon,
                Size(15, 15),
                drawPaint);
          }
        }

        MPPointF.recycleInstance(iconsOffset);
      }
    }
  }

  @override
  void drawValue(Canvas c, String valueText, double x, double y, Color color) {
    valuePaint.text = TextSpan(
        text: valueText,
        style: TextStyle(
            color: color,
            fontSize: valuePaint.text?.style?.fontSize == null
                ? Utils.convertDpToPixel(9)
                : valuePaint.text.style.fontSize));
    valuePaint.layout();
    valuePaint.paint(
        c, Offset(x - valuePaint.width / 2, y - valuePaint.height));
  }

  @override
  void drawExtras(Canvas c) {
    drawCircles(c);
  }

  /**
   * cache for the circle bitmaps of all datasets
   */
//   HashMap<IDataSet, DataSetImageCache> mImageCaches =  HashMap<>();

  /// buffer for drawing the circles
  List<double> mCirclesBuffer = List(2);
  Map<IDataSet, DataSetImageCache> mImageCaches = Map();

  void drawCircles(Canvas c) {
    renderPaint..style = PaintingStyle.fill;

    double phaseY = animator.getPhaseY();

    mCirclesBuffer[0] = 0;
    mCirclesBuffer[1] = 0;

    List<ILineDataSet> dataSets = _provider.getLineData().dataSets;

    Transformer trans;
    for (int i = 0; i < dataSets.length; i++) {
      ILineDataSet dataSet = dataSets[i];

      if (!dataSet.isVisible() ||
          !dataSet.isDrawCirclesEnabled() ||
          dataSet.getEntryCount() == 0) continue;

      _circlePaintInner..color = dataSet.getCircleHoleColor();

      trans = _provider.getTransformer(dataSet.getAxisDependency());
      xBounds.set(_provider, dataSet);

      double circleRadius = dataSet.getCircleRadius();
      double circleHoleRadius = dataSet.getCircleHoleRadius();
      bool drawCircleHole = dataSet.isDrawCircleHoleEnabled() &&
          circleHoleRadius < circleRadius &&
          circleHoleRadius > 0;
      bool drawTransparentCircleHole = drawCircleHole &&
          dataSet.getCircleHoleColor() == ColorUtils.COLOR_NONE;

      int boundsRangeCount = xBounds.range + xBounds.min;

      for (int j = xBounds.min; j <= boundsRangeCount; j++) {
        Entry e = dataSet.getEntryForIndex(j);

        if (e == null) break;

        mCirclesBuffer[0] = e.x;
        mCirclesBuffer[1] = e.y * phaseY;

        trans.pointValuesToPixel(mCirclesBuffer);

        if (!viewPortHandler.isInBoundsRight(mCirclesBuffer[0])) break;

        if (!viewPortHandler.isInBoundsLeft(mCirclesBuffer[0]) ||
            !viewPortHandler.isInBoundsY(mCirclesBuffer[1])) continue;

        int colorCount = dataSet.getCircleColorCount();
        double circleRadius = dataSet.getCircleRadius();
        double circleHoleRadius = dataSet.getCircleHoleRadius();

        renderPaint..color = dataSet.getCircleColor(i % colorCount);

        if (drawTransparentCircleHole) {
          c.drawCircle(Offset(mCirclesBuffer[0], mCirclesBuffer[1]),
              circleRadius, renderPaint);

          c.drawCircle(Offset(mCirclesBuffer[0], mCirclesBuffer[1]),
              circleHoleRadius, renderPaint);
        } else {
          c.drawCircle(Offset(mCirclesBuffer[0], mCirclesBuffer[1]),
              circleRadius, renderPaint);

          if (drawCircleHole) {
            c.drawCircle(Offset(mCirclesBuffer[0], mCirclesBuffer[1]),
                circleHoleRadius, _circlePaintInner);
          }
        }
      }
    }
  }

  Future<Codec> _loadImage(ByteData data) async {
    if (data == null) throw 'Unable to read data';
    return await instantiateImageCodec(data.buffer.asUint8List());
  }

  @override
  void drawHighlighted(Canvas c, List<Highlight> indices) {
    LineData lineData = _provider.getLineData();

    for (Highlight high in indices) {
      ILineDataSet set = lineData.getDataSetByIndex(high.dataSetIndex);

      if (set == null || !set.isHighlightEnabled()) continue;

      Entry e = set.getEntryForXValue2(high.x, high.y);

      if (!isInBoundsX(e, set)) continue;

      MPPointD pix = _provider
          .getTransformer(set.getAxisDependency())
          .getPixelForValues(e.x, e.y * animator.getPhaseY());

      high.setDraw(pix.x, pix.y);

      // draw the lines
      drawHighlightLines(c, pix.x, pix.y, set);
    }
  }

//  /**
//   * Sets the Bitmap.Config to be used by this renderer.
//   * Default: Bitmap.Config.ARGB_8888
//   * Use Bitmap.Config.ARGB_4444 to consume less memory.
//   *
//   * @param config
//   */
//   void setBitmapConfig(Bitmap.Config config) {
//    mBitmapConfig = config;
//    releaseBitmap();
//  }
//
//  /**
//   * Returns the Bitmap.Config that is used by this renderer.
//   *
//   * @return
//   */
//   Bitmap.Config getBitmapConfig() {
//    return mBitmapConfig;
//  }
//
//  /**
//   * Releases the drawing bitmap. This should be called when {@link LineChart#onDetachedFromWindow()}.
//   */
//   void releaseBitmap() {
//    if (mBitmapCanvas != null) {
//      mBitmapCanvas.setBitmap(null);
//      mBitmapCanvas = null;
//    }
//    if (mDrawBitmap != null) {
//      Bitmap drawBitmap = mDrawBitmap.get();
//      if (drawBitmap != null) {
//        drawBitmap.recycle();
//      }
//      mDrawBitmap.clear();
//      mDrawBitmap = null;
//    }
//  }
}
