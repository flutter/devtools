// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/landing_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/wrappers.dart';

void main() {
  testWidgets('Landing screen displays without error',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(wrap(LandingScreenBody()));
    expect(find.text('Connect to a Running App'), findsOneWidget);
    expect(find.text('App Size Tooling'), findsOneWidget);
  });
}
