// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:html' as html;

import 'package:js/js.dart';

import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/primer.dart';
import '../ui/theme.dart';
import '../utils.dart';
import 'cpu_bottom_up.dart';
import 'cpu_call_tree.dart';
import 'cpu_flame_chart.dart';
import 'frame_events_chart.dart';
import 'timeline_controller.dart';
import 'timeline_screen.dart';

class EventDetails extends CoreElement {
  EventDetails(this.timelineController) : super('div') {
    flex();
    layoutVertical();

    _initContent();
    _initListeners();

    // The size of the event details section will change as the splitter is
    // is moved. Observe resizing so that we can rebuild the flame chart canvas
    // as necessary.
    // TODO(kenzie): clean this code up when
    // https://github.com/dart-lang/html/issues/104 is fixed.
    final observer =
        html.ResizeObserver(allowInterop((List<dynamic> entries, _) {
      uiEventDetails.flameChart.updateForContainerResize();
    }));
    observer.observe(element);

    assert(tabNav != null);
    assert(content != null);

    add([tabNav, content]);
  }

  static const defaultTitleText = '[No event selected]';

  static const defaultTitleBackground = ThemedColor(
    Color(0xFFF6F6F6),
    Color(0xFF2D2E31), // Material Dark Grey 900+2
  );

  final TimelineController timelineController;

  PTabNav tabNav;

  PTabNavTab _selectedTab;

  CoreElement content;

  CoreElement _title;

  _UiEventDetails uiEventDetails;

  CoreElement gpuEventDetails;

  Color titleBackgroundColor = defaultTitleBackground;

  Color titleTextColor = contrastForeground;

  void _initContent() {
    _title = div(text: defaultTitleText, c: 'event-details-heading');
    _title.element.style
      ..color = colorToCss(titleTextColor)
      ..backgroundColor = colorToCss(titleBackgroundColor);

    final details = div(c: 'event-details')
      ..layoutVertical()
      ..flex()
      ..add([
        uiEventDetails = _UiEventDetails(timelineController)
          ..attribute('hidden'),
        // TODO(kenzie): eventually we should show something in this area that
        // is useful for GPU events as well (tips, links to docs, etc).
        gpuEventDetails = div(
          text: 'CPU profiling is not available for GPU events.',
          c: 'message',
        )..attribute('hidden'),
      ]);

    content = div(c: 'event-details-section section-border')
      ..flex()
      ..add(<CoreElement>[_title, details]);

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

    tabNav.onTabSelected.listen((PTabNavTab tab) async {
      // Return early if this tab is already selected.
      if (tab == _selectedTab) {
        return;
      }
      _selectedTab = tab;

      assert(tab is EventDetailsTabNavTab);
      switch ((tab as EventDetailsTabNavTab).type) {
        case EventDetailsTabType.flameChart:
          await uiEventDetails.showTab(EventDetailsTabType.flameChart);
          break;
        case EventDetailsTabType.bottomUp:
          await uiEventDetails.showTab(EventDetailsTabType.bottomUp);
          break;
        case EventDetailsTabType.callTree:
          await uiEventDetails.showTab(EventDetailsTabType.callTree);
          break;
      }
    });
  }

  void _initListeners() {
    timelineController.onSelectedFrame.listen((_) => reset());

    onSelectedFrameFlameChartItem.listen((item) async {
      titleBackgroundColor = item.backgroundColor;
      titleTextColor = item.defaultTextColor;
    });

    timelineController.onSelectedTimelineEvent
        .listen((_) async => await update());

    timelineController.onLoadOfflineData.listen((_) async {
      if (timelineController.timelineData.selectedEvent != null) {
        titleTextColor = Colors.black;
        titleBackgroundColor = mainUiColor;
        await update();
      }
    });
  }

  Future<void> update({bool hide = false}) async {
    final selectedEvent = timelineController.timelineData.selectedEvent;

    _title.text = selectedEvent != null
        ? '${selectedEvent.name} - ${msText(selectedEvent.time.duration)}'
        : defaultTitleText;
    _title.element.style
      ..backgroundColor = colorToCss(titleBackgroundColor)
      ..color = colorToCss(titleTextColor);

    attribute('hidden', hide);
    gpuEventDetails.attribute('hidden', selectedEvent?.isUiEvent ?? true);
    uiEventDetails.attribute('hidden', selectedEvent?.isGpuEvent ?? true);

    if (selectedEvent != null && selectedEvent.isUiEvent) {
      await uiEventDetails.update();
    }
  }

  void reset({bool hide = false}) {
    titleTextColor = contrastForeground;
    titleBackgroundColor = defaultTitleBackground;
    update(hide: hide);
  }
}

class _UiEventDetails extends CoreElement {
  _UiEventDetails(TimelineController timelineController) : super('div') {
    layoutVertical();
    flex();

    add([
      flameChart = CpuFlameChart(timelineController),
      bottomUp = CpuBottomUp()..attribute('hidden', true),
      callTree = CpuCallTree()..attribute('hidden', true),
    ]);
  }

  CpuFlameChart flameChart;

  CpuBottomUp bottomUp;

  CpuCallTree callTree;

  Future<void> showTab(EventDetailsTabType tabType) async {
    switch (tabType) {
      case EventDetailsTabType.flameChart:
        await flameChart.show();
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

  Future<void> update() async {
    reset();
    // TODO(kenzie): update call tree and bottom up views here once they are
    // implemented.
    await flameChart.update();
  }

  void reset() {
    // TODO(kenzie): reset call tree and bottom up views here once they are
    // implemented.
    flameChart.reset();
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
