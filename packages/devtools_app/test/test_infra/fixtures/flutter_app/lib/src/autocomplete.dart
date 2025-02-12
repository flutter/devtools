// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:developer' as developer;
import 'dart:math' as math;

// These lints get in the way of testing autocomplete.
// ignore_for_file: unused_import, unused_local_variable, unused_element, prefer_final_locals

import 'autocomplete_helper_library.dart';

export 'other_classes.dart';

// Unused parameters are needed to test autocomplete.
// ignore_for_file: avoid-unused-parameters
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
    var foo = FooClass();
    var foobar = 2;
    var baz = 3;
    var bar = 4;
    developer.debugger();
  }

  var someField = 3;
  static var someStaticField = 2;
  int get someProperty => 42;
  // ignore: avoid-dynamic, gets in the way of testing.
  set someSomeProperty(v) {}
}

var someTopLevelField = 9;

int get someTopLevelGetter => 42;

set someTopLevelSetter(v) {}

void someTopLevelMember() {}

const _privateField1 = 1;
const _privateField2 = 2;
