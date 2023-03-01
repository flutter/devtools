// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../../service/service_extension_widgets.dart';
import '../../service/service_extensions.dart' as extensions;
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/screen.dart';
import '../../shared/theme.dart';
import '../../shared/ui/icons.dart';
import '../../shared/utils.dart';
import 'panes/controls/enhance_tracing/enhance_tracing.dart';
import 'panes/controls/more_debugging_options.dart';
import 'panes/controls/performance_settings.dart';
import 'panes/flutter_frames/flutter_frames_chart.dart';
import 'panes/timeline_events/timeline_events_controller.dart';
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
            const SizedBox(height: denseRowSpacing),
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

class PerformanceControls extends StatelessWidget {
  const PerformanceControls({
    required this.controller,
    required this.onClear,
  });

  static const minScreenWidthForTextBeforeScaling = 920.0;

  final PerformanceController controller;

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return OfflineAwareControls(
      controlsBuilder: (offline) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder<EventsControllerStatus>(
              valueListenable: controller.timelineEventsController.status,
              builder: (context, status, _) {
                return _PrimaryControls(
                  controller: controller,
                  processing: status == EventsControllerStatus.processing,
                  offline: offline,
                  onClear: onClear,
                );
              },
            ),
            if (!offline)
              Padding(
                padding: const EdgeInsets.only(left: defaultSpacing),
                child: _SecondaryPerformanceControls(controller: controller),
              ),
          ],
        );
      },
    );
  }
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({
    Key? key,
    required this.controller,
    required this.processing,
    required this.offline,
    required this.onClear,
  }) : super(key: key);

  final PerformanceController controller;

  final bool processing;

  final bool offline;

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (serviceManager.connectedApp!.isFlutterAppNow!) ...[
          VisibilityButton(
            show: preferences.performance.showFlutterFramesChart,
            onPressed:
                controller.flutterFramesController.toggleShowFlutterFrames,
            label: 'Flutter frames',
            tooltip: 'Toggle visibility of the Flutter frames chart',
          ),
          const SizedBox(width: denseSpacing),
        ],
        if (!offline)
          OutlinedIconButton(
            icon: Icons.block,
            tooltip: 'Clear all data on the Performance screen',
            onPressed: processing ? null : _clearPerformanceData,
          ),
      ],
    );
  }

  Future<void> _clearPerformanceData() async {
    ga.select(gac.performance, gac.clear);
    await controller.clearData();
    onClear();
  }
}

class _SecondaryPerformanceControls extends StatelessWidget {
  const _SecondaryPerformanceControls({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (serviceManager.connectedApp!.isFlutterAppNow!) ...[
          ServiceExtensionButtonGroup(
            minScreenWidthForTextBeforeScaling:
                PerformanceControls.minScreenWidthForTextBeforeScaling,
            extensions: [
              extensions.performanceOverlay,
            ],
          ),
          const SizedBox(width: denseSpacing),
          EnhanceTracingButton(controller.enhanceTracingController),
          const SizedBox(width: denseSpacing),
          const MoreDebuggingOptionsButton(),
        ],
        const SizedBox(width: defaultSpacing),
        OutlinedIconButton(
          icon: Icons.file_download,
          tooltip: 'Export data',
          onPressed: _exportPerformanceData,
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          onPressed: () => _openSettingsDialog(context),
        ),
      ],
    );
  }

  void _exportPerformanceData() {
    ga.select(gac.performance, gac.export);
    controller.exportData();
    // TODO(kenz): investigate if we need to do any error handling here. Is the
    // download always successful?
  }

  void _openSettingsDialog(BuildContext context) {
    unawaited(
      showDialog(
        context: context,
        builder: (context) => PerformanceSettingsDialog(controller),
      ),
    );
  }
}
