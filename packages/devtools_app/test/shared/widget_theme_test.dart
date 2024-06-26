// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/inspector/layout_explorer/ui/widgets_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test WidgetTheme', () {
    test('Correct asset from widget with a type', () {
      const widgetName = 'AnimatedBuilder<String>';
      final theme = WidgetTheme.fromName(widgetName);
      expect(theme.iconAsset, 'icons/inspector/widget_icons/animated.png');
    });

    test('Has default theme for custom widget', () {
      const widgetName = 'CustomWidget';
      final theme = WidgetTheme.fromName(widgetName);
      expect(theme.color, WidgetTheme.otherWidgetColor);
    });
  });
}
