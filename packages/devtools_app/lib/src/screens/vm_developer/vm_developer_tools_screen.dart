// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../service/vm_flags.dart' as vm_flags;
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import 'isolate_statistics/isolate_statistics_view.dart';
import 'object_inspector/object_inspector_view.dart';
import 'process_memory/process_memory_view.dart';
import 'queued_microtasks/queued_microtasks_view.dart';
import 'vm_developer_tools_controller.dart';
import 'vm_statistics/vm_statistics_view.dart';

abstract class VMDeveloperView {
  const VMDeveloperView({
    required this.title,
    required this.icon,
    required this.gaEvent,
  });

  /// The user-facing name of the page.
  final String title;

  final IconData icon;

  /// The analytics id sent when this page is selected.
  final gac.VmToolsEvents gaEvent;

  /// Whether this view should display the isolate selector in the status
  /// line.
  ///
  /// Some views act on all isolates; for these views, displaying a
  /// selector doesn't make sense.
  bool get showIsolateSelector => false;

  Widget build(BuildContext context);
}

class VMDeveloperToolsScreen extends Screen {
  VMDeveloperToolsScreen() : super.fromMetaData(ScreenMetaData.vmTools);

  @override
  ValueListenable<bool> get showIsolateSelector =>
      VMDeveloperToolsController.showIsolateSelector;

  @override
  Widget buildScreenBody(BuildContext context) =>
      const VMDeveloperToolsScreenBody();
}

class VMDeveloperToolsScreenBody extends StatefulWidget {
  const VMDeveloperToolsScreenBody({super.key});

  // The value of the `--profile-microtasks` VM flag cannot be modified once
  // the VM has started running.
  static final showQueuedMicrotasks =
      serviceConnection.vmFlagManager
          .flag(vm_flags.profileMicrotasks)
          ?.value
          .valueAsString ==
      'true';

  static final views = <VMDeveloperView>[
    const VMStatisticsView(),
    const IsolateStatisticsView(),
    ObjectInspectorView(),
    const VMProcessMemoryView(),
    if (showQueuedMicrotasks) const QueuedMicrotasksView(),
  ];

  @override
  State<VMDeveloperToolsScreenBody> createState() =>
      _VMDeveloperToolsScreenBodyState();
}

class _VMDeveloperToolsScreenBodyState
    extends State<VMDeveloperToolsScreenBody> {
  late final VMDeveloperToolsController controller;

  List<VMDeveloperView> get views => VMDeveloperToolsScreenBody.views;

  @override
  void initState() {
    super.initState();
    ga.screen(gac.vmTools);
    controller = screenControllers.lookup<VMDeveloperToolsController>();
    // Record the view that is visible when the screen opens, as tabbed views
    // do (see `AnalyticsTabbedView`).
    ga.select(
      gac.vmTools,
      views[controller.selectedIndex.value].gaEvent.name,
      nonInteraction: true,
    );
  }

  void _selectView(int index) {
    if (index != controller.selectedIndex.value) {
      ga.select(gac.vmTools, views[index].gaEvent.name);
    }
    controller.selectIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.selectedIndex,
      builder: (context, selectedIndex, _) {
        return Row(
          children: [
            if (views.length > 1)
              NavigationRail(
                selectedIndex: selectedIndex,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: _selectView,
                destinations: [
                  for (final view in views)
                    NavigationRailDestination(
                      label: Text(view.title),
                      icon: Icon(view.icon),
                    ),
                ],
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: defaultSpacing),
                child: IndexedStack(
                  index: selectedIndex,
                  children: [for (final view in views) view.build(context)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
