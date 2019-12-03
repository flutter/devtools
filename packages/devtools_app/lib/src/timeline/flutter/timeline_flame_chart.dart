// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
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
      selected: selectedEvent,
      onSelected: (e) => controller.selectTimelineEvent(e),
    );
  }

  Widget _buildFullTimeline(
    TimelineController controller,
    BoxConstraints constraints,
    TimelineEvent selectedEvent,
  ) {
    final fullTimelineEmpty = controller.fullTimeline.data?.isEmpty ?? true;
    return !fullTimelineEmpty
        ? FullTimelineFlameChart(
            controller.fullTimeline.data,
            // TODO(kenz): remove * 4 once zooming is possible. This is so that we can
            // test horizontal scrolling functionality.
            width: constraints.maxWidth * 4,
            selected: selectedEvent,
            onSelection: (e) => controller.selectTimelineEvent(e),
          )
        : const SizedBox();
  }
}

class FrameBasedTimelineFlameChart
    extends FlameChart<TimelineFrame, TimelineEvent> {
  FrameBasedTimelineFlameChart(
    TimelineFrame data, {
    @required double width,
    @required TimelineEvent selected,
    @required Function(TimelineEvent event) onSelected,
  }) : super(
          data,
          duration: data.time.duration,
          totalStartingWidth: width,
          selected: selected,
          onSelected: onSelected,
        );

  @override
  FrameBasedTimelineFlameChartState createState() =>
      FrameBasedTimelineFlameChartState();
}

class FrameBasedTimelineFlameChartState
    extends FlameChartState<FrameBasedTimelineFlameChart, TimelineEvent> {
  // Add one for the spacer offset between UI and GPU nodes.
  int get gpuSectionStartRow =>
      widget.data.uiEventFlow.depth +
      rowOffsetForTopPadding +
      rowOffsetForSectionSpacer;

  // TODO(kenz): when optimizing this code, consider passing in the viewport
  // to only construct FlameChartNode elements that are in view.
  @override
  void initFlameChartElements() {
    super.initFlameChartElements();

    final uiEventFlowDepth = widget.data.uiEventFlow.depth;
    final gpuEventFlowDepth = widget.data.gpuEventFlow.depth;

    expandRows(uiEventFlowDepth +
        gpuEventFlowDepth +
        rowOffsetForTopPadding +
        rowOffsetForSectionSpacer +
        rowOffsetForBottomPadding);

    // Add UI section label.
    final uiSectionLabel = FlameChartNode.sectionLabel(
      text: 'UI',
      textColor: Colors.black,
      backgroundColor: mainUiColor,
      top: flameChartNodeTop,
      width: 28.0,
    );
    rows[0 + rowOffsetForTopPadding].nodes.add(uiSectionLabel);

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
        onSelected: (dynamic event) => widget.onSelected(event),
      );

      rows[row].nodes.add(node);

      for (TimelineEvent child in event.children) {
        createChartNodes(child, row + 1);
      }
    }

    createChartNodes(widget.data.uiEventFlow, rowOffsetForTopPadding);
    createChartNodes(widget.data.gpuEventFlow, gpuSectionStartRow);
  }
}

class FullTimelineFlameChart
    extends FlameChart<FullTimelineData, TimelineEvent> {
  FullTimelineFlameChart(
    FullTimelineData data, {
    @required double width,
    @required TimelineEvent selected,
    @required Function(TimelineEvent event) onSelection,
  }) : super(
          data,
          duration: data.time.duration,
          totalStartingWidth: width,
          startInset: _calculateStartInset(data),
          selected: selected,
          onSelected: onSelection,
        );

  static double _calculateStartInset(FullTimelineData data) {
    // TODO(kenz): we need to calculate start inset based on the width of the
    // section labels. We should also set a max, ellipsize, and rely on tooltip
    // to give the full name in the event that the section name exceeds max.
    //
    // Alternatively, we could make the label section a column of it's own that
    // is resizeable. It would need to link scroll controllers with the list
    // view holding the flame chart nodes. This would make section labels sticky
    // to the left as an inherent bonus.
    return 140.0;
  }

  @override
  _FullTimelineFlameChartState createState() => _FullTimelineFlameChartState();
}

