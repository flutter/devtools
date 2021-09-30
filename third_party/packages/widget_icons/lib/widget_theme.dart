// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:widget_icons/widget_icons.dart';

class WidgetTheme {
  const WidgetTheme({
    this.icon,
    this.color = otherWidgetColor,
  });

  final IconData? icon;
  final Color color;

  static WidgetTheme fromName(String? widgetType) {
    if (widgetType == null) {
      return const WidgetTheme();
    }

    return themeMap[_stripBrackets(widgetType)] ?? const WidgetTheme();
  }

  /// Strips the brackets off the widget name.
  ///
  /// For example: `AnimatedBuilder<String>` -> `AnimatedBuilder`.
  static String _stripBrackets(String widgetType) {
    final bracketIndex = widgetType.indexOf('<');
    if (bracketIndex == -1) {
      return widgetType;
    }

    return widgetType.substring(0, bracketIndex);
  }

  static const contentWidgetColor = Color(0xff06AC3B);
  static const highLevelWidgetColor = Color(0xffAEAEB1);
  static const animationWidgetColor = Color(0xffE09D0E);
  static const otherWidgetColor = Color(0xff0EA7E0);

  static const animatedTheme = WidgetTheme(
    icon: WidgetIcons.animated,
    color: animationWidgetColor,
  );

  static const transitionTheme = WidgetTheme(
    icon: WidgetIcons.transition,
    color: animationWidgetColor,
  );

  static const textTheme = WidgetTheme(
    icon: WidgetIcons.text,
    color: contentWidgetColor,
  );

  static const imageTheme = WidgetTheme(
    icon: WidgetIcons.image,
    color: contentWidgetColor,
  );

  static const tabTheme = WidgetTheme(icon: WidgetIcons.tab);
  static const scrollTheme = WidgetTheme(icon: WidgetIcons.scroll);
  static const highLevelTheme = WidgetTheme(color: highLevelWidgetColor);
  static const listTheme = WidgetTheme(icon: WidgetIcons.list_view);
  static const flexibleTheme = WidgetTheme(icon: WidgetIcons.flexible);
  static const alignTheme = WidgetTheme(icon: WidgetIcons.align);
  static const gestureTheme = WidgetTheme(icon: WidgetIcons.gesture);
  static const textButtonTheme = WidgetTheme(icon: WidgetIcons.text_button);
  static const toggleTheme = WidgetTheme(
    icon: WidgetIcons.toggle,
    color: contentWidgetColor,
  );

  static const Map<String, WidgetTheme> themeMap = {
    // High-level
    'RenderObjectToWidgetAdapter': WidgetTheme(
      icon: WidgetIcons.root,
      color: highLevelWidgetColor,
    ),
    'CupertinoApp': highLevelTheme,
    'MaterialApp': highLevelTheme,
    'WidgetsApp': highLevelTheme,

    // Text
    'DefaultTextStyle': textTheme,
    'RichText': textTheme,
    'SelectableText': textTheme,
    'Text': textTheme,

    // Images
    'Icon': imageTheme,
    'Image': imageTheme,
    'RawImage': imageTheme,

    // Animations
    'AnimatedAlign': animatedTheme,
    'AnimatedBuilder': animatedTheme,
    'AnimatedContainer': animatedTheme,
    'AnimatedCrossFade': animatedTheme,
    'AnimatedDefaultTextStyle': animatedTheme,
    'AnimatedListState': animatedTheme,
    'AnimatedModalBarrier': animatedTheme,
    'AnimatedOpacity': animatedTheme,
    'AnimatedPhysicalModel': animatedTheme,
    'AnimatedPositioned': animatedTheme,
    'AnimatedSize': animatedTheme,
    'AnimatedWidget': animatedTheme,

    // Transitions
    'DecoratedBoxTransition': transitionTheme,
    'FadeTransition': transitionTheme,
    'PositionedTransition': transitionTheme,
    'RotationTransition': transitionTheme,
    'ScaleTransition': transitionTheme,
    'SizeTransition': transitionTheme,
    'SlideTransition': transitionTheme,
    'Hero': WidgetTheme(
      icon: WidgetIcons.hero,
      color: animationWidgetColor,
    ),

    // Scroll
    'CustomScrollView': scrollTheme,
    'DraggableScrollableSheet': scrollTheme,
    'SingleChildScrollView': scrollTheme,
    'Scrollable': scrollTheme,
    'Scrollbar': scrollTheme,
    'ScrollConfiguration': scrollTheme,
    'GridView': WidgetTheme(icon: WidgetIcons.grid_view),
    'ListView': listTheme,
    'ReorderableListView': listTheme,
    'NestedScrollView': listTheme,

    // Input
    'Checkbox': WidgetTheme(
      icon: WidgetIcons.checkbox,
      color: contentWidgetColor,
    ),
    'Radio': WidgetTheme(
      icon: WidgetIcons.radio_button,
      color: contentWidgetColor,
    ),
    'Switch': toggleTheme,
    'CupertinoSwitch': toggleTheme,

    // Layout
    'Container': WidgetTheme(icon: WidgetIcons.container),
    'Center': WidgetTheme(icon: WidgetIcons.center),
    'Row': WidgetTheme(icon: WidgetIcons.row),
    'Column': WidgetTheme(icon: WidgetIcons.column),
    'Padding': WidgetTheme(icon: WidgetIcons.padding),
    'SizedBox': WidgetTheme(icon: WidgetIcons.sized_box),
    'ConstrainedBox': WidgetTheme(icon: WidgetIcons.constrained_box),
    'Align': alignTheme,
    'Positioned': alignTheme,
    'Expanded': flexibleTheme,
    'Flexible': flexibleTheme,
    'Stack': WidgetTheme(icon: WidgetIcons.stack),
    'Wrap': WidgetTheme(icon: WidgetIcons.wrap),

    // Buttons
    'FloatingActionButton': WidgetTheme(
      icon: WidgetIcons.floating_action_button,
      color: contentWidgetColor,
    ),
    'InkWell': WidgetTheme(icon: WidgetIcons.inkwell),
    'GestureDetector': gestureTheme,
    'RawGestureDetector': gestureTheme,
    'TextButton': textButtonTheme,
    'CupertinoButton': textButtonTheme,
    'ElevatedButton': textButtonTheme,
    'OutlinedButton': WidgetTheme(icon: WidgetIcons.outlined_button),

    // Tabs
    'Tab': tabTheme,
    'TabBar': tabTheme,
    'TabBarView': tabTheme,
    'BottomNavigationBar': tabTheme,
    'CupertinoTabScaffold': tabTheme,
    'CupertinoTabView': tabTheme,

    // Other
    'Scaffold': WidgetTheme(icon: WidgetIcons.scaffold),
    'CircularProgressIndicator':
        WidgetTheme(icon: WidgetIcons.circular_progress),
    'Card': WidgetTheme(icon: WidgetIcons.card),
    'Divider': WidgetTheme(icon: WidgetIcons.divider),
    'AlertDialog': WidgetTheme(icon: WidgetIcons.alert_dialog),
    'CircleAvatar': WidgetTheme(icon: WidgetIcons.circle_avatar),
    'Opacity': WidgetTheme(icon: WidgetIcons.opacity),
    'Drawer': WidgetTheme(icon: WidgetIcons.drawer),
    'PageView': WidgetTheme(icon: WidgetIcons.page_view),
    'Material': WidgetTheme(icon: WidgetIcons.material),
  };
}
