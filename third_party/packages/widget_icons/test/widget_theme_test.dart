// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter_test/flutter_test.dart';
import 'package:widget_icons/widget_icons.dart';
import 'package:widget_icons/widget_theme.dart';

void main() {
  test('Correct asset from widget with a type', () {
    const String widgetName = 'AnimatedBuilder<String>';
    final theme = WidgetTheme.fromName(widgetName);
    expect(theme.icon, WidgetIcons.animated);
  });

  test('Has default theme for custom widget', () {
    const String widgetName = 'CustomWidget';
    final theme = WidgetTheme.fromName(widgetName);
    expect(theme.color, WidgetTheme.otherWidgetColor);
  });
}
