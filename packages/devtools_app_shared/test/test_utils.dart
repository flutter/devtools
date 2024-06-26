// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: these helpers are duplicated from `package:devtools_test`. We copied
// them instead of importing `devtools_test`, because `devtools_test` is not
// published on pub.dev, and package `devtools_app_shared` will be.

/// Wraps [widget] with the build context it needs to load in a test.
///
/// This includes a [MaterialApp] to provide context like [Theme.of], a
/// [Material] to support elements like [TextField] that draw ink effects, and a
/// [Directionality] to support [RenderFlex] widgets like [Row] and [Column].
Widget wrap(Widget widget) {
  return MaterialApp(
    theme: themeFor(
      isDarkTheme: false,
      ideTheme: IdeTheme(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
      ),
    ),
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: widget,
    ),
  );
}

/// Runs a test with the size of the app window under test to [windowSize].
void testWidgetsWithWindowSize(
  String name,
  Size windowSize,
  WidgetTesterCallback test, {
  bool skip = false,
}) {
  testWidgets(
    name,
    (WidgetTester tester) async {
      await _setWindowSize(tester, windowSize);
      await test(tester);
      await _resetWindowSize(tester);
    },
    skip: skip,
  );
}

Future<void> _setWindowSize(WidgetTester tester, Size windowSize) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  await binding.setSurfaceSize(windowSize);
  tester.view.physicalSize = windowSize;
  tester.view.devicePixelRatio = 1.0;
}

Future<void> _resetWindowSize(WidgetTester tester) async {
  await _setWindowSize(tester, const Size(800.0, 600.0));
}
