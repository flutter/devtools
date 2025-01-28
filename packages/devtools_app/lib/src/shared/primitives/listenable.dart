// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/foundation.dart';

/// A [ValueListenable] that ignores all added listeners and returns a fixed
/// value.
class FixedValueListenable<T> extends ValueListenable<T> {
  const FixedValueListenable(this._value);

  final T _value;

  @override
  void addListener(void Function() listener) {}

  @override
  void removeListener(void Function() listener) {}

  @override
  T get value => _value;
}
