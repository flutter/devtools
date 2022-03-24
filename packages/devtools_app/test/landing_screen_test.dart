// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/landing_screen.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceManager());
    setGlobal(IdeTheme, IdeTheme());
  });

  testWidgetsWithWindowSize(
      'Landing screen displays without error', const Size(2000.0, 2000.0),
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(wrap(LandingScreenBody()));
    expect(find.text('Connect to a Running App'), findsOneWidget);
    expect(find.text('App Size Tooling'), findsOneWidget);
  });
}
