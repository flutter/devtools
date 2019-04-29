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
import 'timeline_protocol.dart';

final _collapseNativeSamplesController = StreamController<bool>.broadcast();

Stream<bool> get onCollapseNativeSamplesEvent =>
    _collapseNativeSamplesController.stream;

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
    // https://github.com/dart-lang/html/issues/102 is fixed.
    final observer =
        html.ResizeObserver(allowInterop((List<dynamic> entries, _) {
      _details.uiEventDetails.flameChart.updateForContainerResize();
    }));
    observer.observe(element);

    add([tabNav, content]);
  }

  static const defaultTitleText = '[No event selected]';

  static const defaultTitleBackground = ThemedColor(
    Color(0xFFF6F6F6),
    Color(0xFF2D2E31), // Material Dark Grey 900+2
  );

  PTabNav tabNav;

  PTabNavTab _selectedTab;

  CoreElement content;

  CoreElement hideNativeCheckbox;

  TimelineEvent _event;

  CoreElement _title;

  _Details _details;

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

    // Add hide native checkbox to tab nav.
    hideNativeCheckbox =
        CoreElement('input', classes: 'collapse-native-checkbox')
          ..setAttribute('type', 'checkbox');

    final html.InputElement checkbox = hideNativeCheckbox.element;
    checkbox
      ..checked = true
      ..onChange.listen(
          (_) => _collapseNativeSamplesController.add(checkbox.checked));

    // Add checkbox and label to tab bar.
    tabNav.element.children.first.children.addAll([
      (div(c: 'collapse-native-container')
            ..flex()
            ..add([
              hideNativeCheckbox,
              CoreElement('div', text: 'Collapse native samples')
                ..element.style.color = colorToCss(contrastForeground),
            ]))
          .element,
    ]);
  }

  Future<void> update(FrameFlameChartItem item) async {
    _event = item.event;

    _title.text = '${_event.name} - ${msText(_event.time.duration)}';
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
    error = div(c: 'message')..attribute('hidden', true);
    stackFrameDetails = div(c: 'event-details-heading stack-frame-details')
      ..element.style.backgroundColor = colorToCss(stackFrameDetailsBackground)
      ..attribute('hidden', true);

    add([stackFrameDetails, error]);

    onCollapseNativeSamplesEvent
        .listen((value) => lastCollapseNativeSamplesValue = value);
  }

  static const String stackFrameDetailsDefaultText =
      '[No stack frame selected]';

  static const stackFrameDetailsBackground = ThemedColor(
    Color(0xFFF6F6F6),
    Color(0xFF202124),
  );

  FlameChartCanvas canvas;

  CoreElement stackFrameDetails;

  CoreElement error;

  CpuProfileData cpuProfileData;

  TimelineEvent event;

  bool canvasNeedsRebuild = false;

  bool lastCollapseNativeSamplesValue = true;

  bool showingError = false;

  Future<void> _drawFlameChart() async {
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

    if (cpuProfileData.stackFrames.isEmpty) {
      _updateChartWithError('CPU profile unavailable for time range'
          ' [${event.time.start.inMicroseconds} - '
          '${event.time.end.inMicroseconds}]');
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

    // Add the last known value to the stream so that the canvas reflects the
    // persisted checkbox state.
    _collapseNativeSamplesController.add(lastCollapseNativeSamplesValue);

    canvas.onStackFrameSelected.listen((CpuStackFrame stackFrame) {
      stackFrameDetails.text = stackFrame.toString();
    });

    add(canvas.element);
  }

  void _updateChartWithError(String message) {
    showingError = true;
    error.text = message;
    error.attribute('hidden', false);
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
        await _drawFlameChart();

        if (!showingError) {
          stackFrameDetails.text = stackFrameDetailsDefaultText;
          stackFrameDetails.attribute('hidden', false);
        }
      } catch (e) {
        _updateChartWithError('Error retrieving CPU profile: ${e.toString()}');
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

    error.clear();
    error.attribute('hidden', true);
    showingError = false;

    cpuProfileData = null;
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
