// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/analytics_common.dart';
import '../../analytics/constants.dart' as analytics_constants;
import '../../config_specific/import_export/import_export.dart';
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/feature_flags.dart';
import '../../service/service_extension_widgets.dart';
import '../../service/service_extensions.dart' as extensions;
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/screen.dart';
import '../../shared/split.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../shared/version.dart';
import '../../ui/icons.dart';
import '../../ui/vm_flag_widgets.dart';
import 'event_details.dart';
import 'flutter_frames_chart.dart';
import 'panes/controls/enhance_tracing/enhance_tracing.dart';
import 'panes/controls/layer_debugging_options.dart';
import 'panes/controls/performance_settings.dart';
import 'performance_controller.dart';
import 'performance_model.dart';
import 'tabbed_performance_view.dart';

// TODO(kenz): handle small screen widths better by using Wrap instead of Row
// where applicable.

class PerformanceScreen extends Screen {
  const PerformanceScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          worksOffline: true,
          title: 'Performance',
          icon: Octicons.pulse,
        );

  static const id = 'performance';

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
        OfflineScreenMixin<PerformanceScreenBody, OfflinePerformanceData>,
        ProvidedControllerMixin<PerformanceController, PerformanceScreenBody> {
  bool processing = false;

  double processingProgress = 0.0;

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

    processing = controller.processing.value;
    addAutoDisposeListener(controller.processing, () {
      setState(() {
        processing = controller.processing.value;
      });
    });

    processingProgress = controller.processor.progressNotifier.value;
    addAutoDisposeListener(controller.processor.progressNotifier, () {
      setState(() {
        processingProgress = controller.processor.progressNotifier.value;
      });
    });

    addAutoDisposeListener(controller.selectedFrame);

    // Load offline timeline data if available.
    if (shouldLoadOfflineData()) {
      // This is a workaround to guarantee that DevTools exports are compatible
      // with other trace viewers (catapult, perfetto, chrome://tracing), which
      // require a top level field named "traceEvents". See how timeline data is
      // encoded in [ExportController.encode].
      final timelineJson = Map<String, dynamic>.from(
        offlineController.offlineDataJson[PerformanceScreen.id],
      )..addAll({
          PerformanceData.traceEventsKey:
              offlineController.offlineDataJson[PerformanceData.traceEventsKey]
        });
      final offlinePerformanceData = OfflinePerformanceData.parse(timelineJson);
      if (!offlinePerformanceData.isEmpty) {
        loadOfflineData(offlinePerformanceData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOfflineFlutterApp = offlineController.offlineMode.value &&
        controller.offlinePerformanceData != null &&
        controller.offlinePerformanceData!.frames.isNotEmpty;

    final tabbedPerformanceView = TabbedPerformanceView(
      controller: controller,
      processing: processing,
      processingProgress: processingProgress,
    );
    final performanceScreen = Column(
      children: [
        if (!offlineController.offlineMode.value) _buildPerformanceControls(),
        const SizedBox(height: denseRowSpacing),
        if (isOfflineFlutterApp ||
            (!offlineController.offlineMode.value &&
                serviceManager.connectedApp!.isFlutterAppNow!))
          DualValueListenableBuilder<List<FlutterFrame>, double>(
            firstListenable: controller.flutterFrames,
            secondListenable: controller.displayRefreshRate,
            builder: (context, frames, displayRefreshRate, child) {
              return FlutterFramesChart(
                frames,
                displayRefreshRate,
              );
            },
          ),
        Expanded(
          child: FeatureFlags.embeddedPerfetto && !controller.useLegacyTraceViewer.value
              ? tabbedPerformanceView
              : Split(
                  axis: Axis.vertical,
                  initialFractions: const [0.7, 0.3],
                  children: [
                    tabbedPerformanceView,
                    ValueListenableBuilder<TimelineEvent?>(
                      valueListenable: controller.selectedTimelineEvent,
                      builder: (context, selectedEvent, _) {
                        return EventDetails(selectedEvent);
                      },
                    ),
                  ],
                ),
        ),
      ],
    );

    // We put these two items in a stack because the screen's UI needs to be
    // built before offline data is processed in order to initialize listeners
    // that respond to data processing events. The spinner hides the screen's
    // empty UI while data is being processed.
    return Stack(
      children: [
        performanceScreen,
        if (loadingOfflineData)
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const CenteredCircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildPerformanceControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PrimaryControls(
          controller: controller,
          processing: processing,
          onClear: () => setState(() {}),
        ),
        const SizedBox(width: defaultSpacing),
        SecondaryPerformanceControls(controller: controller),
      ],
    );
  }

  @override
  FutureOr<void> processOfflineData(OfflinePerformanceData offlineData) async {
    await controller.processOfflineData(offlineData);
  }

  @override
  bool shouldLoadOfflineData() {
    return offlineController.shouldLoadOfflineData(PerformanceScreen.id) &&
        offlineController.offlineDataJson[PerformanceData.traceEventsKey] !=
            null;
  }
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({
    Key? key,
    required this.controller,
    required this.processing,
    this.onClear,
  }) : super(key: key);

  final PerformanceController controller;

  final bool processing;

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.recordingFrames,
      builder: (context, recording, child) {
        return Row(
          children: [
            OutlinedIconButton(
              icon: Icons.pause,
              tooltip: 'Pause frame recording',
              onPressed: recording ? _pauseFrameRecording : null,
            ),
            const SizedBox(width: denseSpacing),
            OutlinedIconButton(
              icon: Icons.play_arrow,
              tooltip: 'Resume frame recording',
              onPressed: recording ? null : _resumeFrameRecording,
            ),
            const SizedBox(width: denseSpacing),
            child!,
          ],
        );
      },
      child: OutlinedIconButton(
        icon: Icons.block,
        tooltip: 'Clear',
        onPressed: processing ? null : _clearPerformanceData,
      ),
    );
  }

  void _pauseFrameRecording() {
    ga.select(analytics_constants.performance, analytics_constants.pause);
    controller.toggleRecordingFrames(false);
  }

  void _resumeFrameRecording() {
    ga.select(analytics_constants.performance, analytics_constants.resume);
    controller.toggleRecordingFrames(true);
  }

  Future<void> _clearPerformanceData() async {
    ga.select(analytics_constants.performance, analytics_constants.clear);
    await controller.clearData();
    if (onClear != null) {
      onClear!();
    }
  }
}

