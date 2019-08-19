// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:js/js.dart';
import 'package:meta/meta.dart';
import 'package:split/split.dart' as split;

import '../charts/flame_chart_canvas.dart';
import '../framework/framework.dart';
import '../globals.dart';
import '../service_extensions.dart';
import '../ui/analytics.dart' as ga;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/icons.dart';
import '../ui/material_icons.dart';
import '../ui/primer.dart';
import '../ui/service_extension_elements.dart';
import '../ui/ui_utils.dart';
import '../ui/vm_flag_elements.dart';
import 'event_details.dart';
import 'frames_bar_chart.dart';
import 'timeline_controller.dart';
import 'timeline_flame_chart.dart';
import 'timeline_model.dart';
import 'timeline_protocol.dart';

// TODO(devoncarew): show the Skia picture (gpu drawing commands) for a frame

// TODO(devoncarew): show the list of widgets re-drawn during a frame

// TODO(devoncarew): display whether running in debug or profile

// TODO(devoncarew): Have a timeline view thumbnail overview.

// TODO(devoncarew): Switch to showing all timeline events, but highlighting the
// area associated with the selected frame.

const enableMultiModeTimeline = false;

class TimelineScreen extends Screen {
  TimelineScreen({bool disabled, String disabledTooltip})
      : super(
          name: 'Timeline',
          id: timelineScreenId,
          iconClass: 'octicon-pulse',
          disabled: disabled,
          disabledTooltip: disabledTooltip,
        );

  TimelineController timelineController = TimelineController();

  FramesBarChart framesBarChart;

  CoreElement flameChartContainer;

  TimelineFlameChartCanvas flameChartCanvas;

  EventDetails eventDetails;

  PButton pauseButton;

  PButton resumeButton;

  PButton _startRecordingButton;

  PButton _stopRecordingButton;

  PButton clearButton;

  PButton exportButton;

  PButton exitOfflineModeButton;

  ServiceExtensionButton performanceOverlayButton;

  ProfileGranularitySelector _profileGranularitySelector;

  CoreElement _frameBasedTimelineSettingContainer;

  CoreElement _frameBasedTimelineCheckbox;

  CoreElement _recordingInstructions;

  CoreElement _recordingStatus;

  CoreElement _recordingStatusMessage;

  CoreElement upperButtonSection;

  CoreElement debugButtonSection;

  split.Splitter splitter;

  bool splitterConfigured = false;

  @override
  CoreElement createContent(Framework framework) {
    ga_platform.setupDimensions();

    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    pauseButton = PButton.icon('Pause recording', FlutterIcons.pause_white_2x)
      ..small()
      ..primary()
      ..hidden(timelineController.timelineMode == TimelineMode.full)
      ..click(_pauseFrameRecording);

    resumeButton =
        PButton.icon('Resume recording', FlutterIcons.resume_black_disabled_2x)
          ..small()
          ..clazz('margin-left')
          ..disabled = timelineController.manuallyPaused
          ..hidden(timelineController.timelineMode == TimelineMode.full)
          ..click(_resumeFrameRecording);

    _startRecordingButton = PButton.icon('Record', recordPrimary)
      ..small()
      ..primary()
      ..hidden(timelineController.timelineMode == TimelineMode.frameBased)
      ..click(_startRecording);

    _stopRecordingButton = PButton.icon('Stop', stop)
      ..small()
      ..clazz('margin-left')
      ..disabled = !timelineController.recording
      ..hidden(timelineController.timelineMode == TimelineMode.frameBased)
      ..click(_stopRecording);

    _recordingInstructions = createRecordingInstructions(
        recordingGoal: 'to start recording timeline trace.');

    _recordingStatus = div(c: 'center-in-parent')
      ..layoutVertical()
      ..flex()
      ..add([
        _recordingStatusMessage = div(c: 'recording-status-message'),
        Spinner.centered(classes: ['recording-spinner']),
      ]);

    exportButton = PButton.icon('Export', exportIcon)
      ..small()
      ..clazz('margin-left')
      ..setAttribute('title', 'Export timeline')
      ..click(_exportTimeline);

    clearButton = PButton.icon('Clear', clearIcon)
      ..small()
      ..clazz('margin-left')
      ..setAttribute('title', 'Clear timeline')
      ..click(clearTimeline);

    exitOfflineModeButton = PButton.icon(
      'Exit offline mode',
      exitIcon,
    )
      ..small()
      ..setAttribute('title', 'Exit offline mode to connect to a VM Service.')
      ..setAttribute('hidden', 'true')
      ..click(_exitOfflineMode);

    performanceOverlayButton = ServiceExtensionButton(performanceOverlay);

    _profileGranularitySelector = ProfileGranularitySelector(framework);

    _frameBasedTimelineCheckbox = CoreElement('input', classes: 'checkbox')
      ..setAttribute('type', 'checkbox');
    final html.InputElement checkbox = _frameBasedTimelineCheckbox.element;
    checkbox
      ..checked = timelineController.timelineMode == TimelineMode.frameBased
      ..onChange.listen((_) => _setTimelineMode(
          timelineMode:
              checkbox.checked ? TimelineMode.frameBased : TimelineMode.full));

    _frameBasedTimelineSettingContainer = div(c: 'checkbox-container')
      ..layoutHorizontal()
      ..add([
        _frameBasedTimelineCheckbox,
        div(text: 'Show frames', c: 'checkbox-text')
      ]);

    // TODO(kenzie): once [enableMultiModeTimeline] is enabled by default,
    // adjust collapsible-xxx CSS classes to account for timeline mode checkbox.
    upperButtonSection = div(c: 'section')
      ..layoutHorizontal()
      ..add(<CoreElement>[
        div(c: 'btn-group collapsible-885')
          ..add([
            pauseButton,
            resumeButton,
            _startRecordingButton,
            _stopRecordingButton,
          ]),
        div(c: 'btn-group collapsible-685')..add(clearButton),
        exitOfflineModeButton,
        div()..flex(),
        debugButtonSection = div(c: 'btn-group'),
        if (enableMultiModeTimeline) _frameBasedTimelineSettingContainer,
        _profileGranularitySelector.selector..clazz('margin-left'),
        div(c: 'btn-group collapsible-685 margin-left')
          ..add(performanceOverlayButton.button),
        div(c: 'btn-group collapsible-685')..add(exportButton),
      ]);

    _maybeAddDebugButtons();

    screenDiv.add(<CoreElement>[
      upperButtonSection,
      framesBarChart = FramesBarChart(timelineController),
      div(c: 'section')
        ..layoutVertical()
        ..flex()
        ..add(<CoreElement>[
          flameChartContainer =
              div(c: 'timeline-flame-chart-container section-border')
                ..flex()
                ..layoutVertical()
                ..hidden(true),
          eventDetails = EventDetails(timelineController)..hidden(true),
        ]),
    ]);

    maybeAddDebugMessage(framework, timelineScreenId);

    return screenDiv;
  }

