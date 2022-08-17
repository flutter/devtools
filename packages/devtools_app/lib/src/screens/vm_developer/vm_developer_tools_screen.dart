// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../primitives/auto_dispose_mixin.dart';
import '../../shared/common_widgets.dart';
import '../../shared/screen.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import 'isolate_statistics_view.dart';
import 'object_inspector_view.dart';
import 'vm_developer_tools_controller.dart';
import 'vm_statistics_view.dart';

const displayObjectInspector = false;

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
  const VMDeveloperToolsScreen({
    required this.controller,
  }) : super.conditional(
          id: id,
          title: 'VM Tools',
          icon: Icons.settings_applications,
          requiresVmDeveloperMode: true,
        );

  static const id = 'vm-tools';

  final VMDeveloperToolsController controller;

  @override
  ValueListenable<bool> get showIsolateSelector =>
      controller.showIsolateSelector;

  @override
  Widget build(BuildContext context) => const VMDeveloperToolsScreenBody();
}

class VMDeveloperToolsScreenBody extends StatefulWidget {
  const VMDeveloperToolsScreenBody();

  static List<VMDeveloperView> views = [
    const VMStatisticsView(),
    const IsolateStatisticsView(),
    if (displayObjectInspector) ObjectInspectorView(),
  ];

  @override
  _VMDeveloperToolsScreenState createState() => _VMDeveloperToolsScreenState();
}

class _VMDeveloperToolsScreenState extends State<VMDeveloperToolsScreenBody>
    with
        AutoDisposeMixin,
        AutomaticKeepAliveClientMixin<VMDeveloperToolsScreenBody>,
        ProvidedControllerMixin<VMDeveloperToolsController,
            VMDeveloperToolsScreenBody> {
  int _selectedIndex = 0;
  late List<Widget> _views;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

  void onDestinationSelected(int i) {
    setState(() => _selectedIndex = i);
    controller.onSelectedIndex(i);
  }

  @override
  void initState() {
    super.initState();
    _views = [
      for (final view in VMDeveloperToolsScreenBody.views) view.build(context)
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return KeepAliveWrapper(
      child: Row(
        children: [
          if (VMDeveloperToolsScreenBody.views.length > 1)
            NavigationRail(
              selectedIndex: _selectedIndex,
              elevation: 10.0,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (final view in VMDeveloperToolsScreenBody.views)
                  NavigationRailDestination(
                    label: Text(view.title),
                    icon: Icon(view.icon),
                  ),
              ],
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: defaultSpacing,
              ),
              child: IndexedStack(
                index: _selectedIndex,
                children: _views,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
