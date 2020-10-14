// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screen.dart';
import '../theme.dart';
import 'isolate_statistics_view.dart';
import 'vm_developer_tools_screen_controller.dart';
import 'vm_statistics_view.dart';

abstract class VMDeveloperView {
  const VMDeveloperView(
    this.screenId, {
    this.title,
    this.icon,
  });

  final String screenId;

  /// The user-facing name of the page.
  final String title;

  final IconData icon;

  /// Whether this view should display the isolate selector in the status
  /// line.
  ///
  /// Some views act on all isolates; for these views, displaying a
  /// selector doesn't make sense.
  bool get showIsolateSelector => false;

  Widget build(BuildContext context);
}

class VMDeveloperToolsScreen extends Screen {
  const VMDeveloperToolsScreen()
      : super.conditional(
          id: id,
          title: 'VM Tools',
          icon: Icons.settings_applications,
          requiresVmDeveloperMode: true,
        );

  static const id = 'vm-tools';

  @override
  ValueListenable<bool> get showIsolateSelector =>
      VMDeveloperToolsScreenBody.controller.showIsolateSelector;

  @override
  Widget build(BuildContext context) => const VMDeveloperToolsScreenBody();
}

class VMDeveloperToolsScreenBody extends StatelessWidget {
  const VMDeveloperToolsScreenBody();

  static const List<VMDeveloperView> views = [
    VMStatisticsView(),
    IsolateStatisticsView(),
  ];

  // TODO(bkonyi): do we want this to be static? Currently necessary to provide
  // access to the `showIsolateSelector` via `VMDeveloperToolsScreen`
  static final VMDeveloperToolsScreenController controller =
      VMDeveloperToolsScreenController();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.selectedIndex,
      builder: (context, selectedIndex, _) {
        return Row(
          children: [
            if (VMDeveloperToolsScreenBody.views.length > 1)
              NavigationRail(
                selectedIndex: selectedIndex,
                elevation: 10.0,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: controller.setSelectedIndex,
                destinations: [
                  for (final view in VMDeveloperToolsScreenBody.views)
                    NavigationRailDestination(
                      label: Text(view.title),
                      icon: Icon(view.icon),
                    )
                ],
              ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: defaultSpacing,
                ),
                child: VMDeveloperToolsScreenBody.views[selectedIndex]
                    .build(context),
              ),
            )
          ],
        );
      },
    );
  }
}
