// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:html';

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
import 'cpu_flame_chart.dart';
import 'cpu_profile_protocol.dart';
import 'frame_flame_chart.dart';
import 'timeline_protocol.dart';

// TODO(kenzie): this should be removed once the cpu flame chart is optimized.
const bool showCpuFlameChart = false;

class EventDetails extends CoreElement {
  EventDetails() : super('div') {
    flex();
    layoutVertical();

    _title = div(text: defaultTitleText, c: 'event-details-heading')
      ..element.style.backgroundColor = colorToCss(defaultTitleBackground);
    _details = _Details()..attribute('hidden');

    final flameChartTab = EventDetailsTabNavTab(
      'CPU Flame Chart',
      () => _details.uiEventDetails.showTab(EventDetailsTabType.flameChart),
    );
    final bottomUpTab = EventDetailsTabNavTab(
      'Bottom Up',
      () => _details.uiEventDetails.showTab(EventDetailsTabType.bottomUp),
    );
    final callTreeTab = EventDetailsTabNavTab(
      'Call Tree',
      () => _details.uiEventDetails.showTab(EventDetailsTabType.callTree),
    );

    tabNav = EventDetailsTabNav(<EventDetailsTabNavTab>[
      flameChartTab,
      bottomUpTab,
      callTreeTab,
    ])
      ..element.style.borderBottom = '0';

    content = div(c: 'event-details-section section-border')..flex();
    content.add(<CoreElement>[_title, _details]);

    add(tabNav);
    add(content);
  }

  static const defaultTitleText = '[No event selected]';
  static const defaultTitleBackground = Color(0xFFF6F6F6);

  PTabNav tabNav;
  CoreElement content;

  TimelineEvent _event;
  CoreElement _title;
  _Details _details;

  Future<void> update(FrameFlameChartItem item) async {
    _event = item.event;

    _title.text =
        '${_event.name} - ${msText(Duration(microseconds: _event.duration))}';
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

    if (showCpuFlameChart) {
      flameChart = CpuFlameChart();
    } else {
      flameChart = div(c: 'ui-details-section');
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

    onSelectedCpuFlameChartItem.listen(updateStackFrameDetails);
  }

  static const String stackFrameDetailsDefaultText = '[No function selected]';

  CoreElement flameChart;
  CpuBottomUp bottomUp;
  CpuCallTree callTree;
  CoreElement stackFrameDetails;

  TimelineEvent event;

  CpuProfileData cpuProfileData;

  void showTab(EventDetailsTabType tabType) {
    switch (tabType) {
      case EventDetailsTabType.flameChart:
        flameChart.attribute('hidden', false);
        stackFrameDetails.attribute('hidden', false);
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

  Future<void> update(TimelineEvent event) async {
    if (event == this.event) {
      return;
    }

    reset();
    this.event = event;

    final Spinner spinner = Spinner()..clazz('cpu-profile-spinner');
    add(spinner);

    final Response response =
        await serviceManager.service.getCpuProfileTimeline(
      serviceManager.isolateManager.selectedIsolate.id,
      event.startTime,
      event.duration,
    );

    cpuProfileData = CpuProfileData(response);

    if (showCpuFlameChart) {
      (flameChart as CpuFlameChart).update(cpuProfileData);
    }

    spinner.element.remove();

    stackFrameDetails.text = stackFrameDetailsDefaultText;
  }

  void reset() {
    flameChart.clear();
    stackFrameDetails.clear();
    cpuProfileData = null;
  }

  void updateStackFrameDetails(CpuFlameChartItem item) {
    stackFrameDetails.text = item.stackFrame.toString();
  }
}

enum EventDetailsTabType {
  flameChart,
  bottomUp,
  callTree,
}

class EventDetailsTabNav extends PTabNav {
  EventDetailsTabNav(List<EventDetailsTabNavTab> tabs) : super(tabs);

  @override
  void selectTab(PTabNavTab tab) {
    assert(tab is EventDetailsTabNavTab);
    super.selectTab(tab);
    tab.onTabSelected();
  }
}

class EventDetailsTabNavTab extends PTabNavTab {
  EventDetailsTabNavTab(String name, VoidCallback onTabSelected)
      : super(name, onTabSelected: onTabSelected);
}
