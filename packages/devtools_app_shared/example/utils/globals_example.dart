// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';

void main() {
  setAndAccessGlobal();
}

/// This method demonstrates setting and accessing globals, which is
/// functionality exposed by 'package:devtools_app_shared/utils.dart'.
void setAndAccessGlobal() {
  // Creates a globally accessible variable (`globals[ServiceManager]`);
  setGlobal(MyCoolClass, MyCoolClass());
  // Access the variable directory from [globals].
  final coolClassFromGlobals = globals[MyCoolClass] as MyCoolClass;
  coolClassFromGlobals.foo();

  // OR (recommended) access the global from a top level getter.
  coolClass.foo();
}

MyCoolClass get coolClass => globals[MyCoolClass] as MyCoolClass;

class MyCoolClass {
  void foo() {
    print('foo');
  }
}
