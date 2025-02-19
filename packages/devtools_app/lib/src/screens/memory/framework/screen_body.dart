// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../shared/framework/screen.dart';
import '../../../shared/globals.dart';
import '../../../shared/http/http_service.dart' as http_service;
import '../../../shared/managers/banner_messages.dart';
import '../../../shared/ui/common_widgets.dart';
import '../panes/chart/widgets/chart_pane.dart';
import '../panes/control/widgets/control_pane.dart';
import 'memory_controller.dart';
import 'memory_tabs.dart';

class ConnectedMemoryBody extends StatefulWidget {
  const ConnectedMemoryBody({super.key});

  @override
  State<ConnectedMemoryBody> createState() => _ConnectedMemoryBodyState();
}

class _ConnectedMemoryBodyState extends State<ConnectedMemoryBody>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  final _focusNode = FocusNode(debugLabel: 'memory');

  @override
  void initState() {
    super.initState();
    autoDisposeFocusNode(_focusNode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!offlineDataController.showingOfflineData.value) {
      maybePushDebugModeMemoryMessage(context, ScreenMetaData.memory.id);
      maybePushHttpLoggingMessage(context, ScreenMetaData.memory.id);

      addAutoDisposeListener(http_service.httpLoggingState, () {
        maybePushHttpLoggingMessage(context, ScreenMetaData.memory.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = screenControllers.lookup<MemoryController>();
    return FutureBuilder<void>(
      future: controller.initialized,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            controller.loadingOfflineData.value) {
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const CenteredCircularProgressIndicator(),
          );
        }
        return Column(
          key: MemoryChartPane.hoverKey,
          children: [
            MemoryControlPane(
              isGcing: controller.isGcing,
              onGc: controller.gc,
              onSave: controller.exportData,
            ),
            const SizedBox(height: intermediateSpacing),
            MemoryChartPane(chart: controller.chart, keyFocusNode: _focusNode),
            Expanded(child: MemoryTabView(controller)),
          ],
        );
      },
    );
  }
}
