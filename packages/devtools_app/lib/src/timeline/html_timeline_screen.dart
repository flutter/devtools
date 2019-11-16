// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:math' as math;

import 'package:html_shim/html.dart' as html;
import 'package:meta/meta.dart';
import 'package:split/split.dart' as split;

import '../charts/flame_chart_canvas.dart';
import '../framework/html_framework.dart';
import '../globals.dart';
import '../service_extensions.dart';
import '../ui/analytics.dart' as ga;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/html_custom.dart';
import '../ui/html_elements.dart';
import '../ui/icons.dart';
import '../ui/material_icons.dart';
import '../ui/primer.dart';
import '../ui/service_extension_elements.dart';
import '../ui/ui_utils.dart';
import '../ui/vm_flag_elements.dart';
import 'html_event_details.dart';
import 'html_frames_bar_chart.dart';
import 'timeline_controller.dart';
import 'timeline_flame_chart.dart';
import 'timeline_model.dart';
import 'timeline_processor.dart';

// TODO(devoncarew): show the Skia picture (gpu drawing commands) for a frame

// TODO(devoncarew): show the list of widgets re-drawn during a frame

// TODO(devoncarew): display whether running in debug or profile

// TODO(devoncarew): Have a timeline view thumbnail overview.

// TODO(kenz): connect a frame's UI and GPU code in the full_timeline.

const enableMultiModeTimeline = true;

class HtmlTimelineScreen extends HtmlScreen {
  HtmlTimelineScreen(
    this.startTimelineMode, {
    bool enabled,
    String disabledTooltip,
  }) : super(
          name: 'Timeline',
          id: timelineScreenId,
          iconClass: 'octicon-pulse',
          enabled: enabled,
          disabledTooltip: disabledTooltip,
        ) {
    timelineController.timelineMode = startTimelineMode;
  }

  final TimelineMode startTimelineMode;

  TimelineController timelineController = TimelineController();

  FramesBarChart framesBarChart;

  CoreElement flameChartContainer;

  CoreElement _emptyFlameChart;

  FlameChartCanvas timelineFlameChartCanvas;

  HtmlEventDetails eventDetails;

  PButton pauseButton;

  PButton resumeButton;

  PButton _startRecordingButton;

  PButton _stopRecordingButton;

  PButton clearButton;

  PButton exportButton;

  PButton exitOfflineModeButton;

  ServiceExtensionButton performanceOverlayButton;

  ProfileGranularitySelector _profileGranularitySelector;

  CoreElement _timelineModeSettingContainer;

  CoreElement _timelineModeCheckbox;

  CoreElement _recordingInstructions;

  CoreElement _recordingStatus;

  CoreElement _recordingStatusMessage;

  HtmlSpinner _recordingSpinner;

  CoreElement upperButtonSection;

  CoreElement debugButtonSection;

  split.Splitter splitter;

  bool splitterConfigured = false;