  @override
  void onContentAttached() {
    timelineController.onSelectedFrame.listen((_) {
      flameChartContainer
        ..clear()
        ..hidden(false);
      final TimelineFrame frame = timelineController.timelineData.selectedFrame;
      flameChartCanvas = TimelineFlameChartCanvas(
        data: frame,
        width: flameChartContainer.element.clientWidth.toDouble(),
        height: math.max(
          // Subtract [rowHeightWithPadding] to account for timeline at the top of
          // the flame chart.
          flameChartContainer.element.clientHeight.toDouble(),
          // Add 1 to account for a row of padding at the bottom of the chart.
          (frame.uiEventFlow.depth + frame.gpuEventFlow.depth + 1) *
                  rowHeightWithPadding +
              TimelineFlameChartCanvas.sectionSpacing,
        ),
      );
      flameChartCanvas.onNodeSelected.listen((node) {
        eventDetails.titleBackgroundColor = node.backgroundColor;
        eventDetails.titleTextColor = node.textColor;
        timelineController.selectTimelineEvent(node.data);
      });
      flameChartContainer.add(flameChartCanvas.element);

      _configureSplitter();
    });

    timelineController.onLoadOfflineData.listen((_) {
      framesBarChart.hidden(false);
      flameChartContainer..hidden(true);
      _destroySplitter();
    });

    timelineController.onNonFatalError.listen((message) {
      ga.error(message, false);
    });

    // The size of [flameChartContainer] will change as the splitter moved.
    // Observe resizing so that we can rebuild the flame chart canvas as
    // necessary.
    // TODO(kenzie): clean this code up when
    // https://github.com/dart-lang/html/issues/104 is fixed.
    final observer =
        html.ResizeObserver(allowInterop((List<dynamic> entries, _) {
      // TODO(kenzie): observe resizing for recordedTimeline as well. Recorded
      // timeline will not have a selected frame.
      if (flameChartCanvas == null ||
          timelineController.timelineMode == TimelineMode.full) {
        return;
      }

      flameChartCanvas.forceRebuildForSize(
        flameChartCanvas.widthWithInsets,
        math.max(
          // Subtract [rowHeightWithPadding] to account for the size of
          // [stackFrameDetails] section at the bottom of the chart.
          flameChartContainer.element.scrollHeight.toDouble(),
          // Add 1 to account for a row of padding at the bottom of the chart.
          (timelineController.timelineData.selectedFrame.uiEventFlow.depth +
                      timelineController
                          .timelineData.selectedFrame.gpuEventFlow.depth +
                      1) *
                  rowHeightWithPadding +
              TimelineFlameChartCanvas.sectionSpacing,
        ),
      );
    }));
    observer.observe(flameChartContainer.element);
  }

