// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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
