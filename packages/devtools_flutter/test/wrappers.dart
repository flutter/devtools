// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [widget] with the build context it needs to load in a test.
Widget wrap(Widget widget) => MaterialApp(home: widget);

Widget wrapWithMaterial(Widget widget) => wrap(Material(child: widget));

/// Sets the size of the app window under test to [windowSize].
///
/// This will be reset on each test invocation, so it doesn't need to be reset
/// in [tearDown] calls.
Future<void> setWindowSize(Size windowSize) async {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  await binding.setSurfaceSize(windowSize);
  binding.window.physicalSizeTestValue = windowSize;
  binding.window.devicePixelRatioTestValue = 1.0;
}
