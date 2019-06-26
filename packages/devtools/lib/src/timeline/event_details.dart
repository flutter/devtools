// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:html' as html;

import 'package:js/js.dart';

import '../globals.dart';
import '../ui/colors.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/primer.dart';
import '../ui/theme.dart';
import '../utils.dart';
import 'cpu_profile_flame_chart.dart';
import 'cpu_profile_tables.dart';
import 'cpu_profiler_view.dart';
import 'frame_events_chart.dart';
import 'timeline_controller.dart';

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
      cpuProfiler.flameChart.updateForContainerResize();
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

  _CpuProfiler cpuProfiler;

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
        cpuProfiler = _CpuProfiler(timelineController)..hidden(true),
        // TODO(kenzie): eventually we should show something in this area that
        // is useful for GPU events as well (tips, links to docs, etc).
        gpuEventDetails = div(
          text: 'CPU profiling is not available for GPU events.',
          c: 'message',
        )..hidden(true),
      ]);

    content = div(c: 'event-details-section section-border')
      ..flex()
      ..add(<CoreElement>[_title, details]);

    _initTabNav();
  }

  void _initTabNav() {
    final flameChartTab = CpuProfilerTab(
      'CPU Flame Chart',
      CpuProfilerViewType.flameChart,
    );
    final callTreeTab = CpuProfilerTab(
      'Call Tree',
      CpuProfilerViewType.callTree,
    );
    final bottomUpTab = CpuProfilerTab(
      'Bottom Up',
      CpuProfilerViewType.bottomUp,
    );

    tabNav = PTabNav(<CpuProfilerTab>[
      flameChartTab,
      callTreeTab,
      bottomUpTab,
    ])
      ..element.style.borderBottom = '0';

    _selectedTab = flameChartTab;

    tabNav.onTabSelected.listen((PTabNavTab tab) {
      // Return early if this tab is already selected.
      if (tab == _selectedTab) {
        return;
      }
      _selectedTab = tab;
      cpuProfiler.showView((tab as CpuProfilerTab).type);
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
    final selectedEvent = timelineController.timelineData?.selectedEvent;

    _title.text = selectedEvent != null
        ? '${selectedEvent.name} - ${msText(selectedEvent.time.duration)}'
        : defaultTitleText;
    _title.element.style
      ..backgroundColor = colorToCss(titleBackgroundColor)
      ..color = colorToCss(titleTextColor);

    hidden(hide);
    gpuEventDetails.hidden(selectedEvent?.isUiEvent ?? true);
    cpuProfiler.hidden(selectedEvent?.isGpuEvent ?? true);

    if (selectedEvent != null && selectedEvent.isUiEvent) {
      await cpuProfiler.update();
    }
  }

  void reset({bool hide = false}) {
    titleTextColor = contrastForeground;
    titleBackgroundColor = defaultTitleBackground;
    update(hide: hide);
  }
}

class _CpuProfiler extends CoreElement {
  _CpuProfiler(this._timelineController) : super('div') {
    layoutVertical();
    flex();

    add(views = [
      flameChart = CpuFlameChart(_timelineController),
      bottomUp = CpuBottomUp(_timelineController)..hide(),
      callTree = CpuCallTree(_timelineController)..hide(),
    ]);
  }

  final TimelineController _timelineController;

  CpuFlameChart flameChart;

  CpuBottomUp bottomUp;

  CpuCallTree callTree;

  List<CpuProfilerView> views;

  CpuProfilerViewType _selectedViewType = CpuProfilerViewType.flameChart;

  bool showingMessage = false;

  void showView(CpuProfilerViewType showType) {
    _selectedViewType = showType;

    // If we are showing a message, we do not want to show any other views.
    if (showingMessage) return;

    for (CpuProfilerView view in views) {
      if (view.type == showType) {
        view.show();
      } else {
        view.hide();
      }
    }
  }

  void hideAll() {
    for (CpuProfilerView view in views) {
      view.hide();
    }
  }

  Future<void> update() async {
    reset();

    final Spinner spinner = Spinner.centered();
    try {
      add(spinner);

      // Only fetch a profile when we are not loading from offline.
      if (!offlineMode || _timelineController.offlineTimelineData == null) {
        await _timelineController.getCpuProfileForSelectedEvent();
      }

      if (offlineMode &&
          _timelineController.timelineData.selectedEvent !=
              _timelineController.offlineTimelineData?.selectedEvent) {
        final offlineModeMessage = div()
          ..add(span(
              text:
                  'CPU profiling is not yet available for snapshots. You can only'
                  ' view '));
        if (_timelineController.offlineTimelineData?.cpuProfileData != null) {
          offlineModeMessage
            ..add(span(text: 'the '))
            ..add(span(text: 'CPU profile', c: 'message-action')
              ..click(
                  () => _timelineController.restoreCpuProfileFromOfflineData()))
            ..add(span(text: ' included in the snapshot.'));
        } else {
          offlineModeMessage.add(span(
              text:
                  'a CPU profile if it is included in the imported snapshot file.'));
        }
        _updateDetailsWithMessage(offlineModeMessage);
        return;
      }

      if (_timelineController.timelineData.cpuProfileData.stackFrames.isEmpty) {
        _updateDetailsWithMessage(div(
            text: 'CPU profile unavailable for time range'
                ' [${_timelineController.timelineData.selectedEvent.time.start.inMicroseconds} -'
                ' ${_timelineController.timelineData.selectedEvent.time.end.inMicroseconds}]'));
        return;
      }

      flameChart.update();
      callTree.update();
      bottomUp.update();

      // Ensure we are showing the selected profiler view.
      showView(_selectedViewType);
    } catch (e) {
      _updateDetailsWithMessage(
          div(text: 'Error retrieving CPU profile: ${e.toString()}'));
    } finally {
      spinner.remove();
    }
  }

  void reset() {
    flameChart.reset();
    _removeMessage();
  }

  void _updateDetailsWithMessage(CoreElement message) {
    hideAll();
    showingMessage = true;
    add(message
      ..id = 'cpu-profiler-message'
      ..clazz('message'));
  }

  void _removeMessage() {
    element.children.removeWhere((e) => e.id == 'cpu-profiler-message');
    showingMessage = false;
  }
}

class CpuProfilerTab extends PTabNavTab {
  CpuProfilerTab(String name, this.type) : super(name);

  final CpuProfilerViewType type;
}
