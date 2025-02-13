// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

class A {
  String get name => '';
  set name(String value) {}

  void method() {}
  void get() {}
  void set() {}
}

mixin MyMixin<T> on List<T> {}
