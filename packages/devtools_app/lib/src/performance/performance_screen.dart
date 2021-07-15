// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics_stub.dart'
    if (dart.library.html) '../analytics/analytics.dart' as ga;
import '../auto_dispose_mixin.dart';
import '../banner_messages.dart';
import '../common_widgets.dart';
import '../config_specific/import_export/import_export.dart';
import '../dialogs.dart';
import '../globals.dart';
import '../notifications.dart';
import '../screen.dart';
import '../service_extensions.dart';
import '../split.dart';
import '../theme.dart';
import '../ui/icons.dart';
import '../ui/service_extension_widgets.dart';
import '../ui/utils.dart';
import '../ui/vm_flag_widgets.dart';
import '../version.dart';
import 'event_details.dart';
import 'flutter_frames_chart.dart';
import 'performance_controller.dart';
import 'performance_model.dart';
import 'timeline_flame_chart.dart';

// TODO(kenz): handle small screen widths better by using Wrap instead of Row
// where applicable.

class PerformanceScreen extends Screen {
  const PerformanceScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          worksOffline: true,
          shouldShowForFlutterVersion: _shouldShowForFlutterVersion,
          title: 'Performance',
          icon: Octicons.pulse,
        );

  static const id = 'performance';

  static bool _shouldShowForFlutterVersion(FlutterVersion currentVersion) {
    return currentVersion != null &&
        currentVersion >=
            SemanticVersion(
              major: 2,
              minor: 3,
              // Specifying patch makes the version number more readable.
              // ignore: avoid_redundant_argument_values
              patch: 0,
              preReleaseMajor: 16,
              preReleaseMinor: 0,
            );
  }

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
        OfflineScreenMixin<PerformanceScreenBody, OfflinePerformanceData> {
  static const _primaryControlsMinIncludeTextWidth = 725.0;
  static const _secondaryControlsMinIncludeTextWidth = 1100.0;

  PerformanceController controller;

  bool processing = false;

  double processingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    ga.screen(PerformanceScreen.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModePerformanceMessage(context, PerformanceScreen.id);

    final newController = Provider.of<PerformanceController>(context);
    if (newController == controller) return;
    controller = newController;

    cancel();

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
      final timelineJson =
          Map<String, dynamic>.from(offlineDataJson[PerformanceScreen.id])
            ..addAll({
              PerformanceData.traceEventsKey:
                  offlineDataJson[PerformanceData.traceEventsKey]
            });
      final offlinePerformanceData = OfflinePerformanceData.parse(timelineJson);
      if (!offlinePerformanceData.isEmpty) {
        loadOfflineData(offlinePerformanceData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOfflineFlutterApp = offlineMode &&
        controller.offlinePerformanceData != null &&
        controller.offlinePerformanceData.frames.isNotEmpty;

    final performanceScreen = Column(
      children: [
        if (!offlineMode) _buildPerformanceControls(),
        const SizedBox(height: denseRowSpacing),
        if (isOfflineFlutterApp ||
            (!offlineMode && serviceManager.connectedApp.isFlutterAppNow))
          ValueListenableBuilder(
            valueListenable: controller.flutterFrames,
            builder: (context, frames, _) => ValueListenableBuilder(
              valueListenable: controller.displayRefreshRate,
              builder: (context, displayRefreshRate, _) {
                return FlutterFramesChart(
                  frames,
                  displayRefreshRate,
                );
              },
            ),
          ),
        Expanded(
          child: Split(
            axis: Axis.vertical,
            initialFractions: const [0.7, 0.3],
            children: [
              TimelineFlameChartContainer(
                processing: processing,
                processingProgress: processingProgress,
              ),
              ValueListenableBuilder(
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
        _buildPrimaryStateControls(),
        _buildSecondaryControls(),
      ],
    );
  }

  Widget _buildPrimaryStateControls() {
    return ValueListenableBuilder(
      valueListenable: controller.recordingFrames,
      builder: (context, recording, _) {
        return Row(
          children: [
            PauseButton(
              includeTextWidth: _primaryControlsMinIncludeTextWidth,
              onPressed: recording ? _pauseFrameRecording : null,
            ),
            const SizedBox(width: denseSpacing),
            ResumeButton(
              includeTextWidth: _primaryControlsMinIncludeTextWidth,
              onPressed: recording ? null : _resumeFrameRecording,
            ),
            const SizedBox(width: defaultSpacing),
            ClearButton(
              includeTextWidth: _primaryControlsMinIncludeTextWidth,
              onPressed: processing ? null : _clearPerformanceData,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecondaryControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ProfileGranularityDropdown(
          screenId: PerformanceScreen.id,
          profileGranularityFlagNotifier:
              controller.cpuProfilerController.profileGranularityFlagNotifier,
        ),
        const SizedBox(width: defaultSpacing),
        if (!serviceManager.connectedApp.isDartCliAppNow)
          ServiceExtensionButtonGroup(
            minIncludeTextWidth: _secondaryControlsMinIncludeTextWidth,
            extensions: [performanceOverlay, profileWidgetBuilds],
          ),
        // TODO(kenz): hide or disable button if http timeline logging is not
        // available.
        const SizedBox(width: defaultSpacing),
        ExportButton(
          onPressed: _exportPerformanceData,
          includeTextWidth: _secondaryControlsMinIncludeTextWidth,
        ),
        const SizedBox(width: defaultSpacing),
        SettingsOutlinedButton(
          onPressed: _openSettingsDialog,
          label: 'Performance Settings',
        ),
      ],
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => PerformanceSettingsDialog(controller),
    );
  }

  void _pauseFrameRecording() {
    controller.toggleRecordingFrames(false);
  }

  void _resumeFrameRecording() {
    controller.toggleRecordingFrames(true);
  }

  Future<void> _clearPerformanceData() async {
    await controller.clearData();
    setState(() {});
  }

  void _exportPerformanceData() {
    final exportedFile = controller.exportData();
    // TODO(kenz): investigate if we need to do any error handling here. Is the
    // download always successful?
    // TODO(peterdjlee): find a way to push the notification logic into the
    // export controller.
    Notifications.of(context).push(successfulExportMessage(exportedFile));
  }

  @override
  FutureOr<void> processOfflineData(OfflinePerformanceData offlineData) async {
    await controller.processOfflineData(offlineData);
  }

  @override
  bool shouldLoadOfflineData() {
    return offlineMode &&
        offlineDataJson.isNotEmpty &&
        offlineDataJson[PerformanceScreen.id] != null &&
        offlineDataJson[PerformanceData.traceEventsKey] != null;
  }
}

class PerformanceSettingsDialog extends StatelessWidget {
  const PerformanceSettingsDialog(this.controller);

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: dialogTitleText(theme, 'Performance Settings'),
      includeDivider: false,
      content: Container(
        width: defaultDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...dialogSubHeader(theme, 'Recorded Timeline Streams'),
            ..._defaultRecordedStreams(theme),
            ..._advancedStreams(theme),
            if (serviceManager.connectedApp.isFlutterAppNow) ...[
              const SizedBox(height: denseSpacing),
              ..._additionalFlutterSettings(theme),
            ],
          ],
        ),
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }

  List<Widget> _defaultRecordedStreams(ThemeData theme) {
    return [
      RichText(
        text: TextSpan(
          text: 'Default',
          style: theme.subtleTextStyle,
        ),
      ),
      ..._timelineStreams(theme, advanced: false),
      // Special case "Network Traffic" because it is not implemented as a
      // Timeline recorded stream in the VM. The user does not need to be aware of
      // the distinction, however.
      _buildStream(
        name: 'Network',
        description: ' • Http traffic',
        listenable: controller.httpTimelineLoggingEnabled,
        onChanged: controller.toggleHttpRequestLogging,
        theme: theme,
      ),
    ];
  }

  List<Widget> _advancedStreams(ThemeData theme) {
    return [
      RichText(
        text: TextSpan(
          text: 'Advanced',
          style: theme.subtleTextStyle,
        ),
      ),
      ..._timelineStreams(theme, advanced: true),
    ];
  }

  List<Widget> _timelineStreams(
    ThemeData theme, {
    @required bool advanced,
  }) {
    final settings = <Widget>[];
    final streams = controller.recordedStreams
        .where((s) => s.advanced == advanced)
        .toList();
    for (final stream in streams) {
      settings.add(_buildStream(
        name: stream.name,
        description: ' • ${stream.description}',
        listenable: stream.enabled,
        onChanged: (_) => controller.toggleTimelineStream(stream),
        theme: theme,
      ));
    }
    return settings;
  }

  Widget _buildStream({
    @required String name,
    @required String description,
    @required ValueListenable listenable,
    @required void Function(bool) onChanged,
    @required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // TODO(kenz): refactor so that we can use NotifierCheckbox here.
        ValueListenableBuilder(
          valueListenable: listenable,
          builder: (context, value, _) {
            return Checkbox(
              value: value,
              onChanged: onChanged,
            );
          },
        ),
        Flexible(
          child: RichText(
            overflow: TextOverflow.visible,
            text: TextSpan(
              text: name,
              style: theme.regularTextStyle,
              children: [
                TextSpan(
                  text: description,
                  style: theme.subtleTextStyle,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _additionalFlutterSettings(ThemeData theme) {
    return [
      ...dialogSubHeader(theme, 'Additional Settings'),
      _BadgeJankyFramesSetting(controller),
    ];
  }
}

class _BadgeJankyFramesSetting extends StatelessWidget {
  const _BadgeJankyFramesSetting(this.controller);

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NotifierCheckbox(notifier: controller.badgeTabForJankyFrames),
        RichText(
          overflow: TextOverflow.visible,
          text: TextSpan(
            text: 'Badge Performance tab when Flutter UI jank is detected',
            style: Theme.of(context).regularTextStyle,
          ),
        ),
      ],
    );
  }
}
