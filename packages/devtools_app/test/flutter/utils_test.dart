// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogicalKeySetExtension', () {
    testWidgets('meta non-mac', (WidgetTester tester) async {
      final keySet =
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyP);
      expect(keySet.describeKeys(), 'Meta-P');
    });

    testWidgets('meta mac', (WidgetTester tester) async {
      final keySet =
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyP);
      expect(keySet.describeKeys(isMacOS: true), '⌘P');
    });

    testWidgets('ctrl', (WidgetTester tester) async {
      final keySet =
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP);
      expect(keySet.describeKeys(), 'Control-P');
    });
  });
}
