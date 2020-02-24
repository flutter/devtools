import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart';

abstract class Matrix4Utils {
  static Matrix4 _multiply(Matrix4 first, Matrix4 second) {
    var f0 = first.storage[0]; // 123
    var f1 = first.storage[4]; // 567
    var f2 = first.storage[8];
    var f3 = first.storage[12];
    var f4 = first.storage[1];
    var f5 = first.storage[5];
    var f6 = first.storage[9];
    var f7 = first.storage[13];
    var f8 = first.storage[2];
    var f9 = first.storage[6];
    var f10 = first.storage[10];
    var f11 = first.storage[14];
    var f12 = first.storage[3];
    var f13 = first.storage[7];
    var f14 = first.storage[11];
    var f15 = first.storage[15];

    var s0 = second.storage[0]; // 123
    var s1 = second.storage[4]; // 567
    var s2 = second.storage[8];
    var s3 = second.storage[12];
    var s4 = second.storage[1];
    var s5 = second.storage[5];
    var s6 = second.storage[9];
    var s7 = second.storage[13];
    var s8 = second.storage[2];
    var s9 = second.storage[6];
    var s10 = second.storage[10];
    var s11 = second.storage[14];
    var s12 = second.storage[3];
    var s13 = second.storage[7];
    var s14 = second.storage[11];
    var s15 = second.storage[15];

    Matrix4 res = Matrix4.identity();

    res.storage[0] = f0 * s0 + f1 * s4 + f2 * s8 + f3 * s12; // 123
    res.storage[4] = f0 * s1 + f1 * s5 + f2 * s9 + f3 * s13; // 567
    res.storage[8] = f0 * s2 + f1 * s6 + f2 * s10 + f3 * s14;
    res.storage[12] = f0 * s3 + f1 * s7 + f2 * s11 + f3 * s15;

    res.storage[1] = f4 * s0 + f5 * s4 + f6 * s8 + f7 * s12;
    res.storage[5] = f4 * s1 + f5 * s5 + f6 * s9 + f7 * s13;
    res.storage[9] = f4 * s2 + f5 * s6 + f6 * s10 + f7 * s14;
    res.storage[13] = f4 * s3 + f5 * s7 + f6 * s11 + f7 * s15;

    res.storage[2] = f8 * s0 + f9 * s4 + f10 * s8 + f11 * s12;
    res.storage[6] = f8 * s1 + f9 * s5 + f10 * s9 + f11 * s13;
    res.storage[10] = f8 * s2 + f9 * s6 + f10 * s10 + f11 * s14;
    res.storage[14] = f8 * s3 + f9 * s7 + f10 * s11 + f11 * s15;

    res.storage[3] = f12 * s0 + f13 * s4 + f14 * s8 + f15 * s12;
    res.storage[7] = f12 * s1 + f13 * s5 + f14 * s9 + f15 * s13;
    res.storage[11] = f12 * s2 + f13 * s6 + f14 * s10 + f15 * s14;
    res.storage[15] = f12 * s3 + f13 * s7 + f14 * s11 + f15 * s15;

    return res;
  }

  static Matrix4 _getScaleTempMatrixByPoint(
      double sx, double sy, double px, double py) {
    return Matrix4.identity()
      ..storage[13] = py - sy * py
      ..storage[5] = sy
      ..storage[12] = px - sx * px
      ..storage[0] = sx;
  }

  static void postScaleByPoint(
      Matrix4 m, double sx, double sy, double px, double py) {
    var temp = _getScaleTempMatrixByPoint(sx, sy, px, py);
    postConcat(m, temp);
  }

  static void postScale(Matrix4 m, double sx, double sy) {
    m
      ..storage[13] *= sy
      ..storage[5] *= sy
      ..storage[12] *= sx
      ..storage[0] *= sx;
  }

  static void postTranslate(Matrix4 m, double tx, double ty) {
//    final Matrix4 result = Matrix4.identity()..setTranslationRaw(tx, ty, 0.0);
//    multiply(m, result).copyInto(m);
    m.storage[12] += tx;
    m.storage[13] += ty;
  }

  static void setTranslate(Matrix4 m, double tx, double ty) {
    (Matrix4.identity()..setTranslationRaw(tx, ty, 0.0)).copyInto(m);
  }

  static void mapPoints(Matrix4 m, List<double> valuePoints) {
    double x = 0;
    double y = 0;
    for (int i = 0; i < valuePoints.length; i += 2) {
      x = valuePoints[i] == null ? 0 : valuePoints[i];
      y = valuePoints[i + 1] == null ? 0 : valuePoints[i + 1];
      final Vector3 transformed = m.perspectiveTransform(Vector3(x, y, 0));
      valuePoints[i] = transformed.x;
      valuePoints[i + 1] = transformed.y;
    }
  }

  static void postConcat(Matrix4 m, Matrix4 c) {
    _multiply(c, m).copyInto(m);
  }

  static void preConcat(Matrix4 m, Matrix4 c) {
    _multiply(m, c).copyInto(m);
  }

  static void setScale(Matrix4 m, double sx, double sy) {
    m
      ..storage[0] = sx
      ..storage[1] = 0
      ..storage[2] = 0
      ..storage[3] = 0
      ..storage[4] = 0
      ..storage[5] = sy
      ..storage[6] = 0
      ..storage[7] = 0
      ..storage[8] = 0
      ..storage[9] = 0
      ..storage[10] = 1
      ..storage[11] = 0
      ..storage[12] = 0
      ..storage[13] = 0
      ..storage[14] = 0
      ..storage[15] = 1;
  }

  static void setScaleByPoint(
      Matrix4 m, double sx, double sy, double px, double py) {
    m
      ..storage[0] = sx
      ..storage[1] = 0
      ..storage[2] = 0
      ..storage[3] = 0
      ..storage[4] = 0
      ..storage[5] = sy
      ..storage[6] = 0
      ..storage[7] = 0
      ..storage[8] = 0
      ..storage[9] = 0
      ..storage[10] = 1
      ..storage[11] = 0
      ..storage[12] = px - sx * px
      ..storage[13] = py - sy * py
      ..storage[14] = 0
      ..storage[15] = 1;
  }

  static Rect mapRect(Matrix4 m, Rect r) {
    return MatrixUtils.transformRect(m, r);
  }

  static void moveTo(Path p, Matrix4 m, Offset o) {
    o = MatrixUtils.transformPoint(m, o);
    p.moveTo(o.dx, o.dy);
  }

  static void lineTo(Path p, Matrix4 m, Offset o) {
    o = MatrixUtils.transformPoint(m, o);
    p.lineTo(o.dx, o.dy);
  }

  static void cubicTo(Path p, Matrix4 m, Offset o1, Offset o2, Offset o3) {
    o1 = MatrixUtils.transformPoint(m, o1);
    o2 = MatrixUtils.transformPoint(m, o2);
    o3 = MatrixUtils.transformPoint(m, o3);
    p.cubicTo(o1.dx, o1.dy, o2.dx, o2.dy, o3.dx, o3.dy);
  }
}
