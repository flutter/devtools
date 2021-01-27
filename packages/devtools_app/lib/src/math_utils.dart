// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

// TODO(jacobr): move more math utils over to this library.

double sum(Iterable<double> numbers) =>
    numbers.fold(0, (sum, cur) => sum + cur);

double min(Iterable<double> numbers) =>
    numbers.fold(double.infinity, (minimum, cur) => math.min(minimum, cur));

double max(Iterable<double> numbers) =>
    numbers.fold(-double.infinity, (minimum, cur) => math.max(minimum, cur));