  void _configureSplitter() {
    // Configure the flame chart / event details splitter if we haven't
    // already.
    if (!splitterConfigured) {
      // TODO(jacobr): we need to tweak this layout so there is more room to
      // display this UI. On typical devices, the space available is very
      // limited making the UI harder to use than it would be otherwise./
      splitter = split.flexSplit(
        [flameChartContainer.element, eventDetails.element],
        horizontal: false,
        gutterSize: defaultSplitterWidth,
        sizes: [75, 25],
        minSize: [50, 50],
      );
      splitterConfigured = true;
    }
  }

  void _destroySplitter() {
    if (splitterConfigured) {
      splitter.destroy();
      splitterConfigured = false;
    }
  }

  @override
  void entering() {
    _updateListeningState();
    _updateButtonStates();
    _profileGranularitySelector.setGranularity();
  }

  @override
  void exiting() {
    _updateListeningState();
    _updateButtonStates();
  }

  void _exitOfflineMode() {
    // This needs to be called first because [framework.exitOfflineMode()] will
    // remove all elements from the dom if we are not connected to an app.
    // Performing operations from [_clearTimeline()] on elements that have been
    // removed will throw exceptions, so we need to maintain this order.
    clearTimeline();
    eventDetails.reset(hide: true);
    timelineController.exitOfflineMode();
    // This needs to be called before we update the button states because it
    // changes the value of [offlineMode], which the button states depend on.
    framework.exitOfflineMode();
    // Revert to the previously selected mode on offline exit.
    _setTimelineMode(timelineMode: timelineController.timelineMode);
    _updateButtonStates();
  }

  Future<void> _pauseFrameRecording() async {
    assert(timelineController.timelineMode == TimelineMode.frameBased);
    timelineController.pause(manual: true);
    ga.select(ga.timeline, ga.pause);
    _updateButtonStates();
    await _updateListeningState();
  }

  Future<void> _resumeFrameRecording() async {
    assert(timelineController.timelineMode == TimelineMode.frameBased);
    timelineController.resume();
    ga.select(ga.timeline, ga.resume);
    _updateButtonStates();
    await _updateListeningState();
  }

  void _startRecording() {
    assert(timelineController.timelineMode == TimelineMode.full);
    timelineController.startRecording();
    _recordingInstructions.hidden(true);
    _recordingStatusMessage.text = 'Recording timeline trace';
    _recordingStatus.hidden(false);
    _updateButtonStates();
  }

  void _stopRecording() {
    assert(timelineController.timelineMode == TimelineMode.full);
    _recordingStatusMessage.text = 'Processing timeline trace';
    timelineController.stopRecording();
    _recordingStatus.hidden(true);
    _updateButtonStates();
  }

  void _setTimelineMode({@required TimelineMode timelineMode}) {
    // TODO(kenzie): the two modes should be aware of one another and we should
    // share data. For simplicity, we will start by having each mode be aware of
    // only its own data and clearing on mode switch.
    timelineController.timelineData.clear();

    timelineController.timelineMode = timelineMode;
    _updateButtonStates();

    // Update visibility and then reset - the order matters here.
    framesBarChart
      ..hidden(timelineMode == TimelineMode.full)
      ..frameUIgraph.reset();

    flameChartCanvas = null;
    flameChartContainer
      ..clear()
      ..hidden(timelineMode == TimelineMode.frameBased);
    if (timelineMode == TimelineMode.full) {
      flameChartContainer.add([
        _recordingInstructions..hidden(false),
        _recordingStatus..hidden(true),
      ]);
    }

    eventDetails.reset(hide: timelineMode == TimelineMode.frameBased);

    if (timelineMode == TimelineMode.frameBased) {
      _destroySplitter();
    } else {
      _configureSplitter();
    }
  }

  void _updateButtonStates() {
    pauseButton
      ..disabled = timelineController.manuallyPaused
      ..hidden(
          offlineMode || timelineController.timelineMode == TimelineMode.full);
    resumeButton
      ..disabled = !timelineController.manuallyPaused
      ..hidden(
          offlineMode || timelineController.timelineMode == TimelineMode.full);
    _startRecordingButton
      ..disabled = timelineController.recording
      ..hidden(offlineMode ||
          timelineController.timelineMode == TimelineMode.frameBased);
    _stopRecordingButton
      ..disabled = !timelineController.recording
      ..hidden(offlineMode ||
          timelineController.timelineMode == TimelineMode.frameBased);
    _frameBasedTimelineCheckbox.disabled = timelineController.recording;

    // TODO(kenzie): support loading offline data in both modes.
    _frameBasedTimelineSettingContainer.hidden(offlineMode);

    clearButton
      ..disabled = timelineController.recording
      ..hidden(offlineMode);
    exportButton
      ..disabled = timelineController.recording
      ..hidden(offlineMode);
    performanceOverlayButton.button.hidden(offlineMode);
    _profileGranularitySelector.selector.hidden(offlineMode);
    exitOfflineModeButton.hidden(!offlineMode);
  }

