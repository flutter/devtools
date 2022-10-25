// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Mutable container for a value, to be used when ValueNotifier is too powerful.
class ValueContainer<T> implements ValueRef<T> {
  ValueContainer(this.value);

  @override
  T value;
}

/// Immutable container for a value, to be used when ValueListeneble is too powerful.
abstract class ValueRef<T> {
  T get value;
}
