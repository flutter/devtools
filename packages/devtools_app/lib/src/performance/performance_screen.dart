// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics.dart' as ga;
import '../analytics/analytics_common.dart';
import '../analytics/constants.dart' as analytics_constants;
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
import '../ui/colors.dart';
import '../ui/icons.dart';
import '../ui/label.dart';
import '../ui/service_extension_widgets.dart';
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
  PerformanceController controller;

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
      final timelineJson = Map<String, dynamic>.from(
          offlineController.offlineDataJson[PerformanceScreen.id])
        ..addAll({
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
        controller.offlinePerformanceData.frames.isNotEmpty;

    final performanceScreen = Column(
      children: [
        if (!offlineController.offlineMode.value) _buildPerformanceControls(),
        const SizedBox(height: denseRowSpacing),
        if (isOfflineFlutterApp ||
            (!offlineController.offlineMode.value &&
                serviceManager.connectedApp.isFlutterAppNow))
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
        _PrimaryControls(
          controller: controller,
          processing: processing,
          onClear: () => setState(() {}),
        ),
        const SizedBox(width: defaultSpacing),
        _SecondaryControls(controller: controller),
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
    Key key,
    @required this.controller,
    @required this.processing,
    this.onClear,
  }) : super(key: key);

  final PerformanceController controller;

  final bool processing;

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.recordingFrames,
      builder: (context, recording, _) {
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
            OutlinedIconButton(
              icon: Icons.block,
              tooltip: 'Clear',
              onPressed: processing ? null : _clearPerformanceData,
            ),
          ],
        );
      },
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
      onClear();
    }
  }
}

class _SecondaryControls extends StatelessWidget {
  const _SecondaryControls({
    Key key,
    @required this.controller,
  }) : super(key: key);

  static const minScreenWidthForTextBeforeScaling = 1050.0;

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (serviceManager.connectedApp.isFlutterAppNow) ...[
          ServiceExtensionButtonGroup(
            minScreenWidthForTextBeforeScaling:
                minScreenWidthForTextBeforeScaling,
            extensions: [
              performanceOverlay,
              // TODO(devoncarew): Enable this once we have a UI displaying the
              // values.
              //trackRebuildWidgets,
            ],
          ),
          const SizedBox(width: denseSpacing),
          const EnhanceTracingButton(),
          const SizedBox(width: denseSpacing),
          IconLabelButton(
            icon: Icons.build,
            label: 'More debugging options',
            color: Theme.of(context).colorScheme.toggleButtonsTitle,
            tooltip:
                'Opens a list of options you can use to help debug performance',
            minScreenWidthForTextBeforeScaling:
                minScreenWidthForTextBeforeScaling,
            onPressed: () => _openDebuggingOptionsDialog(context),
          ),
        ],
        const SizedBox(width: denseSpacing),
        ProfileGranularityDropdown(
          screenId: PerformanceScreen.id,
          profileGranularityFlagNotifier:
              controller.cpuProfilerController.profileGranularityFlagNotifier,
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
          label: 'Performance Settings',
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
    Notifications.of(context).push(successfulExportMessage(exportedFile));
  }

  void _openDebuggingOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => DebuggingOptionsDialog(),
    );
  }

  void _openSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PerformanceSettingsDialog(controller),
    );
  }
}

class EnhanceTracingButton extends StatefulWidget {
  const EnhanceTracingButton({Key key}) : super(key: key);

  @override
  State<EnhanceTracingButton> createState() => _EnhanceTracingButtonState();
}

