// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils.dart';

/// Navigates to each visible DevTools screen.
Future<void> navigateThroughDevToolsScreens(
  WidgetController controller, {
  bool runWithExpectations = true,
}) async {
  final visibleScreenIds = generateVisibleScreenIds();
  final tabs = controller.widgetList<Tab>(
    find.descendant(
      of: find.byType(DevToolsAppBar),
      matching: find.byType(Tab),
    ),
  );

  var numTabs = tabs.length;
  if (numTabs < visibleScreenIds.length) {
    final tabOverflowMenuFinder = find.descendant(
      of: find.byType(TabOverflowButton),
      matching: find.byType(MenuAnchor),
    );
    _maybeExpect(
      tabOverflowMenuFinder,
      findsOneWidget,
      shouldExpect: runWithExpectations,
    );
    final menuChildren =
        controller.widget<MenuAnchor>(tabOverflowMenuFinder).menuChildren;
    numTabs += menuChildren.length;
  }

  _maybeExpect(
    numTabs,
    visibleScreenIds.length,
    shouldExpect: runWithExpectations,
  );

  final screens = (ScreenMetaData.values.toList()
    ..removeWhere((data) => !visibleScreenIds.contains(data.id)));
  for (final screen in screens) {
    await switchToScreen(
      controller,
      tabIcon: screen.icon!,
      screenId: screen.id,
      runWithExpectations: runWithExpectations,
    );
  }
}

List<String> generateVisibleScreenIds() {
  final availableScreenIds = <String>[];
  // ignore: invalid_use_of_visible_for_testing_member, valid use from package:devtools_test
  for (final screen in devtoolsScreens!) {
    if (shouldShowScreen(screen.screen).show) {
      availableScreenIds.add(screen.screen.screenId);
    }
  }
  return availableScreenIds;
}

/// Switches to the DevTools screen with icon [tabIcon] and pumps the tester
/// to settle the UI.
Future<void> switchToScreen(
  WidgetController controller, {
  required IconData tabIcon,
  required String screenId,
  bool warnIfTapMissed = true,
  bool runWithExpectations = true,
}) async {
  logStatus('switching to $screenId screen (icon $tabIcon)');
  final tabFinder = await findTab(controller, tabIcon);
  _maybeExpect(
    tabFinder,
    findsOneWidget,
    shouldExpect: runWithExpectations,
  );

  await controller.tap(tabFinder, warnIfMissed: warnIfTapMissed);
  // We use pump here instead of pumpAndSettle because pumpAndSettle will
  // never complete if there is an animation (e.g. a progress indicator).
  await controller.pump(safePumpDuration);
}

/// Finds the tab with [icon] either in the top-level DevTools tab bar or in the
/// tab overflow menu for tabs that don't fit on screen.
Future<Finder> findTab(WidgetController controller, IconData icon) async {
  // Open the tab overflow menu before looking for the tab.
  final tabOverflowButtonFinder = find.byType(TabOverflowButton);
  if (tabOverflowButtonFinder.evaluate().isNotEmpty) {
    await controller.tap(tabOverflowButtonFinder);
    await controller.pump(shortPumpDuration);
  }
  return find.widgetWithIcon(Tab, icon);
}

// ignore: avoid-dynamic, wrapper around `expect`, which uses dynamic types.
void _maybeExpect(dynamic actual, dynamic matcher, {bool shouldExpect = true}) {
  if (shouldExpect) {
    expect(actual, matcher);
  }
}

Future<void> loadSampleData(
  WidgetController controller,
  String fileName, {
  Duration waitTimeForLoad = longPumpDuration,
}) async {
  await controller.tap(find.byType(DropdownButton<DevToolsJsonFile>));
  await controller.pumpAndSettle();
  await controller.tap(find.text(fileName).last);
  await controller.pump(safePumpDuration);
  await controller.tap(find.text('Load sample data'));
  await controller.pump(waitTimeForLoad);
}

/// Scrolls to the end of the first [Scrollable] descendant of the [T] widget.
///
/// For example, if you have some widget in the tree 'Foo' that contains a
/// [Scrollbar] somewhere in its descendants, calling
/// `scrollToEnd<Foo>(controller)` would perform the following steps:
///
/// 1) find the [Scrollbar] widget descending from [Foo].
/// 2) access the [Scrollbar] widget's [ScrollController].
/// 3) scroll the scrollable attached to the [ScrollController] to the end of
///    the [ScrollController]'s scroll extent.
Future<void> scrollToEnd<T>(WidgetController controller) async {
  final scrollbarFinder = find.descendant(
    of: find.byType(T),
    matching: find.byType(Scrollbar),
  );
  final scrollbar = controller.firstWidget<Scrollbar>(scrollbarFinder);
  await scrollbar.controller!.animateTo(
    scrollbar.controller!.position.maxScrollExtent,
    duration: const Duration(milliseconds: 500),
    curve: Curves.easeInOutCubic,
  );
  await controller.pump(shortPumpDuration);
}
