// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

class A {
  String get name => '';
  set name(String value) {}

  void method() {}
  void get() {}
  void set() {}
}

mixin MyMixin<T> on List<T> {}
