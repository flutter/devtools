// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

mixin CompareMixin<T> implements Comparable<T> {
  bool operator <(T other) {
    return compareTo(other) < 0;
  }

  bool operator >(T other) {
    return compareTo(other) > 0;
  }

  bool operator <=(T other) {
    return compareTo(other) <= 0;
  }

  bool operator >=(T other) {
    return compareTo(other) >= 0;
  }
}
