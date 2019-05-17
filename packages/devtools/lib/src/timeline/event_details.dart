// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:js/js.dart';
import 'package:vm_service_lib/vm_service_lib.dart' hide TimelineEvent;

import '../globals.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/primer.dart';
import '../ui/theme.dart';
import '../utils.dart';
import 'cpu_bottom_up.dart';
import 'cpu_call_tree.dart';
import 'cpu_profile_protocol.dart';
import 'flame_chart_canvas.dart';
import 'frame_flame_chart.dart';
import 'timeline.dart';
import 'timeline_controller.dart';
import 'timeline_protocol.dart';

/// StreamController that handles loading a CPU profile from snapshot.
final StreamController<TimelineSnapshot> _loadProfileSnapshotController =
    StreamController<TimelineSnapshot>.broadcast();

/// Stream for CPU profile snapshot loads.
Stream<TimelineSnapshot> get _onLoadProfileSnapshot =>
    _loadProfileSnapshotController.stream;

class EventDetails extends CoreElement {
  EventDetails() : super('div') {
    flex();
    layoutVertical();

    _initContent();

    assert(tabNav != null);
    assert(content != null);

    // The size of the event details section will change as the splitter is
    // is moved. Observe resizing so that we can rebuild the flame chart canvas
    // as necessary.
    // TODO(kenzie): clean this code up when
    // https://github.com/dart-lang/html/issues/104 is fixed.
    final observer =
        html.ResizeObserver(allowInterop((List<dynamic> entries, _) {
      _details.uiEventDetails.flameChart.updateForContainerResize();
    }));
    observer.observe(element);

    add([tabNav, content]);

    onLoadTimelineSnapshot.listen((snapshot) {
      clearCurrentSnapshot();
      if (snapshot.hasCpuProfile) {
        _loadProfileSnapshotController.add(snapshot);
      }
    });

    _onLoadProfileSnapshot.listen((snapshot) {
      attribute('hidden', false);
      _setTitleText(
        snapshot.selectedEvent.name,
        Duration(
            microseconds: snapshot.selectedEvent.time.duration.inMicroseconds),
      );
      _title.element.style
        ..backgroundColor = colorToCss(mainUiColor)
        ..color = colorToCss(Colors.black);
      _details.attribute('hidden', false);
      _details.gpuEventDetails.attribute('hidden', true);
      _details.uiEventDetails.attribute('hidden', false);

      _details.uiEventDetails.flameChart._loadFromSnapshot(snapshot);
    });
  }

  static const defaultTitleText = '[No event selected]';

  static const defaultTitleBackground = ThemedColor(
    Color(0xFFF6F6F6),
    Color(0xFF2D2E31), // Material Dark Grey 900+2
  );

  PTabNav tabNav;

  PTabNavTab _selectedTab;

  CoreElement content;

  TimelineEvent get event => _event;

  TimelineEvent _event;

  CoreElement _title;

  _Details _details;

  CpuProfileData get cpuProfileData =>
      _details.uiEventDetails.flameChart.cpuProfileData;

  void _initContent() {
    _title = div(text: defaultTitleText, c: 'event-details-heading');
    _title.element.style
      ..color = colorToCss(contrastForeground)
      ..backgroundColor = colorToCss(defaultTitleBackground);
    _details = _Details()..attribute('hidden');

    content = div(c: 'event-details-section section-border')
      ..flex()
      ..add(<CoreElement>[_title, _details]);

    _initTabNav();
  }

  void _initTabNav() {
    final flameChartTab = EventDetailsTabNavTab(
      'CPU Flame Chart (preview)',
      EventDetailsTabType.flameChart,
    );
    final bottomUpTab = EventDetailsTabNavTab(
      'Bottom Up',
      EventDetailsTabType.bottomUp,
    );
    final callTreeTab = EventDetailsTabNavTab(
      'Call Tree',
      EventDetailsTabType.callTree,
    );

    tabNav = PTabNav(<EventDetailsTabNavTab>[
      flameChartTab,
      bottomUpTab,
      callTreeTab,
    ])
      ..element.style.borderBottom = '0';

    _selectedTab = flameChartTab;

    tabNav.onTabSelected.listen((PTabNavTab tab) {
      // Return early if this tab is already selected.
      if (tab == _selectedTab) {
        return;
      }
      _selectedTab = tab;

      assert(tab is EventDetailsTabNavTab);
      switch ((tab as EventDetailsTabNavTab).type) {
        case EventDetailsTabType.flameChart:
          _details.uiEventDetails.showTab(EventDetailsTabType.flameChart);
          break;
        case EventDetailsTabType.bottomUp:
          _details.uiEventDetails.showTab(EventDetailsTabType.bottomUp);
          break;
        case EventDetailsTabType.callTree:
          _details.uiEventDetails.showTab(EventDetailsTabType.callTree);
          break;
      }
    });
  }

