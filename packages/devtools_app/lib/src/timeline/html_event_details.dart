// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:convert';

import 'package:html_shim/html.dart' as html;

import '../globals.dart';
import '../profiler/html_cpu_profile_flame_chart.dart';
import '../profiler/html_cpu_profile_tables.dart';
import '../profiler/html_cpu_profiler.dart';
import '../ui/colors.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/html_elements.dart';
import '../ui/primer.dart';
import '../ui/theme.dart';
import '../utils.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';

class HtmlEventDetails extends CoreElement {
  HtmlEventDetails(this._timelineController) : super('div') {
    flex();
    layoutVertical();

    _initContent();
    _initListeners();

    // The size of the event details section will change as the splitter is
    // is moved. Observe resizing so that we can rebuild the flame chart canvas
    // as necessary.
    // TODO(jacobr): Change argument type when
    // https://github.com/dart-lang/sdk/issues/36798 is fixed.
    final observer = html.ResizeObserver((List<dynamic> entries, _) {
      _cpuProfiler.flameChart.updateForContainerResize();
    });
    observer.observe(element);

    assert(_cpuProfilerTabNav != null && _summaryTabNav != null);
    assert(_content != null);

    add([_cpuProfilerTabNav.element, _summaryTabNav, _content]);
  }

  static const _defaultTitleText = '[No event selected]';

  static const _defaultTitleBackground = ThemedColor(
    Color(0xFFF6F6F6),
    Color(0xFF2D2E31), // Material Dark Grey 900+2
  );

  final TimelineController _timelineController;

  HtmlCpuProfilerTabNav _cpuProfilerTabNav;

  /// Summary tab nav to show when [_eventSummary] is visible.
  ///
  /// This tab nav will only contain one tab, "Summary", but we add the tab nav
  /// so our UI looks consistent between UI events and non-UI events.
  PTabNav _summaryTabNav;

  CoreElement _content;

  CoreElement _title;

  _CpuProfiler _cpuProfiler;

  // TODO(kenz): Eventually, we should add a summary tab for UI events, as well,
  // but we can wait to do this until we port this UI to flutter.
  /// Event summary to show for non-UI events.
  HtmlEventSummary _eventSummary;

  Color titleBackgroundColor = _defaultTitleBackground;

  Color titleTextColor = contrastForeground;

  void _initContent() {
    _title = div(text: _defaultTitleText, c: 'event-details-heading');
    _title.element.style
      ..color = colorToCss(titleTextColor)
      ..backgroundColor = colorToCss(titleBackgroundColor);

    _cpuProfiler = _CpuProfiler(
      _timelineController,
      () => _timelineController.timeline.data?.cpuProfileData,
    )..hidden(true);

    _cpuProfilerTabNav = HtmlCpuProfilerTabNav(
      _cpuProfiler,
      CpuProfilerTabOrder(
        first: CpuProfilerViewType.flameChart,
        second: CpuProfilerViewType.callTree,
        third: CpuProfilerViewType.bottomUp,
      ),
    );

    _summaryTabNav = PTabNav([PTabNavTab('Summary')])
      ..element.style.borderBottom = '0'
      ..hidden(true);

    final details = div(c: 'event-details')
      ..layoutVertical()
      ..flex()
      ..add([
        _cpuProfiler,
        // TODO(kenz): eventually we should show something in this area that
        // is useful for GPU events as well (tips, links to docs, etc).
        _eventSummary = HtmlEventSummary(
            () => _timelineController.timeline.data.selectedEvent)
          ..hidden(true),
      ]);

    _content = div(c: 'event-details-section section-border')
      ..flex()
      ..add(<CoreElement>[_title, details]);
  }

  void _initListeners() {
    _timelineController.frameBasedTimeline.onSelectedFrame
        .listen((_) => reset());

    _timelineController.onSelectedTimelineEvent
        .listen((_) async => await _update());

    _timelineController.onLoadOfflineData.listen((_) async {
      // If there is no selected event, there is no reason to show the event
      // details section.
      if (_timelineController.offlineTimelineData.selectedEvent != null) {
        final selectedEvent =
            _timelineController.offlineTimelineData.selectedEvent;
        titleBackgroundColor = _backgroundColorForEvent(selectedEvent);
        titleTextColor = Colors.black;
        await _update();
      }
    });
  }

  Future<void> _update({bool hide = false}) async {
    final selectedEvent = _timelineController.timeline.data?.selectedEvent;

    _title.text = selectedEvent != null
        ? '${selectedEvent.name} - ${msText(selectedEvent.time.duration)}'
        : _defaultTitleText;
    _title.element.style
      ..backgroundColor = colorToCss(titleBackgroundColor)
      ..color = colorToCss(titleTextColor);

    hidden(hide);

    final showEventSummary = selectedEvent != null && !selectedEvent.isUiEvent;
    _summaryTabNav.hidden(!showEventSummary);
    _eventSummary.hidden(!showEventSummary);
    if (showEventSummary) {
      _eventSummary.update();
    }

    final showCpuProfiler = selectedEvent?.isUiEvent ?? false;
    _cpuProfiler.hidden(!showCpuProfiler);
    _cpuProfilerTabNav.element.hidden(!showCpuProfiler);
    if (showCpuProfiler) {
      await _cpuProfiler.update();
    }
  }

  void reset({bool hide = false}) {
    titleTextColor = contrastForeground;
    titleBackgroundColor = _defaultTitleBackground;
    _update(hide: hide);
  }

