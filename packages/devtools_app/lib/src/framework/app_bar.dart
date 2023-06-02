// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../shared/common_widgets.dart';
import '../shared/screen.dart';
import '../shared/theme.dart';

class TabOverflowButton extends StatelessWidget {
  const TabOverflowButton({
    super.key,
    required this.screens,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const width = 40.0;

  final List<Screen> screens;

  final int selectedIndex;

  bool get overflowTabSelected => selectedIndex >= 0;

  final Function(int) onItemSelected;

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primary;
    final button = ContextMenuButton(
      icon: Icons.keyboard_double_arrow_right,
      iconSize: actionsIconSize,
      color: overflowTabSelected ? selectedColor : null,
      buttonWidth: buttonMinWidth,
      menuChildren: _buildChildren(context),
    );
    return overflowTabSelected ? SelectedTabWrapper(child: button) : button;
  }

  List<Widget> _buildChildren(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (int i = 0; i < screens.length; i++) {
      final screen = screens[i];
      var tab = screen.buildTab(context);
      if (i == selectedIndex) {
        final tabWidth = screen.approximateTabWidth(
          theme.textTheme,
          includeTabBarSpacing: false,
        );
        tab = SelectedTabWrapper(
          width: tabWidth,
          child: Container(
            width: tabWidth,
            alignment: Alignment.center,
            child: tab,
          ),
        );
      }
      children.add(
        SizedBox(
          // Match the height of the main tab bar.
          height: defaultToolbarHeight,
          child: MenuItemButton(
            style: const ButtonStyle().copyWith(
              textStyle: MaterialStateProperty.resolveWith<TextStyle>((_) {
                return theme.textTheme.titleSmall!;
              }),
            ),
            onPressed: () => onItemSelected(i),
            child: tab,
          ),
        ),
      );
    }
    return children;
  }
}

@visibleForTesting
class SelectedTabWrapper extends StatelessWidget {
  SelectedTabWrapper({super.key, required this.child, double? width})
      : width = width ?? buttonMinWidth;

  final Widget child;

  final double width;

  static const _selectedIndicatorHeight = 3.0;

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primary;
    const radius = Radius.circular(_selectedIndicatorHeight);
    return Stack(
      children: [
        child,
        Positioned(
          bottom: 0.0,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: radius,
              topRight: radius,
            ),
            child: Container(
              height: _selectedIndicatorHeight,
              width: width,
              color: selectedColor,
            ),
          ),
        ),
      ],
    );
  }
}

class DevToolsTitle extends StatelessWidget {
  const DevToolsTitle({super.key, required this.title});

  final String title;

  static double get paddingSize =>
      intermediateSpacing * 2 + VerticalLineSpacer.totalWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).devToolsTitleStyle,
        ),
        const SizedBox(width: intermediateSpacing),
        VerticalLineSpacer(height: defaultToolbarHeight),
      ],
    );
  }
}

// TODO(kenz): make private once app bar code is refactored out of scaffold.dart
// and into this file.
double calculateTitleWidth(
  String title, {
  required TextTheme textTheme,
  bool includeTitlePadding = true,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: title,
      style: textTheme.titleMedium,
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  // Approximate size of the title. Add [defaultSpacing] to account for
  // title's leading padding.
  return painter.width + (includeTitlePadding ? DevToolsTitle.paddingSize : 0);
}