class SecondaryPerformanceControls extends StatelessWidget {
  const SecondaryPerformanceControls({
    Key? key,
    required this.controller,
  }) : super(key: key);

  static const minScreenWidthForTextBeforeScaling = 1075.0;

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (serviceManager.connectedApp!.isFlutterAppNow!) ...[
          ServiceExtensionButtonGroup(
            minScreenWidthForTextBeforeScaling:
                minScreenWidthForTextBeforeScaling,
            extensions: [
              extensions.performanceOverlay,
              // TODO(devoncarew): Enable this once we have a UI displaying the
              // values.
              //trackRebuildWidgets,
            ],
          ),
          const SizedBox(width: denseSpacing),
          EnhanceTracingButton(controller.enhanceTracingController),
          const SizedBox(width: denseSpacing),
          const MoreDebuggingOptionsButton(),
        ],
        const SizedBox(width: denseSpacing),
        ProfileGranularityDropdown(
          screenId: PerformanceScreen.id,
          profileGranularityFlagNotifier:
              controller.cpuProfilerController.profileGranularityFlagNotifier!,
        ),
        const SizedBox(width: defaultSpacing),
        OutlinedIconButton(
          icon: Icons.file_download,
          tooltip: 'Export data',
          onPressed: () => _exportPerformanceData(context),
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          onPressed: () => _openSettingsDialog(context),
        ),
      ],
    );
  }

  void _exportPerformanceData(BuildContext context) {
    ga.select(analytics_constants.performance, analytics_constants.export);
    final exportedFile = controller.exportData();
    // TODO(kenz): investigate if we need to do any error handling here. Is the
    // download always successful?
    // TODO(peterdjlee): find a way to push the notification logic into the
    // export controller.
    notificationService.push(successfulExportMessage(exportedFile));
  }

  void _openSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PerformanceSettingsDialog(controller),
    );
  }
}

class PerformanceScreenMetrics extends ScreenAnalyticsMetrics {
  PerformanceScreenMetrics({
    this.uiDuration,
    this.rasterDuration,
    this.shaderCompilationDuration,
    this.traceEventCount,
  });

  final Duration? uiDuration;
  final Duration? rasterDuration;
  final Duration? shaderCompilationDuration;
  final int? traceEventCount;
}