  void _setTitleText(String name, Duration duration) {
    _title.text = '$name - ${msText(duration)}';
  }

  Future<void> update(FrameFlameChartItem item) async {
    _event = item.event;

    _setTitleText(_event.name, _event.time.duration);
    _title.element.style
      ..backgroundColor = colorToCss(item.backgroundColor)
      ..color = colorToCss(item.defaultTextColor);

    await _details.update(item.event);
  }

  void reset() {
    _title.text = defaultTitleText;
    _title.element.style
      ..color = colorToCss(contrastForeground)
      ..backgroundColor = colorToCss(defaultTitleBackground);
    _details.reset();
  }

  void clearCurrentSnapshot() {
    _details.uiEventDetails.flameChart.snapshot = null;
  }
}

class _Details extends CoreElement {
  _Details() : super('div', classes: 'event-details') {
    layoutVertical();
    flex();

    uiEventDetails = _UiEventDetails()..attribute('hidden');

    // TODO(kenzie): eventually we should show something in this area that is
    // useful for GPU events as well (tips, links to docs, etc).
    gpuEventDetails = div(
      text: 'CPU profiling is not available for GPU events.',
      c: 'message',
    )..attribute('hidden');

    add(uiEventDetails);
    add(gpuEventDetails);
  }

  CoreElement gpuEventDetails;

  _UiEventDetails uiEventDetails;

  Future<void> update(TimelineEvent event) async {
    attribute('hidden', false);
    gpuEventDetails.attribute('hidden', event.isUiEvent);
    uiEventDetails.attribute('hidden', event.isGpuEvent);

    if (event.isUiEvent) {
      await uiEventDetails.update(event);
    }
  }

  void reset() {
    gpuEventDetails.attribute('hidden', true);
    uiEventDetails.attribute('hidden', true);
    uiEventDetails.reset();
  }
}

class _UiEventDetails extends CoreElement {
  _UiEventDetails() : super('div') {
    layoutVertical();
    flex();

    add([
      flameChart = _CpuFlameChart(),
      bottomUp = CpuBottomUp()..attribute('hidden', true),
      callTree = CpuCallTree()..attribute('hidden', true),
    ]);
  }

  _CpuFlameChart flameChart;

  CpuBottomUp bottomUp;

  CpuCallTree callTree;

  TimelineEvent event;

  void showTab(EventDetailsTabType tabType) {
    switch (tabType) {
      case EventDetailsTabType.flameChart:
        flameChart.show();
        bottomUp.attribute('hidden', true);
        callTree.attribute('hidden', true);
        break;
      case EventDetailsTabType.bottomUp:
        flameChart.attribute('hidden', true);
        bottomUp.attribute('hidden', false);
        callTree.attribute('hidden', true);
        break;
      case EventDetailsTabType.callTree:
        flameChart.attribute('hidden', true);
        bottomUp.attribute('hidden', true);
        callTree.attribute('hidden', false);
        break;
    }
  }

  Future<void> update(TimelineEvent event) async {
    if (event == this.event) {
      return;
    }
    reset();
    this.event = event;

    // TODO(kenzie): update call tree and bottom up views here once they are
    // implemented.
    await flameChart.update(event);
  }

  void reset() {
    // TODO(kenzie): reset call tree and bottom up views here once they are
    // implemented.
    flameChart.reset();
  }
}

class _CpuFlameChart extends CoreElement {
  _CpuFlameChart() : super('div', classes: 'ui-details-section') {
    stackFrameDetails = div(c: 'event-details-heading stack-frame-details')
      ..element.style.backgroundColor = colorToCss(stackFrameDetailsBackground)
      ..attribute('hidden', true);

    add(stackFrameDetails);
  }

  static const String stackFrameDetailsDefaultText =
      '[No stack frame selected]';

  static const stackFrameDetailsBackground = ThemedColor(
    Color(0xFFF6F6F6),
    Color(0xFF202124),
  );

  FlameChartCanvas canvas;

  CoreElement stackFrameDetails;

  CpuProfileData cpuProfileData;

  TimelineEvent event;

  /// Stores the latest timeline snapshot.
  ///
  /// This will be null if a cpu profile was not loaded from snapshot.
  TimelineSnapshot snapshot;

  bool canvasNeedsRebuild = false;

  bool showingMessage = false;

  Future<void> _getCpuProfile() async {
    final Response response =
        await serviceManager.service.getCpuProfileTimeline(
      serviceManager.isolateManager.selectedIsolate.id,
      event.time.start.inMicroseconds,
      event.time.duration.inMicroseconds,
    );

    cpuProfileData = CpuProfileData(
      response,
      event.time.duration,
    );
  }