  Color _backgroundColorForEvent(TimelineEvent event) {
    if (event.isAsyncEvent) {
      return mainAsyncColor;
    } else if (event.isUiEvent) {
      return mainUiColor;
    } else if (event.isGpuEvent) {
      return mainGpuColor;
    } else {
      return _defaultTitleBackground;
    }
  }
}

class _CpuProfiler extends HtmlCpuProfiler {
  _CpuProfiler(
    this._timelineController,
    CpuProfileDataProvider profileDataProvider,
  ) : super(
          HtmlCpuFlameChart(profileDataProvider),
          HtmlCpuCallTree(profileDataProvider),
          HtmlCpuBottomUp(profileDataProvider),
        );

  final TimelineController _timelineController;

  @override
  Future<void> prepareCpuProfile() async {
    // Fetch a profile if we are not loading from offline.
    if (!offlineMode || _timelineController.offlineTimelineData == null) {
      await _timelineController.getCpuProfileForSelectedEvent();
    }
  }

  @override
  bool maybeShowMessageOnUpdate() {
    if (offlineMode &&
        !collectionEquals(_timelineController.timeline.data.selectedEvent.json,
            _timelineController.offlineTimelineData?.selectedEvent?.json)) {
      final offlineModeMessage = div()
        ..add(span(
            text:
                'CPU profiling is not yet available for snapshots. You can only'
                ' view '));
      if (_timelineController.offlineTimelineData.hasCpuProfileData()) {
        offlineModeMessage
          ..add(span(text: 'the '))
          ..add(span(text: 'CPU profile', c: 'message-action')
            ..click(() {
              // TODO(kenz): ensure event details title style is restored.
              _timelineController.setOfflineData();
            }))
          ..add(span(text: ' included in the snapshot.'));
      } else {
        offlineModeMessage.add(span(
            text:
                'a CPU profile if it is included in the imported snapshot file.'));
      }
      showMessage(offlineModeMessage);
      return true;
    }

    final cpuProfileData = _timelineController.timeline.data?.cpuProfileData;
    if (cpuProfileData != null && cpuProfileData.stackFrames.isEmpty) {
      final offset = _timelineController.timelineMode == TimelineMode.frameBased
          ? _timelineController.frameBasedTimeline.data.selectedFrame.time.start
          : _timelineController
              .fullTimeline.data.timelineEvents.first.time.start;
      final startTime =
          _timelineController.timeline.data.selectedEvent.time.start - offset;
      final endTime =
          _timelineController.timeline.data.selectedEvent.time.end - offset;

      showMessage(div(
          text: 'CPU profile unavailable for time range'
              ' [${msText(startTime, fractionDigits: 2)} -'
              ' ${msText(endTime, fractionDigits: 2)}]'));
      return true;
    }
    return false;
  }
}

typedef SelectedEventProvider = TimelineEvent Function();

class HtmlEventSummary extends CoreElement {
  HtmlEventSummary(this.selectedEventProvider)
      : super('div', classes: 'event-summary') {
    layoutVertical();
    add([
      category = div(c: 'event-summary-section')..layoutHorizontal(),
      thread = div(c: 'event-summary-section')..layoutHorizontal(),
      process = div(c: 'event-summary-section')..layoutHorizontal(),
      connectedEvents = div(c: 'event-summary-section')
        ..layoutVertical()
        ..hidden(true),
      args = div(c: 'event-summary-section')
        ..layoutVertical()
        ..hidden(true),
    ]);
  }

  final SelectedEventProvider selectedEventProvider;

  CoreElement category;

  CoreElement thread;

  CoreElement process;

  CoreElement args;

  CoreElement connectedEvents;

  void update() {
    final event = selectedEventProvider();
    if (event == null) return;

    reset();

    final firstTraceEvent = event.traceEvents.first.event;
    category.add(
        [span(text: 'Category: '), div(text: '${firstTraceEvent.category}')]);
    thread.add(
        [span(text: 'Thread id: '), div(text: '${firstTraceEvent.threadId}')]);
    process.add([
      span(text: 'Process id: '),
      div(text: '${firstTraceEvent.processId}')
    ]);

    final asyncInstantEvents = event.isAsyncEvent
        ? [
            ...event.children.where((e) =>
                e.traceEvents.first.event.phase == TraceEvent.asyncInstantPhase)
          ]
        : [];
    if (asyncInstantEvents.isNotEmpty) {
      // TODO(kenz): eventually show flow events here as well.
      connectedEvents
        ..add([
          span(text: 'Connected events: '),
          for (var e in asyncInstantEvents)
            div(
                text: '${e.name} - {'
                    'startTime: ${msText(e.time.start - event.time.start)}, '
                    'args: ${e.traceEvents.first.event.args}}')
        ])
        ..hidden(false);
    }

    // Merge args from all trace events.
    final eventArgs = Map.from(firstTraceEvent.args)
      ..addAll({for (var trace in event.traceEvents) ...trace.event.args});
    if (eventArgs.isNotEmpty) {
      const encoder = JsonEncoder.withIndent('  ');
      final formattedArgs = encoder.convert(eventArgs);
      args
        ..add([
          span(text: 'Arguments: '),
          div(text: formattedArgs, c: 'event-args'),
        ])
        ..hidden(false);
    }
  }

  void reset() {
    category.clear();
    thread.clear();
    process.clear();
    connectedEvents.clear();
    args.clear();
  }
}
