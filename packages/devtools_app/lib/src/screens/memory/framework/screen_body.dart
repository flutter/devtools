// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../shared/banner_messages.dart';
import '../../../shared/common_widgets.dart';
import '../../../shared/http/http_service.dart' as http_service;
import '../../../shared/primitives/simple_items.dart';
import '../../../shared/screen.dart';
import '../../../shared/utils.dart';
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
    with
        AutoDisposeMixin,
        SingleTickerProviderStateMixin,
        ProvidedControllerMixin<MemoryController, ConnectedMemoryBody> {
  final _focusNode = FocusNode(debugLabel: 'memory');

  @override
  void initState() {
    super.initState();
    autoDisposeFocusNode(_focusNode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!initController()) return;

    if (controller.mode == ControllerCreationMode.connected) {
      maybePushDebugModeMemoryMessage(context, ScreenMetaData.memory.id);
      maybePushHttpLoggingMessage(context, ScreenMetaData.memory.id);

      addAutoDisposeListener(http_service.httpLoggingState, () {
        maybePushHttpLoggingMessage(context, ScreenMetaData.memory.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: controller.initialized,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Column(
            key: MemoryChartPane.hoverKey,
            children: [
              MemoryControlPane(
                controller: controller.control,
              ),
              const SizedBox(height: intermediateSpacing),
              if (controller.mode != ControllerCreationMode.disconnected)
                MemoryChartPane(
                  chart: controller.chart!,
                  keyFocusNode: _focusNode,
                ),
              Expanded(
                child: MemoryTabView(controller),
              ),
            ],
          );
        } else {
          return const CenteredCircularProgressIndicator();
        }
      },
    );
  }
}
