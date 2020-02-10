// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../charts/flutter/flame_chart.dart';
import '../../flutter/controllers.dart';
import '../../geometry.dart';
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
    final selectedFrame = controller.frameBasedTimeline.data.selectedFrame;
    return selectedFrame != null
        ? FrameBasedTimelineFlameChart(
            selectedFrame,
            width: constraints.maxWidth,
            selected: selectedEvent,
            onSelected: (e) => controller.selectTimelineEvent(e),
          )
        : const SizedBox();
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
            width: constraints.maxWidth,
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
          time: data.time,
          totalStartingWidth: width,
          selected: selected,
          onSelected: onSelected,
        );

  @override
  FrameBasedTimelineFlameChartState createState() =>
      FrameBasedTimelineFlameChartState();
}

// TODO(kenz): override buildCustomPaints to provide TimelineGridPainter.
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
    rows[0 + rowOffsetForTopPadding].addNode(uiSectionLabel, index: 0);

    // Add GPU section label.
    final gpuSectionLabel = FlameChartNode.sectionLabel(
      text: 'GPU',
      textColor: Colors.white,
      backgroundColor: mainGpuColor,
      top: flameChartNodeTop,
      width: 42.0,
    );
    rows[gpuSectionStartRow].addNode(gpuSectionLabel, index: 0);

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
        key: Key('${event.name} ${event.traceEvents.first.id}'),
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

      rows[row].addNode(node);

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
          time: data.time,
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

  /// Offset for drawing async guidelines.
  static int asyncGuidelineOffset = 1;

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

  /// Async guideline segments drawn in the direction of the x-axis.
  final List<HorizontalLineSegment> horizontalGuidelines = [];

  /// Async guideline segments drawn in the direction of the y-axis.
  final List<VerticalLineSegment> verticalGuidelines = [];

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
        sectionIndex: section,
      );
      chartNodesByEvent[event] = node;

      rows[row].addNode(node);
    }

    expandRows(rowOffsetForTopPadding);
    int currentRowIndex = rowOffsetForTopPadding;
    int currentSectionIndex = 0;
    for (String groupName in widget.data.eventGroups.keys) {
      final FullTimelineEventGroup group = widget.data.eventGroups[groupName];
      // Expand rows to fit nodes in [group].
      assert(rows.length == currentRowIndex);
      final groupDisplaySize = group.rows.length + rowOffsetForSectionSpacer;
      expandRows(rows.length + groupDisplaySize);

      for (int i = 0; i < group.rows.length; i++) {
        for (var event in group.rows[i].events) {
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

      rows[currentRowIndex].addNode(currentSectionLabel, index: 0);

      // Increment for next section.
      currentRowIndex += groupDisplaySize;
      currentSectionIndex++;
    }

    // Ensure the nodes in each row are sorted in ascending positional order.
    for (var row in rows) {
      row.nodes.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    }

    _calculateAsyncGuidelines();
  }

  @override
  List<CustomPaint> buildCustomPaints(BoxConstraints constraints) {
    // TODO(kenz): add TimelineGridPainter to this list.
    return [
      CustomPaint(
        painter: AsyncGuidelinePainter(
          zoom: zoomController.value,
          constraints: constraints,
          verticalScrollOffset: verticalScrollOffset,
          horizontalScrollOffset: horizontalScrollOffset,
          verticalGuidelines: verticalGuidelines,
          horizontalGuidelines: horizontalGuidelines,
          chartStartInset: widget.startInset,
        ),
      ),
    ];
  }

  void _calculateAsyncGuidelines() {
    // Padding to be added between a subsequent guideline and the child event
    // it is connecting.
    const subsequentChildGuidelinePadding = 8.0;
    assert(rows.isNotEmpty);
    assert(chartNodesByEvent.isNotEmpty);
    verticalGuidelines.clear();
    horizontalGuidelines.clear();
    for (var row in rows) {
      for (var node in row.nodes) {
        if (node.data is AsyncTimelineEvent) {
          final event = node.data as AsyncTimelineEvent;
          if (event.children.isNotEmpty) {
            // Vertical guideline that will connect [node] with its children
            // nodes. The line will end at [node]'s last child.
            final verticalGuidelineX =
                node.rect.left + FullTimelineFlameChart.asyncGuidelineOffset;
            final verticalGuidelineStartY =
                _calculateVerticalGuidelineStartY(event);
            final verticalGuidelineEndY =
                _calculateHorizontalGuidelineY(event.lowestDisplayChild);
            verticalGuidelines.add(VerticalLineSegment(
              Offset(verticalGuidelineX, verticalGuidelineStartY),
              Offset(verticalGuidelineX, verticalGuidelineEndY),
            ));

            // Draw the first child since it is guaranteed to be connected to
            // the main vertical we just created.
            final firstChild = event.children.first;
            final horizontalGuidelineEndX =
                chartNodesByEvent[firstChild].rect.left;
            final horizontalGuidelineY =
                _calculateHorizontalGuidelineY(firstChild);
            horizontalGuidelines.add(HorizontalLineSegment(
              Offset(verticalGuidelineX, horizontalGuidelineY),
              Offset(horizontalGuidelineEndX, horizontalGuidelineY),
            ));

            // Horizontal guidelines connecting each child to the vertical
            // guideline above.
            for (int i = 1; i < event.children.length; i++) {
              double horizontalGuidelineStartX = verticalGuidelineX;

              final child = event.children[i];
              final childNode = chartNodesByEvent[child];

              // Helper method to generate a vertical guideline for subsequent
              // children after the first child. We will create a new guideline
              // if it can be created without intersecting previous children.
              void generateSubsequentVerticalGuideline(double previousXInRow) {
                double newVerticalGuidelineX;

                // If [child] started after [event] ended, use the right edge of
                // event's [node] as the x coordinate for the guideline.
                // Otherwise, take the minimum of
                // [subsequentChildGuidelineOffset] and half the distance
                // between [previousXInRow] and child's left edge.
                if (event.time.end < child.time.start) {
                  newVerticalGuidelineX = node.rect.right;
                } else {
                  newVerticalGuidelineX = childNode.rect.left -
                      math.min(
                        subsequentChildGuidelinePadding,
                        (childNode.rect.left - previousXInRow) / 2,
                      );
                }
                final newVerticalGuidelineEndY =
                    _calculateHorizontalGuidelineY(child);
                verticalGuidelines.add(VerticalLineSegment(
                  Offset(newVerticalGuidelineX, verticalGuidelineStartY),
                  Offset(newVerticalGuidelineX, newVerticalGuidelineEndY),
                ));

                horizontalGuidelineStartX = newVerticalGuidelineX;
              }

              if (childNode.row.index == node.row.index + 1) {
                final previousChildIndex =
                    childNode.row.nodes.indexOf(childNode) - 1;
                final previousNode = childNode.row.nodes[previousChildIndex];
                generateSubsequentVerticalGuideline(previousNode.rect.right);
              }

              final horizontalGuidelineEndX = childNode.rect.left;
              final horizontalGuidelineY =
                  _calculateHorizontalGuidelineY(child);
              horizontalGuidelines.add(HorizontalLineSegment(
                Offset(horizontalGuidelineStartX, horizontalGuidelineY),
                Offset(horizontalGuidelineEndX, horizontalGuidelineY),
              ));
            }
          }
        }
      }
    }

    // Sort the lists in ascending order based on their cross axis coordinate.
    verticalGuidelines.sort();
    horizontalGuidelines.sort();
  }

  int _spacerRowsBeforeEvent(TimelineEvent event) {
    // Add 1 to account for the first spacer row before section 0 begins.
    return chartNodesByEvent[event].sectionIndex + 1;
  }

  double _calculateVerticalGuidelineStartY(TimelineEvent event) {
    final spacerRowsBeforeEvent = _spacerRowsBeforeEvent(event);
    return spacerRowsBeforeEvent * sectionSpacing +
        (chartNodesByEvent[event].row.index - spacerRowsBeforeEvent) *
            rowHeightWithPadding +
        rowHeight;
  }

  double _calculateHorizontalGuidelineY(TimelineEvent event) {
    final spacerRowsBeforeEvent = _spacerRowsBeforeEvent(event);
    return spacerRowsBeforeEvent * sectionSpacing +
        (chartNodesByEvent[event].row.index - spacerRowsBeforeEvent) *
            rowHeightWithPadding +
        rowHeight / 2;
  }
}