  @override
  CoreElement createContent(HtmlFramework framework) {
    ga_platform.setupDimensions();

    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    pauseButton = PButton.icon('Pause recording', FlutterIcons.pause_white_2x)
      ..small()
      ..primary()
      ..click(_pauseFrameRecording);

    resumeButton =
        PButton.icon('Resume recording', FlutterIcons.resume_black_disabled_2x)
          ..small()
          ..clazz('margin-left')
          ..disabled = timelineController.frameBasedTimeline.manuallyPaused
          ..click(_resumeFrameRecording);

    _startRecordingButton = PButton.icon('Record', recordPrimary)
      ..small()
      ..primary()
      ..click(() async => await _startFullRecording());

    _stopRecordingButton = PButton.icon('Stop', stop)
      ..small()
      ..clazz('margin-left')
      ..disabled = !timelineController.fullTimeline.recording
      ..click(_stopFullRecording);

    _recordingInstructions = createRecordingInstructions(
        recordingGoal: 'to start recording timeline trace.');

    _recordingStatus = div(c: 'center-in-parent')
      ..layoutVertical()
      ..flex()
      ..add([
        _recordingStatusMessage = div(c: 'recording-status-message'),
        _recordingSpinner =
            HtmlSpinner.centered(classes: ['recording-spinner']),
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
      ..click(() async => await clearTimeline());

    exitOfflineModeButton = PButton.icon(
      'Exit offline mode',
      exitIcon,
    )
      ..small()
      ..setAttribute('title', 'Exit offline mode to connect to a VM Service.')
      ..click(_exitOfflineMode);

    performanceOverlayButton = ServiceExtensionButton(performanceOverlay);

    _profileGranularitySelector = ProfileGranularitySelector(framework);

    _timelineModeCheckbox = CoreElement('input', classes: 'checkbox')
      ..setAttribute('type', 'checkbox');
    final html.InputElement checkbox = _timelineModeCheckbox.element;
    checkbox
      ..checked = timelineController.timelineMode == TimelineMode.frameBased
      ..onChange.listen((_) => _setTimelineMode(
          timelineMode:
              checkbox.checked ? TimelineMode.frameBased : TimelineMode.full));

    _timelineModeSettingContainer = div(c: 'checkbox-container')
      ..layoutHorizontal()
      ..add([
        _timelineModeCheckbox,
        div(text: 'Show frames', c: 'checkbox-text')
      ]);

    upperButtonSection = div(c: 'section')
      ..layoutHorizontal()
      ..add(<CoreElement>[
        div(c: 'btn-group collapsible-1015')
          ..add([
            pauseButton,
            resumeButton,
            _startRecordingButton,
            _stopRecordingButton,
          ]),
        div(c: 'btn-group collapsible-800')..add(clearButton),
        exitOfflineModeButton,
        div()..flex(),
        debugButtonSection = div(c: 'btn-group'),
        if (enableMultiModeTimeline) _timelineModeSettingContainer,
        _profileGranularitySelector.selector..clazz('margin-left'),
        div(c: 'btn-group collapsible-800 margin-left')
          ..add(performanceOverlayButton.button),
        div(c: 'btn-group collapsible-800')..add(exportButton),
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
                ..add([
                  _emptyFlameChart =
                      div(), // Dummy for modifying the flame chart.
                  _recordingInstructions,
                  _recordingStatus,
                ]),
          eventDetails = HtmlEventDetails(timelineController),
        ]),
    ]);

    maybeAddDebugMessage(framework, timelineScreenId);

    return screenDiv;
  }

