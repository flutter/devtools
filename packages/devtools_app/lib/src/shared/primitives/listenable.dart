// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

/// A [ValueListenable] that ignores all added listeners and returns a fixed
/// value.
class FixedValueListenable<T> extends ValueListenable<T> {
  const FixedValueListenable(this._value);

  final T _value;

  @override
  void addListener(listener) => null;

  @override
  void removeListener(listener) => null;

  @override
  T get value => _value;
}
