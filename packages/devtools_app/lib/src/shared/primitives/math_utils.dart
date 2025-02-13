// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
import 'dart:math' as math;

// TODO(jacobr): move more math utils over to this library.

double sum(Iterable<double> numbers) =>
    numbers.fold(0, (sum, cur) => sum + cur);

double min(Iterable<double> numbers) =>
    numbers.fold(double.infinity, (minimum, cur) => math.min(minimum, cur));

double max(Iterable<double> numbers) =>
    numbers.fold(-double.infinity, (minimum, cur) => math.max(minimum, cur));