  void _drawFlameChart() {
    if (cpuProfileData.stackFrames.isEmpty) {
      final snapshotModeMessage = div()
        ..add(span(
            text:
                'CPU profiling is not yet available for snapshots. You can only'
                ' view '));
      if (snapshot != null && snapshot.hasCpuProfile) {
        snapshotModeMessage
          ..add(span(text: 'the '))
          ..add(span(text: 'CPU profile', c: 'message-action')
            ..click(() => _loadProfileSnapshotController.add(snapshot)))
          ..add(span(text: ' included in the snapshot.'));
      } else {
        snapshotModeMessage.add(span(
            text:
                'a CPU profile if it is included in the imported snapshot file.'));
      }

      _updateChartWithMessage(snapshotMode
          ? snapshotModeMessage
          : div(
              text: 'CPU profile unavailable for time range'
                  ' [${event.time.start.inMicroseconds} -'
                  ' ${event.time.end.inMicroseconds}]'));
      return;
    }

    canvas = FlameChartCanvas(
      data: cpuProfileData,
      flameChartWidth: element.clientWidth,
      flameChartHeight: math.max(
        // Subtract [rowHeightWithPadding] to account for timeline at the top of
        // the flame chart.
        element.clientHeight - rowHeightWithPadding,
        // Add 1 to account for a row of padding at the bottom of the chart.
        (cpuProfileData.cpuProfileRoot.depth + 1) * rowHeightWithPadding,
      ),
    );

    canvas.onStackFrameSelected.listen((CpuStackFrame stackFrame) {
      final frameDuration = Duration(
          microseconds: (stackFrame.cpuConsumptionRatio *
                  event.time.duration.inMicroseconds)
              .round());
      stackFrameDetails.text = stackFrame.toString(duration: frameDuration);
    });

    add(canvas.element);

    if (!showingMessage) {
      stackFrameDetails
        ..text = stackFrameDetailsDefaultText
        ..attribute('hidden', false);
    }
  }

  void _updateChartWithMessage(CoreElement message) {
    showingMessage = true;
    add(message
      ..id = 'flame-chart-message'
      ..clazz('message'));
    stackFrameDetails.attribute('hidden', true);
  }

  Future<void> update(TimelineEvent event) async {
    reset();
    this.event = event;

    // Update the canvas if the flame chart is visible. Otherwise, mark the
    // canvas as needing a rebuild.
    if (!isHidden) {
      final Spinner spinner = Spinner()..clazz('cpu-profile-spinner');
      add(spinner);

      try {
        await _getCpuProfile();
        _drawFlameChart();
      } on AssertionError catch (e) {
        _updateChartWithMessage(div(text: e.toString()));
      } catch (e) {
        _updateChartWithMessage(
            div(text: 'Error retrieving CPU profile: ${e.toString()}'));
      }

      spinner.element.remove();
    } else {
      canvasNeedsRebuild = true;
    }
  }

  void updateForContainerResize() {
    if (canvas == null) {
      return;
    }

    // Only update the canvas if the flame chart is visible and has data.
    // Otherwise, mark the canvas as needing a rebuild.
    if (!isHidden && cpuProfileData != null) {
      // We need to rebuild the canvas with a new content size so that the
      // canvas is always at least as tall as the container it is in. This
      // ensures that the grid lines in the chart will extend all the way to the
      // bottom of the container.
      canvas.forceRebuildForSize(
        canvas.flameChartWidthWithInsets,
        math.max(
          // Subtract [rowHeightWithPadding] to account for the size of
          // [stackFrameDetails] section at the bottom of the chart.
          element.scrollHeight.toDouble() - rowHeightWithPadding,
          // Add 1 to account for a row of padding at the bottom of the chart.
          (cpuProfileData.cpuProfileRoot.depth + 1) * rowHeightWithPadding,
        ),
      );
    } else {
      canvasNeedsRebuild = true;
    }
  }

  Future<void> show() async {
    attribute('hidden', false);

    if (canvasNeedsRebuild) {
      assert(event != null);
      canvasNeedsRebuild = false;
      await update(event);
    }
  }

  void reset() {
    if (canvas?.element?.element != null) {
      canvas.element.element.remove();
    }
    canvas = null;

    stackFrameDetails.text = stackFrameDetailsDefaultText;
    stackFrameDetails.attribute('hidden', true);

    _removeMessage();

    cpuProfileData = null;
  }

  void _removeMessage() {
    element.children.removeWhere((e) => e.id == 'flame-chart-message');
    showingMessage = false;
  }

  void _loadFromSnapshot(TimelineSnapshot snapshot) {
    _removeMessage();
    this.snapshot = snapshot;
    event = snapshot.selectedEvent;
    cpuProfileData = CpuProfileData(
      Response.parse(snapshot.cpuProfile),
      Duration(
          microseconds: snapshot.selectedEvent.time.duration.inMicroseconds),
    );
    _drawFlameChart();
  }
}

enum EventDetailsTabType {
  flameChart,
  bottomUp,
  callTree,
}

class EventDetailsTabNavTab extends PTabNavTab {
  EventDetailsTabNavTab(String name, this.type) : super(name);

  final EventDetailsTabType type;
}
