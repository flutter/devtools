// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../primitives/auto_dispose_mixin.dart';
import '../../shared/screen.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import 'isolate_statistics_view.dart';
import 'object_inspector_view.dart';
import 'vm_developer_tools_controller.dart';
import 'vm_statistics_view.dart';

abstract class VMDeveloperView {
  const VMDeveloperView(
    this.screenId, {
    required this.title,
    required this.icon,
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
      VMDeveloperToolsController.showIsolateSelector;

  @override
  Widget build(BuildContext context) => const VMDeveloperToolsScreenBody();
}

class VMDeveloperToolsScreenBody extends StatefulWidget {
  const VMDeveloperToolsScreenBody();

  static List<VMDeveloperView> views = [
    const VMStatisticsView(),
    const IsolateStatisticsView(),
    ObjectInspectorView(),
  ];

  @override
  _VMDeveloperToolsScreenState createState() => _VMDeveloperToolsScreenState();
}

class _VMDeveloperToolsScreenState extends State<VMDeveloperToolsScreenBody>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<VMDeveloperToolsController,
            VMDeveloperToolsScreenBody> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

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
                onDestinationSelected: controller.selectIndex,
                destinations: [
                  for (final view in VMDeveloperToolsScreenBody.views)
                    NavigationRailDestination(
                      label: Text(view.title),
                      icon: Icon(view.icon),
                    )
                ],
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: defaultSpacing,
                ),
                child: IndexedStack(
                  index: selectedIndex,
                  children: [
                    for (final view in VMDeveloperToolsScreenBody.views)
                      view.build(context)
                  ],
                ),
              ),
            )
          ],
        );
      },
    );
  }
}
