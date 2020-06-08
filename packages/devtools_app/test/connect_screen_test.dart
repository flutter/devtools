// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/connect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/wrappers.dart';

void main() {
  testWidgets('Connect screen displays without error',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(wrap(ConnectScreenBody()));
    expect(find.byKey(const Key('Connect Title')), findsOneWidget);
  });
}
