// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/screen.dart';
import '../../shared/theme.dart';
import '../../shared/ui/icons.dart';
import '../../shared/utils.dart';
import 'panes/controls/performance_controls.dart';
import 'panes/flutter_frames/flutter_frames_chart.dart';
import 'performance_controller.dart';
import 'tabbed_performance_view.dart';

// TODO(kenz): handle small screen widths better by using Wrap instead of Row
// where applicable.

class PerformanceScreen extends Screen {
  PerformanceScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          worksOffline: true,
          title: ScreenMetaData.performance.title,
          icon: Octicons.pulse,
        );

  static final id = ScreenMetaData.performance.id;

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) => const PerformanceScreenBody();
}

class PerformanceScreenBody extends StatefulWidget {
  const PerformanceScreenBody();

  @override
  PerformanceScreenBodyState createState() => PerformanceScreenBodyState();
}

class PerformanceScreenBodyState extends State<PerformanceScreenBody>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<PerformanceController, PerformanceScreenBody> {
  @override
  void initState() {
    super.initState();
    ga.screen(PerformanceScreen.id);
    addAutoDisposeListener(offlineController.offlineMode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushUnsupportedFlutterVersionWarning(
      context,
      PerformanceScreen.id,
      supportedFlutterVersion: SemanticVersion(
        major: 2,
        minor: 3,
        // Specifying patch makes the version number more readable.
        // ignore: avoid_redundant_argument_values
        patch: 0,
        preReleaseMajor: 16,
        preReleaseMinor: 0,
      ),
    );
    maybePushDebugModePerformanceMessage(context, PerformanceScreen.id);

    if (!initController()) return;

    cancelListeners();
    addAutoDisposeListener(controller.loadingOfflineData);
    addAutoDisposeListener(controller.flutterFramesController.selectedFrame);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: controller.initialized,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            controller.loadingOfflineData.value) {
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const CenteredCircularProgressIndicator(),
          );
        }

        final offlineMode = offlineController.offlineMode.value;
        final isOfflineFlutterApp = offlineMode &&
            controller.offlinePerformanceData != null &&
            controller.offlinePerformanceData!.frames.isNotEmpty;
        return Column(
          children: [
            PerformanceControls(
              controller: controller,
              onClear: () => setState(() {}),
            ),
            const SizedBox(height: intermediateSpacing),
            if (isOfflineFlutterApp ||
                (!offlineMode && serviceManager.connectedApp!.isFlutterAppNow!))
              FlutterFramesChart(
                controller.flutterFramesController,
                offlineMode: offlineMode,
              ),
            const Expanded(child: TabbedPerformanceView()),
          ],
        );
      },
    );
  }
}
