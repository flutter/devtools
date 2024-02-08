// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dart_foo/dart_foo.dart';

// This is a script that uses `package:dart_foo`.
void main() async {
  final dartFoo = DartFoo();
  await dartFoo.loop();
}