  @override
  void onContentAttached() {
    _updateVisibilityForTimelineMode();
    if (timelineController.timelineMode == TimelineMode.full) {
      _configureSplitter();
    }

    timelineController.frameBasedTimeline.onSelectedFrame.listen((_) {
      _selectFrame();
    });

    timelineController.fullTimeline
      ..onTimelineProcessed.listen((_) {
        timelineFlameChartCanvas = FullTimelineFlameChartCanvas(
          data: timelineController.fullTimeline.data,
          width: flameChartContainer.element.clientWidth.toDouble(),
          height: math.max(
            // Subtract [rowHeightWithPadding] to account for timeline at the top of
            // the flame chart.
            flameChartContainer.element.clientHeight.toDouble(),
            // Add 1 to account for a row of padding at the bottom of the chart.
            _fullTimelineChartHeight(),
          ),
        );
        timelineFlameChartCanvas.onNodeSelected.listen((node) {
          eventDetails.titleBackgroundColor = node.backgroundColor;
          eventDetails.titleTextColor = node.textColor;
          timelineController.selectTimelineEvent(node.data);
        });
        _setFlameChart(timelineFlameChartCanvas.element);

        _configureSplitter();
      })
      ..onNoEventsRecorded.listen((_) {
        _recordingStatusMessage.text = 'No timeline events recorded';
        _recordingStatus.hidden(false);
        _recordingSpinner.hidden(true);
      });

    timelineController.onLoadOfflineData.listen((_) {
      if (timelineController.offlineTimelineData
          is OfflineFrameBasedTimelineData) {
        final offlineData = timelineController.offlineTimelineData
            as OfflineFrameBasedTimelineData;
        // Relayout the plotly graph so that the frames bar chart reflects the
        // display refresh rate from the imported snapshot.
        framesBarChart.frameUIgraph.plotlyChart
          ..displayRefreshRate = offlineData.displayRefreshRate
          ..relayoutFPSTimeseriesLayout();

        flameChartContainer.hidden(offlineData.selectedFrameId == null);
        eventDetails.hidden(offlineData.selectedFrameId == null);

        if (offlineData.selectedFrameId == null) {
          _destroySplitter();
        } else {
          _selectFrame();
        }
      }

      if (timelineController.offlineTimelineData.hasCpuProfileData()) {
        _configureSplitter(sizes: [50, 50]);
      }
    });

    timelineController.onNonFatalError.listen((message) {
      ga.error(message, false);
    });

    // The size of [flameChartContainer] will change as the splitter moved.
    // Observe resizing so that we can rebuild the flame chart canvas as
    // necessary.
    // TODO(jacobr): Change argument type when
    // https://github.com/dart-lang/sdk/issues/36798 is fixed.
    final observer = html.ResizeObserver((List<dynamic> entries, _) {
      if (timelineFlameChartCanvas == null ||
          (timelineController.timelineMode == TimelineMode.frameBased &&
              timelineController.frameBasedTimeline.data.selectedFrame ==
                  null)) {
        return;
      }

      final dataHeight = timelineController.timelineMode ==
              TimelineMode.frameBased
          ? // Add 1 to account for a row of padding at the bottom of the chart.
          _frameBasedTimelineChartHeight()
          : // Add 1 to account for a row of padding at the bottom of the chart.
          _fullTimelineChartHeight();

      timelineFlameChartCanvas.forceRebuildForSize(
        timelineFlameChartCanvas.calculatedWidthWithInsets,
        math.max(
          // Subtract [rowHeightWithPadding] to account for the size of
          // [stackFrameDetails] section at the bottom of the chart.
          flameChartContainer.element.scrollHeight.toDouble(),
          dataHeight,
        ),
      );
    });
    observer.observe(flameChartContainer.element);
  }

  void _setFlameChart(CoreElement flameChart) {
    // If the container does not have a flame chart yet, this call will replace
    // the dummy element added in `createContent`.
    assert(flameChartContainer.element.children.length == 3);
    flameChartContainer.replace(0, flameChart);
  }

  void _selectFrame() {
    flameChartContainer.hidden(false);
    final TimelineFrame frame =
        timelineController.frameBasedTimeline.data.selectedFrame;
    timelineFlameChartCanvas = FrameBasedTimelineFlameChartCanvas(
      data: frame,
      width: flameChartContainer.element.clientWidth.toDouble(),
      height: math.max(
        // Subtract [rowHeightWithPadding] to account for timeline at the top of
        // the flame chart.
        flameChartContainer.element.clientHeight.toDouble(),
        // Add 1 to account for a row of padding at the bottom of the chart.
        _frameBasedTimelineChartHeight(),
      ),
    );
    timelineFlameChartCanvas.onNodeSelected.listen((node) {
      eventDetails.titleBackgroundColor = node.backgroundColor;
      eventDetails.titleTextColor = node.textColor;
      timelineController.selectTimelineEvent(node.data);
    });
    _setFlameChart(timelineFlameChartCanvas.element);

    _configureSplitter();
  }

  double _frameBasedTimelineChartHeight() {
    return (timelineController.frameBasedTimeline.data.displayDepth + 1) *
            rowHeightWithPadding +
        FrameBasedTimelineFlameChartCanvas.sectionSpacing;
  }

  double _fullTimelineChartHeight() {
    return (timelineController.fullTimeline.data.displayDepth + 1) *
            rowHeightWithPadding +
        (timelineController.fullTimeline.data.eventBuckets.length) *
            sectionSpacing;
  }

