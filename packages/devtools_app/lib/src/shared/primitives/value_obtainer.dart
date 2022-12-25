// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

class ListenebleAsObtainer<T> implements ValueObtainer<T> {
  ListenebleAsObtainer(this._listeneble);

  final ValueListenable<T> _listeneble;

  @override
  T get value => _listeneble.value;
}

class FunctionAsObtainer<T> implements ValueObtainer<T> {
  FunctionAsObtainer(this._function);

  final T Function() _function;

  @override
  T get value => _function();
}

class ValueAsObtainer<T> implements ValueObtainer<T> {
  ValueAsObtainer(this.value);

  @override
  T value;
}

/// Use this interface when the client needs
/// access to the current value, but does not need the value to be listeneble,
/// i.e. [ValueListeneble] would be too strong requirement.
abstract class ValueObtainer<T> {
  T get value;
}