class AsyncGuidelinePainter extends CustomPainter {
  AsyncGuidelinePainter({
    @required this.zoom,
    @required this.constraints,
    @required this.verticalScrollOffset,
    @required this.horizontalScrollOffset,
    @required this.verticalGuidelines,
    @required this.horizontalGuidelines,
    @required this.chartStartInset,
  });

  final double zoom;

  final BoxConstraints constraints;

  final double verticalScrollOffset;

  final double horizontalScrollOffset;

  final List<VerticalLineSegment> verticalGuidelines;

  final List<HorizontalLineSegment> horizontalGuidelines;

  final double chartStartInset;

  @override
  void paint(Canvas canvas, Size size) {
    final visible = Rect.fromLTWH(
      horizontalScrollOffset,
      verticalScrollOffset,
      constraints.maxWidth,
      constraints.maxHeight,
    );

    // The guideline objects are calculated with a base zoom level of 1.0. We
    // need to convert the zoomed left offset into the unzoomed left offset for
    // proper calculation of the first vertical guideline index.
    final unzoomedOffset = math.max(0.0, visible.left - chartStartInset) / zoom;
    final leftBoundWithZoom = chartStartInset + unzoomedOffset;

    final firstVerticalGuidelineIndex = lowerBound(
      verticalGuidelines,
      VerticalLineSegment(
        Offset(leftBoundWithZoom, visible.top),
        Offset(leftBoundWithZoom, visible.bottom),
      ),
    );
    final firstHorizontalGuidelineIndex = lowerBound(
      horizontalGuidelines,
      HorizontalLineSegment(visible.topLeft, visible.topRight),
    );

    if (firstVerticalGuidelineIndex != -1) {
      _paintGuidelines(
        canvas,
        visible,
        verticalGuidelines,
        firstVerticalGuidelineIndex,
      );
    }

    if (firstHorizontalGuidelineIndex != -1) {
      _paintGuidelines(
        canvas,
        visible,
        horizontalGuidelines,
        firstHorizontalGuidelineIndex,
      );
    }
  }

