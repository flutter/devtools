// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:math' as math;

import '../globals.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/theme.dart';
import 'flame_chart_canvas.dart';
import 'timeline_controller.dart';

class CpuFlameChart extends CoreElement {
  CpuFlameChart(this.timelineController)
      : super('div', classes: 'ui-details-section') {
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

  final TimelineController timelineController;

  FlameChartCanvas canvas;

  CoreElement stackFrameDetails;

  bool canvasNeedsRebuild = false;

  bool showingMessage = false;

  void _drawFlameChart() {
    if (offlineMode &&
        timelineController.timelineData.selectedEvent !=
            timelineController.offlineTimelineData?.selectedEvent) {
      final offlineModeMessage = div()
        ..add(span(
            text:
                'CPU profiling is not yet available for snapshots. You can only'
                ' view '));
      if (timelineController.offlineTimelineData?.cpuProfileData != null) {
        offlineModeMessage
          ..add(span(text: 'the '))
          ..add(span(text: 'CPU profile', c: 'message-action')
            ..click(
                () => timelineController.restoreCpuProfileFromOfflineData()))
          ..add(span(text: ' included in the snapshot.'));
      } else {
        offlineModeMessage.add(span(
            text:
                'a CPU profile if it is included in the imported snapshot file.'));
      }
      _updateChartWithMessage(offlineModeMessage);
      return;
    }

    if (timelineController.timelineData.cpuProfileData.stackFrames.isEmpty) {
      _updateChartWithMessage(div(
          text: 'CPU profile unavailable for time range'
              ' [${timelineController.timelineData.selectedEvent.time.start.inMicroseconds} -'
              ' ${timelineController.timelineData.selectedEvent.time.end.inMicroseconds}]'));
      return;
    }

    canvas = FlameChartCanvas(
      data: timelineController.timelineData.cpuProfileData,
      flameChartWidth: element.clientWidth,
      flameChartHeight: math.max(
        // Subtract [rowHeightWithPadding] to account for timeline at the top of
        // the flame chart.
        element.clientHeight - rowHeightWithPadding,
        // Add 1 to account for a row of padding at the bottom of the chart.
        (timelineController.timelineData.cpuProfileData.cpuProfileRoot.depth +
                1) *
            rowHeightWithPadding,
      ),
    );

    canvas.onStackFrameSelected.listen((stackFrame) {
      final frameDuration = Duration(
          microseconds: (stackFrame.cpuConsumptionRatio *
                  timelineController
                      .timelineData.selectedEvent.time.duration.inMicroseconds)
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

  Future<void> update() async {
    reset();

    // If we are loading offline data, draw the flame chart without attempting
    // to fetch a profile.
    if (offlineMode && timelineController.offlineTimelineData != null) {
      _drawFlameChart();
      return;
    }

    // Update the canvas if the flame chart is visible. Otherwise, mark the
    // canvas as needing a rebuild.
    if (!isHidden) {
      final Spinner spinner = Spinner(classes: ['cpu-profile-spinner']);
      add(spinner);

      try {
        await timelineController.fetchCpuProfileForSelectedEvent();
        _drawFlameChart();
      } catch (e) {
        _updateChartWithMessage(
            div(text: 'Error retrieving CPU profile: ${e.toString()}'));
      }

      spinner.remove();
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
    if (!isHidden && timelineController.timelineData.cpuProfileData != null) {
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
          (timelineController.timelineData.cpuProfileData.cpuProfileRoot.depth +
                  1) *
              rowHeightWithPadding,
        ),
      );
    } else {
      canvasNeedsRebuild = true;
    }
  }

  Future<void> show() async {
    attribute('hidden', false);

    if (canvasNeedsRebuild) {
      canvasNeedsRebuild = false;
      await update();
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
  }

  void _removeMessage() {
    element.children.removeWhere((e) => e.id == 'flame-chart-message');
    showingMessage = false;
  }
}
