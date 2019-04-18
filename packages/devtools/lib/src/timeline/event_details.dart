// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:html' as html;

import 'package:vm_service_lib/vm_service_lib.dart' hide TimelineEvent;

import '../globals.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/primer.dart';
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

    add([tabNav, content]);
  }

  static const defaultTitleText = '[No event selected]';
  static const defaultTitleBackground = Color(0xFFF6F6F6);

  PTabNav tabNav;
  CoreElement content;
  CoreElement hideNativeCheckbox;

  TimelineEvent _event;
  CoreElement _title;
  _Details _details;

  void _initContent() {
    _title = div(text: defaultTitleText, c: 'event-details-heading')
      ..element.style.backgroundColor = colorToCss(defaultTitleBackground);
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

    tabNav.onTabSelected.listen((PTabNavTab tab) {
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
            ]))
          .element,
    ]);
  }

  Future<void> update(FrameFlameChartItem item) async {
    _event = item.event;

    _title.text = '${_event.name} - ${msText(_event.time.duration)}';
    _title.element.style
      ..backgroundColor = colorToCss(item.backgroundColor)
      ..color = colorToCss(_event.isGpuEvent ? Colors.white : Colors.black);

    await _details.update(item.event);
  }

  void reset() {
    _title.text = defaultTitleText;
    _title.element.style.color = colorToCss(Colors.black);
    _title.element.style.backgroundColor = colorToCss(defaultTitleBackground);
    _details.reset();

    final html.InputElement checkbox = hideNativeCheckbox.element;
    checkbox.checked = true;
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

    if (event.isUiEvent && showCpuFlameChart) {
      await uiEventDetails.update(event);
    }
  }

  void reset() {
    gpuEventDetails.attribute('hidden', true);
    uiEventDetails.attribute('hidden', true);
    if (showCpuFlameChart) {
      uiEventDetails.reset();
    }
  }
}

class _UiEventDetails extends CoreElement {
  _UiEventDetails() : super('div', classes: 'ui-details') {
    layoutVertical();
    flex();

    flameChart = div(c: 'ui-details-section');

    if (!showCpuFlameChart) {
      flameChart.add(div(text: 'CPU flame chart coming soon', c: 'message'));
    }

    add([
      flameChart,
      bottomUp = CpuBottomUp()..attribute('hidden', true),
      callTree = CpuCallTree()..attribute('hidden', true),
    ]);

    stackFrameDetails = div(c: 'event-details-heading stack-frame-details');
    if (showCpuFlameChart) {
      add(stackFrameDetails);
    }
  }

  static const String stackFrameDetailsDefaultText = '[No function selected]';

  CoreElement flameChart;
  CpuBottomUp bottomUp;
  CpuCallTree callTree;
  CoreElement stackFrameDetails;

  EventDetailsTabType selectedTab = EventDetailsTabType.flameChart;

  bool showingFlameChartError = false;

  TimelineEvent event;

  CpuProfileData cpuProfileData;

  void showTab(EventDetailsTabType tabType) {
    selectedTab = tabType;
    switch (tabType) {
      case EventDetailsTabType.flameChart:
        flameChart.attribute('hidden', false);
        stackFrameDetails.attribute('hidden', showingFlameChartError);
        bottomUp.attribute('hidden', true);
        callTree.attribute('hidden', true);
        break;
      case EventDetailsTabType.bottomUp:
        flameChart.attribute('hidden', true);
        stackFrameDetails.attribute('hidden', true);
        bottomUp.attribute('hidden', false);
        callTree.attribute('hidden', true);
        break;
      case EventDetailsTabType.callTree:
        flameChart.attribute('hidden', true);
        stackFrameDetails.attribute('hidden', true);
        bottomUp.attribute('hidden', true);
        callTree.attribute('hidden', false);
        break;
    }
  }

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
      _updateFlameChartForError(div(
        text: 'CPU profile unavailable for time range'
            ' [${event.time.start.inMicroseconds} - '
            '${event.time.end.inMicroseconds}]',
        c: 'message',
      ));
      return;
    }

    final flameChartCanvas = FlameChartCanvas(
      data: cpuProfileData,
      flameChartWidth: flameChart.element.clientWidth,
      flameChartHeight:
          cpuProfileData.cpuProfileRoot.depth * rowHeightWithPadding,
    );

    flameChartCanvas.onStackFrameSelected.listen((CpuStackFrame stackFrame) {
      _updateStackFrameDetails(stackFrame);
    });

    flameChart.add(flameChartCanvas.element);
  }

  void _updateFlameChartForError(CoreElement errorDiv) {
    flameChart.add(errorDiv);
    showingFlameChartError = true;
    stackFrameDetails.attribute('hidden', true);
  }

  Future<void> update(TimelineEvent event) async {
    if (event == this.event) {
      return;
    }

    reset();
    this.event = event;

    final Spinner spinner = Spinner()..clazz('cpu-profile-spinner');
    add(spinner);

    try {
      // TODO(kenzie): add a timeout here so we don't appear to have an
      // infinite spinner.
      await _drawFlameChart();
    } catch (e) {
      _updateFlameChartForError(div(
          text: 'Error retrieving CPU profile: ${e.toString()}', c: 'message'));
    }

    spinner.element.remove();

    stackFrameDetails.text = stackFrameDetailsDefaultText;
  }

  void reset() {
    flameChart.clear();
    stackFrameDetails.clear();
    showingFlameChartError = false;
    stackFrameDetails.attribute(
        'hidden', selectedTab != EventDetailsTabType.flameChart);
    cpuProfileData = null;
  }

  void _updateStackFrameDetails(CpuStackFrame stackFrame) {
    stackFrameDetails.text = stackFrame.toString();
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
