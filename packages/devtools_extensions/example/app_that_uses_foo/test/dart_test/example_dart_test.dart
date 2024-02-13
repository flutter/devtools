// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dart_foo/dart_foo.dart';
import 'package:test/test.dart';

// This test can be run to verify that the `package:foo` DevTools extension
// loads properly when debugging a Dart test target with DevTools.
//
// This doubles as a test to make sure the DevTools extension loads properly
// when the test target is in a subdirectory of 'test/'.
//
// To test this, run the following command and copy the VM service URI to
// connect to DevTools:
//
// dart run test/dart_test/example_dart_test.dart --start-paused

void main() {
  test('a simple dart test', () {
    final dartFoo = DartFoo();
    dartFoo.foo();
    expect(1 + 1, 2);
    expect(1 + 2, 3);
  });
}
