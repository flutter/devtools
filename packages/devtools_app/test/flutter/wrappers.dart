// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/controllers.dart';
import 'package:devtools_app/src/flutter/theme.dart';
import 'package:devtools_app/src/logging/logging_controller.dart';
import 'package:devtools_app/src/memory/memory_controller.dart';
import 'package:devtools_app/src/timeline/timeline_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

import '../support/mocks.dart';

/// Wraps [widget] with the build context it needs to load in a test.
///
/// This includes a [MaterialApp] to provide context like [Theme.of].
/// It also provides a [Material] to support elements like [TextField] that
/// draw ink effects.
Widget wrap(Widget widget) {
  return MaterialApp(
    theme: themeFor(isDarkTheme: false),
    home: Material(child: widget),
  );
}

Widget wrapWithControllers(
  Widget widget, {
  LoggingController loggingController,
  MemoryController memoryController,
  TimelineController timelineController,
}) {
  return MaterialApp(
    theme: themeFor(isDarkTheme: false),
    home: Material(
      child: Controllers.overridden(
        overrideProviders: () {
          return ProvidedControllers(
            logging: loggingController ?? MockLoggingController(),
            memory: memoryController ?? MockMemoryController(),
            timeline: timelineController ?? MockTimelineController(),
          );
        },
        child: widget,
      ),
    ),
  );
}

/// Runs a test with the size of the app window under test to [windowSize].
@isTest
void testWidgetsWithWindowSize(
  String name,
  Size windowSize,
  WidgetTesterCallback test, {
  bool skip = false,
}) {
  testWidgets(name, (WidgetTester tester) async {
    await _setWindowSize(windowSize);
    await test(tester);
    await _resetWindowSize();
  }, skip: skip);
}

Future<void> _setWindowSize(Size windowSize) async {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  await binding.setSurfaceSize(windowSize);
  binding.window.physicalSizeTestValue = windowSize;
  binding.window.devicePixelRatioTestValue = 1.0;
}

Future<void> _resetWindowSize() async {
  await _setWindowSize(const Size(800.0, 600.0));
}
