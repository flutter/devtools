// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:widget_icons/widget_icons.dart';

void main() {
  runApp(const MaterialApp(home: HomePage()));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: const [
          IconContainer(
            icon: WidgetIcons.alert_dialog,
            name: 'alert_dialog',
          ),
          IconContainer(
            icon: WidgetIcons.align,
            name: 'align',
          ),
          IconContainer(
            icon: WidgetIcons.animated,
            name: 'animated',
          ),
          IconContainer(
            icon: WidgetIcons.app_bar,
            name: 'app_bar',
          ),
          IconContainer(
            icon: WidgetIcons.bottom_bar,
            name: 'bottom_bar',
          ),
          IconContainer(
            icon: WidgetIcons.card,
            name: 'card',
          ),
          IconContainer(
            icon: WidgetIcons.center,
            name: 'center',
          ),
          IconContainer(
            icon: WidgetIcons.checkbox,
            name: 'checkbox',
          ),
          IconContainer(
            icon: WidgetIcons.circle_avatar,
            name: 'circle_avatar',
          ),
          IconContainer(
            icon: WidgetIcons.circular_progress,
            name: 'circular_progress',
          ),
          IconContainer(
            icon: WidgetIcons.column,
            name: 'column',
          ),
          IconContainer(
            icon: WidgetIcons.constrained_box,
            name: 'constrained_box',
          ),
          IconContainer(
            icon: WidgetIcons.container,
            name: 'container',
          ),
          IconContainer(
            icon: WidgetIcons.divider,
            name: 'divider',
          ),
          IconContainer(
            icon: WidgetIcons.drawer,
            name: 'drawer',
          ),
          IconContainer(
            icon: WidgetIcons.flexible,
            name: 'flexible',
          ),
          IconContainer(
            icon: WidgetIcons.floating_action_button,
            name: 'floating_action_button',
          ),
          IconContainer(
            icon: WidgetIcons.gesture,
            name: 'gesture',
          ),
          IconContainer(
            icon: WidgetIcons.grid_view,
            name: 'grid_view',
          ),
          IconContainer(
            icon: WidgetIcons.hero,
            name: 'hero',
          ),
          IconContainer(
            icon: WidgetIcons.icon,
            name: 'icon',
          ),
          IconContainer(
            icon: WidgetIcons.image,
            name: 'image',
          ),
          IconContainer(
            icon: WidgetIcons.inkwell,
            name: 'inkwell',
          ),
          IconContainer(
            icon: WidgetIcons.list_view,
            name: 'list_view',
          ),
          IconContainer(
            icon: WidgetIcons.material,
            name: 'material',
          ),
          IconContainer(
            icon: WidgetIcons.opacity,
            name: 'opacity',
          ),
          IconContainer(
            icon: WidgetIcons.outlined_button,
            name: 'outlined_button',
          ),
          IconContainer(
            icon: WidgetIcons.padding,
            name: 'padding',
          ),
          IconContainer(
            icon: WidgetIcons.page_view,
            name: 'page_view',
          ),
          IconContainer(
            icon: WidgetIcons.radio_button,
            name: 'radio_button',
          ),
          IconContainer(
            icon: WidgetIcons.root,
            name: 'root',
          ),
          IconContainer(
            icon: WidgetIcons.row,
            name: 'row',
          ),
          IconContainer(
            icon: WidgetIcons.scaffold,
            name: 'scaffold',
          ),
          IconContainer(
            icon: WidgetIcons.scroll,
            name: 'scroll',
          ),
          IconContainer(
            icon: WidgetIcons.sized_box,
            name: 'sized_box',
          ),
          IconContainer(
            icon: WidgetIcons.stack,
            name: 'stack',
          ),
          IconContainer(
            icon: WidgetIcons.tab,
            name: 'tab',
          ),
          IconContainer(
            icon: WidgetIcons.text,
            name: 'text',
          ),
          IconContainer(
            icon: WidgetIcons.text_button,
            name: 'text_button',
          ),
          IconContainer(
            icon: WidgetIcons.toggle,
            name: 'toggle',
          ),
          IconContainer(
            icon: WidgetIcons.transition,
            name: 'transition',
          ),
          IconContainer(
            icon: WidgetIcons.wrap,
            name: 'wrap',
          ),
        ],
      ),
    );
  }
}

class IconContainer extends StatelessWidget {
  final IconData icon;
  final String name;

  const IconContainer({
    super.key,
    required this.icon,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 100),
        Text(name),
        const SizedBox(height: 40),
      ],
    );
  }
}