class _EnhanceTracingButtonState extends State<EnhanceTracingButton>
    with AutoDisposeMixin {
  static const _hoverYOffset = 10.0;

  final _tracingServiceExtensions = [
    profileWidgetBuilds,
    profileRenderObjectLayouts,
    profileRenderObjectPaints,
  ];

  final _tracingEnhanced = ValueNotifier(false);

  List<bool> _extensionStates;

  OverlayEntry _enhanceTracingOverlay;

  bool _enhanceTracingOverlayHovered = false;

  @override
  void initState() {
    super.initState();
    _extensionStates =
        List.generate(_tracingServiceExtensions.length, (index) => false);
    for (int i = 0; i < _tracingServiceExtensions.length; i++) {
      final extension = _tracingServiceExtensions[i];
      final state = serviceManager.serviceExtensionManager
          .getServiceExtensionState(extension.extension);
      _extensionStates[i] = state.value.enabled;
      // Listen for extension state changes so that we can update the value of
      // [_tracingEnhanced].
      addAutoDisposeListener(state, () {
        _extensionStates[i] = state.value.enabled;
        _tracingEnhanced.value = _isTracingEnhanced();
      });
    }
    _tracingEnhanced.value = _isTracingEnhanced();
  }

  bool _isTracingEnhanced() {
    for (final state in _extensionStates) {
      if (state) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _tracingEnhanced,
      builder: (context, tracingEnhanced, _) {
        return DevToolsToggleButtonGroup(
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: defaultSpacing),
              child: MaterialIconLabel(
                label: 'Enhance Tracing',
                iconData: Icons.auto_awesome,
                minScreenWidthForTextBeforeScaling:
                    _SecondaryControls.minScreenWidthForTextBeforeScaling,
              ),
            ),
          ],
          selectedStates: [tracingEnhanced],
          onPressed: (_) => _insertOverlay(context),
        );
      },
    );
  }

  void _insertOverlay(BuildContext context) {
    final offset = _calculateOverlayPosition(
      EnhanceTracingOverlay.width,
      context,
    );
    _enhanceTracingOverlay?.remove();
    Overlay.of(context).insert(
      _enhanceTracingOverlay = OverlayEntry(
        maintainState: true,
        builder: (context) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _maybeRemoveEnhanceTracingOverlay,
            child: Stack(
              children: [
                Positioned(
                  left: offset.dx,
                  top: offset.dy,
                  child: MouseRegion(
                    onEnter: _mouseEnter,
                    onExit: _mouseExit,
                    child: const EnhanceTracingOverlay(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Offset _calculateOverlayPosition(double width, BuildContext context) {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = context.findRenderObject() as RenderBox;

    final maxX = overlayBox.size.width - width;
    final maxY = overlayBox.size.height;

    final offset = box.localToGlobal(
      box.size.bottomCenter(Offset.zero).translate(-width / 2, _hoverYOffset),
      ancestor: overlayBox,
    );

    return Offset(
      offset.dx.clamp(0.0, maxX),
      offset.dy.clamp(0.0, maxY),
    );
  }

  void _mouseEnter(PointerEnterEvent event) {
    _enhanceTracingOverlayHovered = true;
  }

  void _mouseExit(PointerExitEvent event) {
    _enhanceTracingOverlayHovered = false;
  }

  void _maybeRemoveEnhanceTracingOverlay() {
    if (!_enhanceTracingOverlayHovered) {
      _enhanceTracingOverlay?.remove();
      _enhanceTracingOverlay = null;
    }
  }
}

class EnhanceTracingOverlay extends StatelessWidget {
  const EnhanceTracingOverlay({Key key}) : super(key: key);

  static const width = 600.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      child: Container(
        width: width,
        padding: const EdgeInsets.all(defaultSpacing),
        decoration: BoxDecoration(
          color: theme.colorScheme.defaultBackgroundColor,
          border: Border.all(
            color: theme.focusColor,
            width: hoverCardBorderWidth,
          ),
          borderRadius: BorderRadius.circular(defaultBorderRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                text: 'These options can be used to add more detail to the '
                    'timeline, but be aware that ',
                style: theme.subtleTextStyle,
                children: [
                  TextSpan(
                    text: 'frame times may be negatively affected',
                    style:
                        theme.subtleTextStyle.copyWith(color: rasterJankColor),
                  ),
                  TextSpan(
                    text: '.',
                    style: theme.subtleTextStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: denseSpacing),
            // TODO(kenz): link to documentation for each of these features when
            // docs are available.
            ServiceExtensionCheckbox(service: profileWidgetBuilds),
            ServiceExtensionCheckbox(service: profileRenderObjectLayouts),
            ServiceExtensionCheckbox(service: profileRenderObjectPaints),
          ],
        ),
      ),
    );
  }
}

class DebuggingOptionsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: dialogTitleText(theme, 'Debugging Options'),
      includeDivider: false,
      content: Container(
        width: defaultDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'When toggling on/off a rendering layer, you will need '
              'to reproduce activity in your app to see the effects of the '
              'debugging option.',
              style: theme.subtleTextStyle,
            ),
            const SizedBox(height: defaultSpacing),
            ServiceExtensionCheckbox(service: disableClipLayers),
            ServiceExtensionCheckbox(service: disableOpacityLayers),
            ServiceExtensionCheckbox(service: disablePhysicalShapeLayers),
          ],
        ),
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
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
            TimelineStreamSettings(controller: controller),
            if (serviceManager.connectedApp.isFlutterAppNow) ...[
              const SizedBox(height: denseSpacing),
              FlutterSettings(controller: controller),
            ],
          ],
        ),
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }
}

class TimelineStreamSettings extends StatelessWidget {
  const TimelineStreamSettings({
    Key key,
    @required this.controller,
  }) : super(key: key);

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...dialogSubHeader(theme, 'Recorded Timeline Streams'),
        ..._defaultRecordedStreams(theme),
        ..._advancedStreams(theme),
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
      CheckboxSetting(
        title: 'Network',
        description: 'Http traffic',
        notifier: controller.httpTimelineLoggingEnabled,
        onChanged: controller.toggleHttpRequestLogging,
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
    final streams = advanced
        ? serviceManager.timelineStreamManager.advancedStreams
        : serviceManager.timelineStreamManager.basicStreams;
    final settings = streams
        .map(
          (stream) => CheckboxSetting(
            title: stream.name,
            description: stream.description,
            notifier: stream.recorded,
            onChanged: (newValue) =>
                serviceManager.timelineStreamManager.updateTimelineStream(
              stream,
              newValue,
            ),
          ),
        )
        .toList();
    return settings;
  }
}

class FlutterSettings extends StatelessWidget {
  const FlutterSettings({Key key, @required this.controller}) : super(key: key);

  final PerformanceController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...dialogSubHeader(Theme.of(context), 'Additional Settings'),
        CheckboxSetting(
          notifier: controller.badgeTabForJankyFrames,
          title: 'Badge Performance tab when Flutter UI jank is detected',
        ),
      ],
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

  final Duration uiDuration;
  final Duration rasterDuration;
  final Duration shaderCompilationDuration;
  final int traceEventCount;
}