class _FullTimelineFlameChartState
    extends FlameChartState<FullTimelineFlameChart, TimelineEvent> {
  /// Stores the [FlameChartNode] for each [TimelineEvent] in the chart.
  ///
  /// We need to be able to look up a [FlameChartNode] based on its
  /// corresponding [TimelineEvent] when we traverse the event tree.
  final Map<TimelineEvent, FlameChartNode> chartNodesByEvent = {};

  int widestRow = -1;

  @override
  void initFlameChartElements() {
    super.initFlameChartElements();

    double leftForEvent(TimelineEvent event) {
      return (event.time.start.inMicroseconds - startTimeOffset) *
              startingPxPerMicro +
          widget.startInset;
    }

    double rightForEvent(TimelineEvent event) {
      return (event.time.end.inMicroseconds - startTimeOffset) *
              startingPxPerMicro +
          widget.startInset;
    }

    double maxRight = -1;
    void createChartNode(TimelineEvent event, int row, int section) {
      // TODO(kenz): we should do something more clever here by inferring the
      // missing start/end time based on ancestors/children. Skip for now.
      if (!event.isWellFormed) return;

      final double left = leftForEvent(event);
      final double right = rightForEvent(event);
      if (right > maxRight) {
        maxRight = right;
        widestRow = row;
      }

      Color backgroundColor;
      if (event.isAsyncEvent) {
        backgroundColor = nextAsyncColor();
      } else if (event.isUiEvent) {
        backgroundColor = nextUiColor();
      } else if (event.isGpuEvent) {
        backgroundColor = nextGpuColor();
      } else {
        backgroundColor = nextUnknownColor();
      }

      Color textColor;
      if (event.isGpuEvent) {
        textColor = ThemedColor.fromSingleColor(contrastForegroundWhite);
      } else {
        textColor = ThemedColor.fromSingleColor(Colors.black);
      }

      final node = FlameChartNode<TimelineEvent>(
        key: Key('${event.name} ${event.traceEvents.first.id}'),
        text: event.name,
        tooltip: '${event.name} - ${msText(event.time.duration)}',
        rect: Rect.fromLTRB(left, flameChartNodeTop, right, rowHeight),
        backgroundColor: backgroundColor,
        textColor: textColor,
        data: event,
        onSelected: (dynamic event) => widget.onSelected(event),
      );
      chartNodesByEvent[event] = node;

      rows[row].nodes.add(node);
    }

    expandRows(rowOffsetForTopPadding);
    int currentRowIndex = rowOffsetForTopPadding;
    int currentSectionIndex = 0;
    for (String groupName in widget.data.eventGroups.keys) {
      final FullTimelineEventGroup group = widget.data.eventGroups[groupName];
      // Expand rows to fit nodes in [group].
      assert(rows.length == currentRowIndex);
      final groupDisplaySize =
          group.eventsByRow.length + rowOffsetForSectionSpacer;
      expandRows(rows.length + groupDisplaySize);

      for (int i = 0; i < group.eventsByRow.length; i++) {
        final row = group.eventsByRow[i];
        for (var event in row) {
          createChartNode(
            event,
            currentRowIndex + i,
            currentSectionIndex,
          );
        }
      }

      final section = FlameChartSection(
        currentSectionIndex,
        startRow: currentRowIndex,
        endRow: currentRowIndex + group.displayDepth,
      );
      sections.add(section);

      // Add section label node.
      Color sectionLabelBackgroundColor;
      switch (groupName) {
        case FullTimelineData.uiKey:
          sectionLabelBackgroundColor = mainUiColor;
          break;
        case FullTimelineData.gpuKey:
          sectionLabelBackgroundColor = mainGpuColor;
          break;
        case FullTimelineData.unknownKey:
          sectionLabelBackgroundColor = mainUnknownColor;
          break;
        default:
          sectionLabelBackgroundColor = mainAsyncColor;
      }

      final currentSectionLabel = FlameChartNode.sectionLabel(
        text: groupName,
        textColor: Colors.black,
        backgroundColor: sectionLabelBackgroundColor,
        top: flameChartNodeTop,
        width: 120.0,
      );

      rows[currentRowIndex].nodes.insert(0, currentSectionLabel);

      // Increment for next section.
      currentRowIndex += groupDisplaySize;
      currentSectionIndex++;
    }

    // Ensure the nodes in each row are sorted in ascending positional order.
    for (var row in rows) {
      row.nodes.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    }

    // TODO(kenz): calculate async guidelines here.
  }
}
