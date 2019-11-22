// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../charts/flutter/flame_chart.dart';
import '../../flutter/controllers.dart';
import '../../ui/colors.dart';
import '../../ui/theme.dart';
import '../../utils.dart';
import '../timeline_controller.dart';
import '../timeline_model.dart';

class TimelineFlameChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Controllers.of(context).timeline;
    return LayoutBuilder(builder: (context, constraints) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: controller.timelineModeNotifier.value == TimelineMode.frameBased
            ? _buildFrameBasedTimeline(controller, constraints)
            : _buildFullTimeline(controller, constraints),
      );
    });
  }

  Widget _buildFrameBasedTimeline(
    TimelineController controller,
    BoxConstraints constraints,
  ) {
    return FrameBasedTimelineFlameChart(
      controller.frameBasedTimeline.data.selectedFrame,
      // TODO(kenz): remove * 2 once zooming is possible. This is so that we can
      // test horizontal scrolling functionality.
      width: constraints.maxWidth * 2,
      height: math.max(
        constraints.maxHeight,
        _frameBasedTimelineChartHeight(controller),
      ),
      selectionNotifier: controller.selectedTimelineEventNotifier,
      onSelection: (e) => controller.selectTimelineEvent(e),
    );
  }

  Widget _buildFullTimeline(
    TimelineController controller,
    BoxConstraints constraints,
  ) {
    // TODO(kenz): implement full timeline flame chart.
    return Container(
      color: Colors.black26,
      child: const Center(
        child: Text('TODO Full Timeline Flame Chart'),
      ),
    );
  }

  double _frameBasedTimelineChartHeight(TimelineController controller) {
    return (controller.frameBasedTimeline.data.displayDepth + 2) *
            rowHeightWithPadding +
        sectionSpacing;
  }
}

class FrameBasedTimelineFlameChart
    extends FlameChart<TimelineFrame, TimelineEvent> {
  FrameBasedTimelineFlameChart(
    TimelineFrame data, {
    @required double height,
    @required double width,
    @required ValueListenable selectionNotifier,
    @required Function(TimelineEvent event) onSelection,
  }) : super(
          data,
          duration: data.time.duration,
          height: height,
          totalStartingWidth: width,
          startInset: sideInset,
          selectionNotifier: selectionNotifier,
          onSelection: onSelection,
        );

  @override
  FrameBasedTimelineFlameChartState createState() =>
      FrameBasedTimelineFlameChartState();
}

class FrameBasedTimelineFlameChartState
    extends FlameChartState<FrameBasedTimelineFlameChart> {
  static const _rowOffsetForTopTimeline = 1;
  static const _rowOffsetForBottomTimeline = 1;
  static const _rowOffsetForSectionSpacer = 1;

  // Add one for the spacer offset between UI and GPU nodes.
  int get gpuSectionStartRow =>
      widget.data.uiEventFlow.depth +
      _rowOffsetForTopTimeline +
      _rowOffsetForSectionSpacer;

  // TODO(kenz): when optimizing this code, consider passing in the viewport
  // to only construct FlameChartNode elements that are in view.
  @override
  void initFlameChartElements() {
    _resetColorOffsets();

    rows = List.generate(
      widget.data.uiEventFlow.depth +
          widget.data.gpuEventFlow.depth +
          _rowOffsetForTopTimeline +
          _rowOffsetForSectionSpacer +
          _rowOffsetForBottomTimeline,
      (i) => FlameChartRow(nodes: [], index: i),
    );

    final int frameStartOffset = widget.data.time.start.inMicroseconds;

    // Pixels per microsecond in order to fit the entire frame in view.
    final double pxPerMicro =
        widget.startingContentWidth / widget.data.time.duration.inMicroseconds;

    // Top is always 0 because each node is positioned inside its own stack.
    const top = 0.0;

    // Add UI section label.
    final uiSectionLabel = FlameChartNode.sectionLabel(
      text: 'UI',
      textColor: Colors.black,
      backgroundColor: mainUiColor,
      top: top,
      width: 28.0,
    );
    rows[0 + _rowOffsetForTopTimeline].nodes.add(uiSectionLabel);

    // Add GPU section label.
    final gpuSectionLabel = FlameChartNode.sectionLabel(
      text: 'GPU',
      textColor: Colors.white,
      backgroundColor: mainGpuColor,
      top: top,
      width: 42.0,
    );
    rows[gpuSectionStartRow].nodes.add(gpuSectionLabel);

    void createChartNodes(TimelineEvent event, int row) {
      // Do not round these values. Rounding the left could cause us to have
      // inaccurately placed events on the chart. Rounding the width could cause
      // us to lose very small events if the width rounds to zero.
      final double left =
          (event.time.start.inMicroseconds - frameStartOffset) * pxPerMicro +
              widget.startInset;
      final double right =
          (event.time.end.inMicroseconds - frameStartOffset) * pxPerMicro +
              widget.startInset;
      final backgroundColor =
          event.isUiEvent ? _nextUiColor() : _nextGpuColor();

      final node = FlameChartNode<TimelineEvent>(
        key: Key('${event.name} ${event.time.start.inMicroseconds}'),
        text: event.name,
        tooltip: '${event.name} - ${msText(event.time.duration)}',
        rect: Rect.fromLTRB(left, top, right, rowHeight),
        backgroundColor: backgroundColor,
        textColor: event.isUiEvent
            ? ThemedColor.fromSingleColor(Colors.black)
            : ThemedColor.fromSingleColor(contrastForegroundWhite),
        data: event,
        onSelected: (dynamic event) => widget.onSelection(event),
      );

      rows[row].nodes.add(node);

      for (TimelineEvent child in event.children) {
        createChartNodes(
          child,
          row + 1,
        );
      }
    }

    createChartNodes(widget.data.uiEventFlow, _rowOffsetForTopTimeline);
    createChartNodes(widget.data.gpuEventFlow, gpuSectionStartRow);
  }
}

int _uiColorOffset = 0;

Color _nextUiColor() {
  final color = uiColorPalette[_uiColorOffset % uiColorPalette.length];
  _uiColorOffset++;
  return color;
}

int _gpuColorOffset = 0;

Color _nextGpuColor() {
  final color = gpuColorPalette[_gpuColorOffset % gpuColorPalette.length];
  _gpuColorOffset++;
  return color;
}

void _resetColorOffsets() {
  _uiColorOffset = 0;
  _gpuColorOffset = 0;
}
