// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../shared/common_widgets.dart';
import '../shared/primitives/utils.dart';
import '../shared/screen.dart';

class DevToolsAppBar extends StatelessWidget {
  const DevToolsAppBar({
    super.key,
    required this.tabController,
    required this.screens,
    required this.actions,
  });

  final TabController? tabController;

  final List<Screen> screens;

  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget? flexibleSpace;
    TabBar tabBar;

    List<Screen> visibleScreens = screens;
    bool tabsOverflow({bool includeOverflowButtonWidth = false}) {
      return _scaffoldHeaderWidth(
                screens: visibleScreens,
                actions: actions,
                textTheme: textTheme,
              ) +
              (includeOverflowButtonWidth ? TabOverflowButton.width : 0) >=
          MediaQuery.of(context).size.width;
    }

    var overflow = tabsOverflow();
    while (overflow) {
      visibleScreens = List.of(visibleScreens)..safeRemoveLast();
      overflow = tabsOverflow(includeOverflowButtonWidth: true);
      if (overflow && visibleScreens.isEmpty) {
        break;
      }
    }
    final overflowScreens = screens.sublist(visibleScreens.length);

    // Add a leading [VerticalLineSpacer] to the actions to separate them from
    // the tabs.
    final actionsWithSpacer = List<Widget>.from(actions ?? [])
      ..insert(0, VerticalLineSpacer(height: defaultToolbarHeight));

    final bool hasMultipleTabs = screens.length > 1;
    if (hasMultipleTabs) {
      tabBar = TabBar(
        controller: tabController,
        isScrollable: true,
        labelPadding: EdgeInsets.zero,
        tabs: [
          for (var screen in visibleScreens)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: tabBarSpacing),
              child: screen.buildTab(context),
            ),
          // We need to include a widget in the tab bar for the overflow screens
          // because the [_tabController] expects a length equal to the total
          // number of screens, hidden or not.
          for (var _ in overflowScreens) const SizedBox.shrink(),
        ],
      );

      final rightPadding = math.max(
        0.0,
        // Use [actions] here instead of [actionsWithSpacer] because we may
        // have added a spacer element to [actionsWithSpacer] above, which
        // should be excluded from the width calculation.
        actionWidgetSize * ((actions ?? []).length) +
            VerticalLineSpacer.totalWidth,
      );

      flexibleSpace = Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            top: densePadding,
            right: rightPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              tabBar,
              if (overflowScreens.isNotEmpty)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TabOverflowButton(
                      screens: overflowScreens,
                      selectedIndex:
                          tabController!.index - visibleScreens.length,
                      onItemSelected: (index) {
                        final selectedTabIndex = visibleScreens.length + index;
                        tabController!.index = selectedTabIndex;
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return AppBar(
      // Turn off the appbar's back button.
      automaticallyImplyLeading: false,
      centerTitle: false,
      toolbarHeight: defaultToolbarHeight,
      actions: actionsWithSpacer,
      flexibleSpace: flexibleSpace,
    );
  }

  /// Returns the width of the scaffold title, tabs and default icons.
  double _scaffoldHeaderWidth({
    required List<Screen> screens,
    required List<Widget>? actions,
    required TextTheme textTheme,
  }) {
    final tabsWidth = screens.fold(
      0.0,
      (prev, screen) => prev + screen.approximateTabWidth(textTheme),
    );
    final actionsWidth = (actions?.length ?? 0) * actionWidgetSize;
    return tabsWidth + VerticalLineSpacer.totalWidth + actionsWidth;
  }
}

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

  final void Function(int) onItemSelected;

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primary;
    final button = ContextMenuButton(
      icon: Icons.keyboard_double_arrow_right_sharp,
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
        PointerInterceptor(
          child: SizedBox(
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