  Future<void> _updateListeningState() async {
    final bool shouldBeRunning =
        !timelineController.manuallyPaused && !offlineMode && isCurrentScreen;
    final bool isRunning = !timelineController.paused;
    await timelineController.timelineService.updateListeningState(
      shouldBeRunning: shouldBeRunning,
      isRunning: isRunning,
    );
  }

  void clearTimeline() {
    timelineController.timelineData?.clear();
    flameChartContainer
        .hidden(timelineController.timelineMode == TimelineMode.frameBased);
    flameChartCanvas = null;
    eventDetails.reset(
        hide: timelineController.timelineMode == TimelineMode.frameBased);

    switch (timelineController.timelineMode) {
      case TimelineMode.frameBased:
        debugHandledTraceEvents.clear();
        debugFrameTracking.clear();
        framesBarChart.frameUIgraph.reset();
        _destroySplitter();
        break;
      case TimelineMode.full:
        _recordingInstructions.hidden(false);
    }
  }

  void _exportTimeline() {
    // TODO(kenzie): add analytics for this. It would be helpful to know how
    // complex the problems are that users are trying to solve.
    final String encodedTimelineData =
        jsonEncode(timelineController.timelineData.json);
    final now = DateTime.now();
    final timestamp =
        '${now.year}_${now.month}_${now.day}-${now.microsecondsSinceEpoch}';
    downloadFile(encodedTimelineData, 'timeline_$timestamp.json');
  }

  /// Adds a button to the timeline that will dump debug information to text
  /// files and download them. This will only appear if the [debugTimeline] flag
  /// is true.
  void _maybeAddDebugButtons() {
    if (debugTimeline) {
      debugButtonSection.add(PButton('Debug dump timeline')
        ..small()
        ..click(() {
          // Trace event json in the order we handled the events.
          final handledTraceEventsJson = {
            'traceEvents': debugHandledTraceEvents
          };
          downloadFile(
            jsonEncode(handledTraceEventsJson),
            'handled_trace_output.json',
          );

          // Significant events in the frame tracking process.
          downloadFile(
            debugFrameTracking.toString(),
            'frame_tracking_output.txt',
          );

          final timelineProtocol = timelineController.timelineProtocol;

          // Current status of our frame tracking elements (i.e. pendingEvents,
          // pendingFrames).
          final buf = StringBuffer();
          buf.writeln('Pending events: '
              '${timelineProtocol.pendingEvents.length}');
          for (TimelineEvent event in timelineProtocol.pendingEvents) {
            event.format(buf, '    ');
            buf.writeln();
          }
          buf.writeln('\nPending frames: '
              '${timelineProtocol.pendingFrames.length}');
          for (TimelineFrame frame in timelineProtocol.pendingFrames.values) {
            buf.writeln('${frame.toString()}');
          }
          if (timelineProtocol.currentEventNodes[TimelineEventType.ui.index] !=
              null) {
            buf.writeln('\nCurrent UI event node:');
            timelineProtocol.currentEventNodes[TimelineEventType.ui.index]
                .format(buf, '   ');
          }
          if (timelineProtocol.currentEventNodes[TimelineEventType.gpu.index] !=
              null) {
            buf.writeln('\n Current GPU event node:');
            timelineProtocol.currentEventNodes[TimelineEventType.gpu.index]
                .format(buf, '   ');
          }
          if (timelineProtocol.heaps[TimelineEventType.ui.index].isNotEmpty) {
            buf.writeln('\nUI heap');
            for (TraceEventWrapper wrapper in timelineProtocol
                .heaps[TimelineEventType.ui.index]
                .toList()) {
              buf.writeln(wrapper.event.json.toString());
            }
          }
          if (timelineProtocol.heaps[TimelineEventType.gpu.index].isNotEmpty) {
            buf.writeln('\nGPU heap');
            for (TraceEventWrapper wrapper in timelineProtocol
                .heaps[TimelineEventType.gpu.index]
                .toList()) {
              buf.writeln(wrapper.event.json.toString());
            }
          }
          downloadFile(buf.toString(), 'pending_frame_tracking_status.txt');
        }));
    }
  }
}