  void _paintGuidelines(
    Canvas canvas,
    Rect visible,
    List<LineSegment> guidelines,
    int firstLineIndex,
  ) {
    for (int i = firstLineIndex; i < guidelines.length; i++) {
      final line = guidelines[i];
      // Take [chartStartInset] and
      // [FullTimelineFlameChart.asyncGuidelineOffset] into account when
      // calculating [zoomedLine] because these units of space should not scale.
      final unzoomableOffsetLineStart =
          FullTimelineFlameChart.asyncGuidelineOffset + chartStartInset;

      LineSegment zoomedLine;
      if (line is VerticalLineSegment) {
        // The unzoomable offset will be the same for start and end because this
        // is a vertical line, so line.start.dx == line.end.dx.
        zoomedLine = line.toZoomed(
          zoom: zoom,
          unzoomableOffsetLineStart: unzoomableOffsetLineStart,
          unzoomableOffsetLineEnd: unzoomableOffsetLineStart,
        );
      } else {
        // The unzoomable end offset for a horizontal line is unaffected by
        // [FullTimelineFlameChart.asyncGuidelineOffset], so we only need to
        // consider [chartStartInset].
        zoomedLine = line.toZoomed(
          zoom: zoom,
          unzoomableOffsetLineStart: unzoomableOffsetLineStart,
          unzoomableOffsetLineEnd: chartStartInset,
        );
      }

      // We are out of range on the cross axis.
      if (!zoomedLine.crossAxisIntersects(visible)) break;

      // Only paint lines that intersect [visible] along both axes.
      if (zoomedLine.intersects(visible)) {
        canvas.drawLine(
          Offset(
            (zoomedLine.start.dx - horizontalScrollOffset)
                .clamp(0.0, constraints.maxWidth),
            (zoomedLine.start.dy - verticalScrollOffset)
                .clamp(0.0, constraints.maxHeight),
          ),
          Offset(
            (zoomedLine.end.dx - horizontalScrollOffset)
                .clamp(0.0, constraints.maxWidth),
            (zoomedLine.end.dy - verticalScrollOffset)
                .clamp(0.0, constraints.maxHeight),
          ),
          Paint()..color = treeGuidelineColor,
        );
      }
    }
  }

  // TODO(kenz): does this have to return true all the time? Is it cheaper to
  // compare delegates or to just paint?
  @override
  bool shouldRepaint(AsyncGuidelinePainter oldDelegate) => true;
}
