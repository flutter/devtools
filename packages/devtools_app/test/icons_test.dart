// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/ui/icons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test WidgetIcons', () {
    test('Correct asset from widget with a type', () {
      const String widgetName = 'AnimatedBuilder<String>';
      final asset = WidgetIcons.getAssetName(widgetName);
      expect(asset, 'icons/inspector/widget_icons/animated.png');
    });

    test('Null asset if widget is not in the icon map', () {
      const String widgetName = 'CustomWidget';
      final asset = WidgetIcons.getAssetName(widgetName);
      expect(asset, null);
    });
  });
}
