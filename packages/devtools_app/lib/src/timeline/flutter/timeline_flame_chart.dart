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
        child: ValueListenableBuilder(
          valueListenable: controller.selectedTimelineEventNotifier,
          builder: (context, selectedEvent, _) {
            return controller.timelineModeNotifier.value ==
                    TimelineMode.frameBased
                ? _buildFrameBasedTimeline(
                    controller,
                    constraints,
                    selectedEvent,
                  )
                : _buildFullTimeline(controller, constraints, selectedEvent);
          },
        ),
      );
    });
  }

  Widget _buildFrameBasedTimeline(
    TimelineController controller,
    BoxConstraints constraints,
    TimelineEvent selectedEvent,
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
      selected: selectedEvent,
      onSelected: (e) => controller.selectTimelineEvent(e),
    );
  }

  Widget _buildFullTimeline(
    TimelineController controller,
    BoxConstraints constraints,
    TimelineEvent selectedEvent,
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
    @required TimelineEvent selected,
    @required Function(TimelineEvent event) onSelected,
  }) : super(
          data,
          duration: data.time.duration,
          height: height,
          totalStartingWidth: width,
          startInset: sideInset,
          selected: selected,
          onSelected: onSelected,
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
    super.initFlameChartElements();

    final uiEventFlowDepth = widget.data.uiEventFlow.depth;
    final gpuEventFlowDepth = widget.data.gpuEventFlow.depth;
    rows = List.generate(
      uiEventFlowDepth +
          gpuEventFlowDepth +
          _rowOffsetForTopTimeline +
          _rowOffsetForSectionSpacer +
          _rowOffsetForBottomTimeline,
      (i) => FlameChartRow(nodes: [], index: i),
    );

    // Add UI section label.
    final uiSectionLabel = FlameChartNode.sectionLabel(
      text: 'UI',
      textColor: Colors.black,
      backgroundColor: mainUiColor,
      top: flameChartNodeTop,
      width: 28.0,
    );
    rows[0 + _rowOffsetForTopTimeline].nodes.add(uiSectionLabel);

    // Add GPU section label.
    final gpuSectionLabel = FlameChartNode.sectionLabel(
      text: 'GPU',
      textColor: Colors.white,
      backgroundColor: mainGpuColor,
      top: flameChartNodeTop,
      width: 42.0,
    );
    rows[gpuSectionStartRow].nodes.add(gpuSectionLabel);

    void createChartNodes(TimelineEvent event, int row) {
      // Do not round these values. Rounding the left could cause us to have
      // inaccurately placed events on the chart. Rounding the width could cause
      // us to lose very small events if the width rounds to zero.
      final double left = (event.time.start.inMicroseconds - startTimeOffset) *
              startingPxPerMicro +
          widget.startInset;
      final double right = (event.time.end.inMicroseconds - startTimeOffset) *
              startingPxPerMicro +
          widget.startInset;
      final backgroundColor = event.isUiEvent ? nextUiColor() : nextGpuColor();

      final node = FlameChartNode<TimelineEvent>(
        key: Key('${event.name} ${event.time.start.inMicroseconds}'),
        text: event.name,
        tooltip: '${event.name} - ${msText(event.time.duration)}',
        rect: Rect.fromLTRB(left, flameChartNodeTop, right, rowHeight),
        backgroundColor: backgroundColor,
        textColor: event.isUiEvent
            ? ThemedColor.fromSingleColor(Colors.black)
            : ThemedColor.fromSingleColor(contrastForegroundWhite),
        data: event,
        selected: event == widget.selected,
        onSelected: (dynamic event) => widget.onSelected(event),
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