  void _configureSplitter({List<int> sizes}) {
    assert(sizes == null || sizes.length == 2);
    // Configure the flame chart / event details splitter if we haven't
    // already.
    if (!splitterConfigured) {
      // TODO(jacobr): we need to tweak this layout so there is more room to
      // display this UI. On typical devices, the space available is very
      // limited making the UI harder to use than it would be otherwise.
      splitter = split.flexSplit(
        html.toDartHtmlElementList(
            [flameChartContainer.element, eventDetails.element]),
        horizontal: false,
        gutterSize: defaultSplitterWidth,
        sizes: sizes ?? [75, 25],
        minSize: [50, 90],
      );
      splitterConfigured = true;
    } else if (sizes != null) {
      splitter.setSizes(sizes);
    }
  }

  void _destroySplitter() {
    if (splitterConfigured) {
      splitter.destroy();
      splitterConfigured = false;
    }
  }

  @override
  void entering() async {
    await timelineController.timelineService.updateListeningState(true);
    _updateButtonStates();
    await _profileGranularitySelector.setGranularity();
  }

  @override
  void exiting() async {
    await timelineController.timelineService.updateListeningState(false);
    _updateButtonStates();
  }

  Future<void> prepareViewForOfflineData(TimelineMode timelineMode) async {
    await clearTimeline();
    framesBarChart.hidden(timelineMode == TimelineMode.full);
    _setFlameChart(_emptyFlameChart);
    flameChartContainer.hidden(timelineMode == TimelineMode.frameBased);
    eventDetails.hidden(timelineMode == TimelineMode.frameBased);
    _recordingInstructions.hidden(true);
  }

  Future<void> _exitOfflineMode() async {
    // This needs to be called first because [framework.exitOfflineMode()] will
    // remove all elements from the dom if we are not connected to an app.
    // Performing operations from [_clearTimeline()] on elements that have been
    // removed will throw exceptions, so we need to maintain this order.
    await clearTimeline();
    eventDetails.reset(hide: true);

    // We already cleared the timeline data - do not repeat this action.
    timelineController.exitOfflineMode(clearTimeline: false);

    // This needs to be called before we update the button states because it
    // changes the value of [offlineMode], which the button states depend on.
    framework.exitOfflineMode();

    // Revert to [startTimelineMode]. We already cleared the timeline data - do
    // not repeat this action.
    _setTimelineMode(
      timelineMode: startTimelineMode,
      clearTimeline: false,
    );
    _updateButtonStates();
  }

  Future<void> _pauseFrameRecording() async {
    assert(timelineController.timelineMode == TimelineMode.frameBased);
    timelineController.frameBasedTimeline.pause(manual: true);
    ga.select(ga.timeline, ga.pause);
    _updateButtonStates();
    await timelineController.timelineService
        .updateListeningState(isCurrentScreen);
  }

  Future<void> _resumeFrameRecording() async {
    assert(timelineController.timelineMode == TimelineMode.frameBased);
    timelineController.frameBasedTimeline.resume();
    ga.select(ga.timeline, ga.resume);
    _updateButtonStates();
    await timelineController.timelineService
        .updateListeningState(isCurrentScreen);
  }

  Future<void> _startFullRecording() async {
    assert(timelineController.timelineMode == TimelineMode.full);
    await clearTimeline();
    timelineController.fullTimeline.startRecording();
    _recordingInstructions.hidden(true);
    _recordingStatusMessage.text = 'Recording timeline trace';
    _recordingStatus.hidden(false);
    _recordingSpinner.hidden(false);
    _updateButtonStates();
  }

  void _stopFullRecording() {
    assert(timelineController.timelineMode == TimelineMode.full);
    _recordingStatusMessage.text = 'Processing timeline trace';
    timelineController.fullTimeline.stopRecording();
    _recordingStatus.hidden(true);
    _updateButtonStates();
  }

