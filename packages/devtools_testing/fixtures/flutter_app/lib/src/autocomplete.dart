// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer' as developer;
import 'dart:math' as math;

// ignore: unused_import
import 'autocomplete_helper_library.dart';

export 'other_classes.dart';

class FooClass {
  FooClass();
  FooClass.namedConstructor();
  factory FooClass.factory1() => FooClass();

  int field1 = 1;
  int field2 = 2;
  static int staticField1 = 3;
  static int staticField2 = 4;
  static void staticMethod() {}
  void func1() {}
  void func2() {}

  int operator [](int index) {
    return 7;
  }
}

// ignore: unused_element
class _PrivateClass {}

class AnotherClass {
  int operator [](int index) {
    return 42;
  }

  static int someStaticMethod() {
    return math.max(3, 4);
  }

  void someInstanceMethod() {}

  void pauseWithScopedVariablesMethod() {
    // ignore: unused_local_variable, prefer_final_locals
    var foo = FooClass();
    // ignore: unused_local_variable, prefer_final_locals
    var foobar = 2;
    // ignore: unused_local_variable, prefer_final_locals
    var baz = 3;
    // ignore: unused_local_variable, prefer_final_locals
    var bar = 4;
    developer.debugger();
  }

  var someField = 3;
  static var someStaticField = 2;
  int get someProperty => 42;
  set someSomeProperty(v) {}
}

var someTopLevelField = 9;

int get someTopLevelGetter => 42;

set someTopLevelSetter(v) {}

void someTopLevelMember() {}

// ignore: unused_element
const _privateField1 = 1;
// ignore: unused_element
const _privateField2 = 2;
