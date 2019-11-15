// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/controllers.dart';
import 'package:devtools_app/src/flutter/theme.dart';
import 'package:devtools_app/src/logging/logging_controller.dart';
import 'package:devtools_app/src/timeline/timeline_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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

Widget wrapWithProvidedController(
  Widget widget, {
  LoggingController loggingController,
  TimelineController timelineController,
}) {
  return MaterialApp(
    theme: themeFor(isDarkTheme: false),
    home: Material(
      child: Controllers.overridden(
        overrideProviders: () {
          return ProvidedControllers(
            logging: loggingController ?? MockLoggingController(),
            timeline: timelineController ?? MockTimelineController(),
          );
        },
        child: widget,
      ),
    ),
  );
}

/// Sets the size of the app window under test to [windowSize].
///
/// This must be reset on after each test invocation that calls
/// by using [resetWindowSize].
Future<void> setWindowSize(Size windowSize) async {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  await binding.setSurfaceSize(windowSize);
  binding.window.physicalSizeTestValue = windowSize;
  binding.window.devicePixelRatioTestValue = 1.0;
}

Future<void> resetWindowSize() async {
  await setWindowSize(const Size(800.0, 1200.0));
}