  void _setTimelineMode({
    @required TimelineMode timelineMode,
    bool clearTimeline = true,
  }) async {
    // TODO(kenz): the two modes should be aware of one another and we should
    // share data. For simplicity, we will start by having each mode be aware of
    // only its own data and clearing on mode switch.
    if (clearTimeline) {
      timelineController.timeline.data?.clear();
    }

    timelineController.timelineMode = timelineMode;

    // Update visibility and then do resets - the order matters here.
    _updateVisibilityForTimelineMode();

    framesBarChart.frameUIgraph.reset(
        displayRefreshRate:
            await timelineController.frameBasedTimeline.displayRefreshRate);

    timelineFlameChartCanvas = null;
    _setFlameChart(_emptyFlameChart);

    eventDetails.reset(hide: timelineMode == TimelineMode.frameBased);

    if (timelineMode == TimelineMode.frameBased) {
      _destroySplitter();
    } else {
      _configureSplitter();
    }
  }

  void _updateButtonStates() async {
    final isDartCliApp = await serviceManager.connectedApp.isDartCliApp;
    pauseButton
      ..disabled = timelineController.frameBasedTimeline.manuallyPaused
      ..hidden(
          offlineMode || timelineController.timelineMode == TimelineMode.full);
    resumeButton
      ..disabled = !timelineController.frameBasedTimeline.manuallyPaused
      ..hidden(
          offlineMode || timelineController.timelineMode == TimelineMode.full);
    _startRecordingButton
      ..disabled = timelineController.fullTimeline.recording
      ..hidden(offlineMode ||
          timelineController.timelineMode == TimelineMode.frameBased);
    _stopRecordingButton
      ..disabled = !timelineController.fullTimeline.recording
      ..hidden(offlineMode ||
          timelineController.timelineMode == TimelineMode.frameBased);
    _timelineModeCheckbox.disabled = timelineController.fullTimeline.recording;
    (_timelineModeCheckbox.element as html.InputElement).checked =
        timelineController.timelineMode == TimelineMode.frameBased;

    _timelineModeSettingContainer.hidden(offlineMode || isDartCliApp);

    clearButton
      ..disabled = timelineController.fullTimeline.recording
      ..hidden(offlineMode);
    exportButton
      ..disabled = timelineController.fullTimeline.recording
      ..hidden(offlineMode);
    performanceOverlayButton.button.hidden(offlineMode || isDartCliApp);
    _profileGranularitySelector.selector.hidden(offlineMode);
    exitOfflineModeButton.hidden(!offlineMode);
  }

  void _updateVisibilityForTimelineMode() {
    _updateButtonStates();
    framesBarChart.hidden(timelineController.timelineMode == TimelineMode.full);
    flameChartContainer
        .hidden(timelineController.timelineMode == TimelineMode.frameBased);
    _recordingInstructions
        .hidden(timelineController.timelineMode == TimelineMode.frameBased);
    _recordingStatus.hidden(true);
    eventDetails
        .hidden(timelineController.timelineMode == TimelineMode.frameBased);
  }

  Future<void> clearTimeline() async {
    await timelineController.clearData();
    _setFlameChart(_emptyFlameChart);
    flameChartContainer
        .hidden(timelineController.timelineMode == TimelineMode.frameBased);
    timelineFlameChartCanvas?.element?.element?.remove();
    timelineFlameChartCanvas = null;
    eventDetails.reset(
        hide: timelineController.timelineMode == TimelineMode.frameBased);
    _recordingStatus.hidden(true);

    switch (timelineController.timelineMode) {
      case TimelineMode.frameBased:
        debugHandledTraceEvents.clear();
        debugFrameTracking.clear();
        framesBarChart.frameUIgraph.reset(
            displayRefreshRate:
                await timelineController.frameBasedTimeline.displayRefreshRate);
        _destroySplitter();
        break;
      case TimelineMode.full:
        _recordingInstructions.hidden(false);
    }
    _updateButtonStates();
  }

  void _exportTimeline() {
    // TODO(kenz): add analytics for this. It would be helpful to know how
    // complex the problems are that users are trying to solve.
    final String encodedTimelineData =
        jsonEncode(timelineController.timeline.data.json);
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

          final timelineProtocol =
              timelineController.frameBasedTimeline.processor;

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
