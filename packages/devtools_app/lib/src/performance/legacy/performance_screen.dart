// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(kenz): delete this legacy implementation after
// https://github.com/flutter/flutter/commit/78a96b09d64dc2a520e5b269d5cea1b9dde27d3f
// hits flutter stable.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../analytics/analytics_stub.dart'
    if (dart.library.html) '../../analytics/analytics.dart' as ga;
import '../../auto_dispose_mixin.dart';
import '../../banner_messages.dart';
import '../../common_widgets.dart';
import '../../config_specific/import_export/import_export.dart';
import '../../connected_app.dart';
import '../../dialogs.dart';
import '../../globals.dart';
import '../../notifications.dart';
import '../../screen.dart';
import '../../service_extensions.dart';
import '../../split.dart';
import '../../theme.dart';
import '../../ui/icons.dart';
import '../../ui/service_extension_widgets.dart';
import '../../ui/utils.dart';
import '../../ui/vm_flag_widgets.dart';
import '../../version.dart';
import 'event_details.dart';
import 'flutter_frames_chart.dart';
import 'performance_controller.dart';
import 'performance_model.dart';
import 'timeline_flame_chart.dart';

// TODO(kenz): handle small screen widths better by using Wrap instead of Row
// where applicable.

class LegacyPerformanceScreen extends Screen {
  const LegacyPerformanceScreen()
      : super.conditional(
          id: id,
          // Only show this screen for flutter apps, where we can conditionally
          // show this screen or [PerformanceScreen] based on the current
          // flutter version.
          requiresLibrary: flutterLibraryUri,
          requiresDartVm: true,
          worksOffline: true,
          shouldShowForFlutterVersion: _shouldShowForFlutterVersion,
          title: 'Performance',
          icon: Octicons.pulse,
        );

  static const id = 'legacy-performance';

  static bool _shouldShowForFlutterVersion(FlutterVersion currentVersion) {
    return currentVersion != null &&
        currentVersion <
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
  String get docPageId => 'performance';

  @override
  Widget build(BuildContext context) => const LegacyPerformanceScreenBody();
}

class LegacyPerformanceScreenBody extends StatefulWidget {
  const LegacyPerformanceScreenBody();

  @override
  LegacyPerformanceScreenBodyState createState() =>
      LegacyPerformanceScreenBodyState();
}

class LegacyPerformanceScreenBodyState
    extends State<LegacyPerformanceScreenBody>
    with
        AutoDisposeMixin,
        OfflineScreenMixin<LegacyPerformanceScreenBody,
            LegacyOfflinePerformanceData> {
  static const _primaryControlsMinIncludeTextWidth = 725.0;
  static const _secondaryControlsMinIncludeTextWidth = 1100.0;

  LegacyPerformanceController controller;

  bool processing = false;

  double processingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    ga.screen(LegacyPerformanceScreen.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushDebugModePerformanceMessage(context, LegacyPerformanceScreen.id);

    final newController = Provider.of<LegacyPerformanceController>(context);
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

    // Refresh data on page load if data is null. On subsequent tab changes,
    // this should not be called.
    if (controller.data == null && !offlineMode) {
      controller.refreshData();
    }

    // Load offline timeline data if available.
    if (shouldLoadOfflineData()) {
      // This is a workaround to guarantee that DevTools exports are compatible
      // with other trace viewers (catapult, perfetto, chrome://tracing), which
      // require a top level field named "traceEvents". See how timeline data is
      // encoded in [ExportController.encode].
      final timelineJson =
          Map<String, dynamic>.from(offlineDataJson[LegacyPerformanceScreen.id])
            ..addAll({
              LegacyPerformanceData.traceEventsKey:
                  offlineDataJson[LegacyPerformanceData.traceEventsKey]
            });
      final offlinePerformanceData =
          LegacyOfflinePerformanceData.parse(timelineJson);
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
                return LegacyFlutterFramesChart(
                  frames,
                  displayRefreshRate,
                );
              },
            ),
          ),
        Expanded(
          child: Split(
            axis: Axis.vertical,
            initialFractions: const [0.6, 0.4],
            children: [
              LegacyTimelineFlameChartContainer(
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
      valueListenable: controller.refreshing,
      builder: (context, refreshing, _) {
        return Row(
          children: [
            RefreshButton(
              minScreenWidthForTextBeforeScaling:
                  _primaryControlsMinIncludeTextWidth,
              onPressed:
                  (refreshing || processing) ? null : _refreshPerformanceData,
            ),
            const SizedBox(width: defaultSpacing),
            ClearButton(
              minScreenWidthForTextBeforeScaling:
                  _primaryControlsMinIncludeTextWidth,
              onPressed:
                  (refreshing || processing) ? null : _clearPerformanceData,
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
          screenId: LegacyPerformanceScreen.id,
          profileGranularityFlagNotifier:
              controller.cpuProfilerController.profileGranularityFlagNotifier,
        ),
        const SizedBox(width: defaultSpacing),
        if (!serviceManager.connectedApp.isDartCliAppNow)
          ServiceExtensionButtonGroup(
            minScreenWidthForTextBeforeScaling:
                _secondaryControlsMinIncludeTextWidth,
            extensions: [performanceOverlay, profileWidgetBuilds],
          ),
        // TODO(kenz): hide or disable button if http timeline logging is not
        // available.
        const SizedBox(width: defaultSpacing),
        ExportButton(
          onPressed: _exportPerformanceData,
          minScreenWidthForTextBeforeScaling:
              _secondaryControlsMinIncludeTextWidth,
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
      builder: (context) => LegacyPerformanceSettingsDialog(controller),
    );
  }

  Future<void> _refreshPerformanceData() async {
    await controller.refreshData();
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
  FutureOr<void> processOfflineData(
      LegacyOfflinePerformanceData offlineData) async {
    await controller.processOfflineData(offlineData);
  }

  @override
  bool shouldLoadOfflineData() {
    return offlineMode &&
        offlineDataJson.isNotEmpty &&
        offlineDataJson[LegacyPerformanceScreen.id] != null &&
        offlineDataJson[LegacyPerformanceData.traceEventsKey] != null;
  }
}

class LegacyPerformanceSettingsDialog extends StatelessWidget {
  const LegacyPerformanceSettingsDialog(this.controller);

  final LegacyPerformanceController controller;

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
      _LegacyBadgeJankyFramesSetting(controller),
    ];
  }
}

class _LegacyBadgeJankyFramesSetting extends StatelessWidget {
  const _LegacyBadgeJankyFramesSetting(this.controller);

  final LegacyPerformanceController controller;

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
