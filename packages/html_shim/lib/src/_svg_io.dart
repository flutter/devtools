// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// This library is a minimal fork of dart:svg with just functionality needed to
/// make the html library valid.
library svg;

import '_html_common_io.dart';

@Unstable()
@Native("SVGMatrix")
class Matrix extends Interceptor {
  // To suppress missing implicit constructor warnings.
  factory Matrix._() {
    throw new UnsupportedError("Not supported");
  }

  num a;

  num b;

  num c;

  num d;

  num e;

  num f;

  Matrix flipX() => unsupported();

  Matrix flipY() => unsupported();

  Matrix inverse() => unsupported();

  Matrix multiply(Matrix secondMatrix) => unsupported();

  Matrix rotate(num angle) => unsupported();

  Matrix rotateFromVector(num x, num y) => unsupported();

  Matrix scale(num scaleFactor) => unsupported();

  Matrix scaleNonUniform(num scaleFactorX, num scaleFactorY) => unsupported();

  Matrix skewX(num angle) => unsupported();

  Matrix skewY(num angle) => unsupported();

  Matrix translate(num x, num y) => unsupported();
}
