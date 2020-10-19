// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../charts/flame_chart.dart';
import '../common_widgets.dart';
import '../flutter_widgets/linked_scroll_controller.dart';
import '../geometry.dart';
import '../theme.dart';
import '../ui/colors.dart';
import '../ui/search.dart';
import '../ui/theme.dart';
import '../utils.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';
import 'timeline_utils.dart';

final timelineSearchFieldKey = GlobalKey(debugLabel: 'TimelineSearchFieldKey');

class TimelineFlameChartContainer extends StatefulWidget {
  const TimelineFlameChartContainer({
    @required this.processing,
    @required this.processingProgress,
  });

  @visibleForTesting
  static const emptyTimelineKey = Key('Empty Timeline');

  final bool processing;

  final double processingProgress;

  @override
  _TimelineFlameChartContainerState createState() =>
      _TimelineFlameChartContainerState();
}

class _TimelineFlameChartContainerState
    extends State<TimelineFlameChartContainer>
    with AutoDisposeMixin, SearchFieldMixin {
  TimelineController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<TimelineController>(context);
    if (newController == controller) return;
    controller = newController;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    final timelineEmpty = (controller.data?.isEmpty ?? true) ||
        controller.data.eventGroups.isEmpty;
    if (widget.processing || timelineEmpty) {
      content = ValueListenableBuilder<bool>(
        valueListenable: controller.emptyTimeline,
        builder: (context, emptyRecording, _) {
          return emptyRecording
              ? const Center(
                  key: TimelineFlameChartContainer.emptyTimelineKey,
                  child: Text('No timeline events'),
                )
              : _buildProcessingInfo();
        },
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          return TimelineFlameChart(
            controller.data,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            selectionNotifier: controller.selectedTimelineEvent,
            searchMatchesNotifier: controller.searchMatches,
            activeSearchMatchNotifier: controller.activeSearchMatch,
            onSelection: (e) => controller.selectTimelineEvent(e),
          );
        },
      );
    }

    final searchFieldEnabled =
        !(controller.data?.isEmpty ?? true) && !widget.processing;
    return OutlineDecoration(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          areaPaneHeader(
            context,
            title: 'Timeline Events',
            tall: true,
            needsTopBorder: false,
            actions: [
              Container(
                width: wideSearchTextWidth,
                height: defaultTextFieldHeight,
                child: buildSearchField(
                  controller: controller,
                  searchFieldKey: timelineSearchFieldKey,
                  searchFieldEnabled: searchFieldEnabled,
                  shouldRequestFocus: searchFieldEnabled,
                  supportsNavigation: true,
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingInfo() {
    return ProcessingInfo(
      progressValue: widget.processingProgress,
      processedObject: 'timeline trace',
    );
  }
}

// TODO(kenz): for sections with more than one row deep, add empty row for
// section label.

// TODO(kenz): make flame chart sections collapsible.

class TimelineFlameChart extends FlameChart<TimelineData, TimelineEvent> {
  TimelineFlameChart(
    TimelineData data, {
    @required double width,
    @required double height,
    @required ValueListenable<TimelineEvent> selectionNotifier,
    @required ValueListenable<List<TimelineEvent>> searchMatchesNotifier,
    @required ValueListenable<TimelineEvent> activeSearchMatchNotifier,
    @required Function(TimelineEvent event) onSelection,
  }) : super(
          data,
          time: data.time,
          containerWidth: width,
          containerHeight: height,
          startInset: _calculateStartInset(data),
          selectionNotifier: selectionNotifier,
          searchMatchesNotifier: searchMatchesNotifier,
          activeSearchMatchNotifier: activeSearchMatchNotifier,
          onSelected: onSelection,
        );

  static double _calculateStartInset(TimelineData data) {
    const spaceFor0msText = 55.0;
    const maxStartInset = 300.0;
    var maxMeasuredWidth = 0.0;
    for (String groupName in data.eventGroups.keys) {
      final textPainter = TextPainter(
        text: TextSpan(text: groupName),
        textDirection: TextDirection.ltr,
      )..layout();
      maxMeasuredWidth =
          math.max(maxMeasuredWidth, textPainter.width + 2 * densePadding);
    }
    return math.min(maxStartInset, maxMeasuredWidth) + spaceFor0msText;
  }

  /// Offset for drawing async guidelines.
  static const int asyncGuidelineOffset = 1;

  // Rows of top padding needed to create room for the timestamp labels and the
  // selected frame brackets.
  static const int rowOffsetForTopPadding = 3;

  @override
  TimelineFlameChartState createState() => TimelineFlameChartState();
}

class TimelineFlameChartState
    extends FlameChartState<TimelineFlameChart, TimelineEvent> {
  /// Stores the [FlameChartNode] for each [TimelineEvent] in the chart.
  ///
  /// We need to be able to look up a [FlameChartNode] based on its
  /// corresponding [TimelineEvent] when we traverse the event tree.
  final chartNodesByEvent = <TimelineEvent, FlameChartNode>{};

  /// Async guideline segments drawn in the direction of the x-axis.
  final horizontalGuidelines = <HorizontalLineSegment>[];

  /// Async guideline segments drawn in the direction of the y-axis.
  final verticalGuidelines = <VerticalLineSegment>[];

  final eventGroupStartYValues = Expando<double>();

  int widestRow = -1;

  TimelineController _timelineController;

  TimelineFrame _selectedFrame;

  @override
  int get rowOffsetForTopPadding => TimelineFlameChart.rowOffsetForTopPadding;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Provider.of<TimelineController>(context);
    if (newController == _timelineController) return;
    _timelineController = newController;

    addAutoDisposeListener(
      _timelineController.selectedFrame,
      _handleSelectedFrame,
    );
  }

  @override
  bool isDataVerticallyInView(TimelineEvent data) {
    final eventTopY = topYForData(data);
    final verticalScrollOffset = verticalController.offset;
    return eventTopY > verticalScrollOffset &&
        eventTopY + rowHeightWithPadding <
            verticalScrollOffset + widget.containerHeight;
  }

  @override
  bool isDataHorizontallyInView(TimelineEvent data) {
    return (visibleTimeRange.contains(data.time.start) &&
            visibleTimeRange.contains(data.time.end)) ||
        (data.time.start <= visibleTimeRange.start &&
            data.time.end >= visibleTimeRange.end);
  }

  @override
  double topYForData(TimelineEvent data) {
    final eventGroup = widget.data.eventGroups[computeEventGroupKey(data)];
    assert(eventGroup != null);
    final rowOffsetInGroup = eventGroup.rowIndexForEvent[data];
    return eventGroupStartYValues[eventGroup] +
        rowOffsetInGroup * rowHeightWithPadding;
  }

  @override
  double startXForData(TimelineEvent data) {
    final timeMicros = data.time.start.inMicroseconds;
    // Horizontally scroll to the frame.
    final relativeStartTime = timeMicros - startTimeOffset;
    final ratio = relativeStartTime / widget.data.time.duration.inMicroseconds;
    return contentWidthWithZoom * ratio;
  }

  void _handleSelectedFrame() async {
    final TimelineFrame selectedFrame = _timelineController.selectedFrame.value;
    if (selectedFrame != null) {
      if (selectedFrame == _selectedFrame) return;

      setState(() {
        _selectedFrame = selectedFrame;
      });

      // TODO(kenz): consider using jumpTo for some of these animations to
      // improve performance.

      // Vertically scroll to the frame's UI event.
      await scrollVerticallyToData(selectedFrame.uiEventFlow);

      // Bail early if the selection has changed again while the animation was
      // in progress.
      if (selectedFrame != _selectedFrame) return;

      // Zoom the frame into view.
      await zoomToTimeRange(
        startMicros: selectedFrame.time.start.inMicroseconds,
        durationMicros: selectedFrame.time.duration.inMicroseconds,
      );

      // Bail early if the selection has changed again while the animation was
      // in progress.
      if (selectedFrame != _selectedFrame) return;

      // Horizontally scroll to the frame.
      await scrollHorizontallyToData(selectedFrame.uiEventFlow);
    }
  }

  Future<void> zoomToTimeRange({
    @required int startMicros,
    @required int durationMicros,
    double targetWidth,
  }) async {
    targetWidth ??= widget.containerWidth * 0.8;
    final startingWidth = durationMicros * startingPxPerMicro;
    final zoom = targetWidth / startingWidth;
    final mouseXForZoom = (startMicros - startTimeOffset + durationMicros / 2) *
            startingPxPerMicro +
        widget.startInset;
    await zoomTo(zoom, forceMouseX: mouseXForZoom);
  }

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
        backgroundColor = nextAsyncColor(row);
      } else if (event.isUiEvent) {
        backgroundColor = nextUiColor(row);
      } else if (event.isRasterEvent) {
        backgroundColor = nextRasterColor(row);
      } else {
        backgroundColor = nextUnknownColor(row);
      }

      Color textColor;
      if (event.isRasterEvent) {
        textColor = contrastForegroundWhite;
      } else {
        textColor = Colors.black;
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
    double yOffset = rowOffsetForTopPadding * sectionSpacing;
    for (String groupName in widget.data.eventGroups.keys) {
      final TimelineEventGroup group = widget.data.eventGroups[groupName];
      // Expand rows to fit nodes in [group].
      assert(rows.length == currentRowIndex);
      expandRows(rows.length + group.displaySize);
      eventGroupStartYValues[group] = yOffset;
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

      // Increment for next section.
      currentRowIndex += group.displaySize;
      currentSectionIndex++;
      yOffset += group.displaySizePx;
    }

    // Ensure the nodes in each row are sorted in ascending positional order.
    for (var row in rows) {
      row.nodes.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    }

    _calculateAsyncGuidelines();
  }

  @override
  List<CustomPaint> buildCustomPaints(
    BoxConstraints constraints,
    BuildContext buildContext,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final zoom = zoomController.value;
    return [
      CustomPaint(
        painter: AsyncGuidelinePainter(
          zoom: zoom,
          constraints: constraints,
          verticalController: verticalController,
          horizontalController: horizontalController,
          verticalGuidelines: verticalGuidelines,
          horizontalGuidelines: horizontalGuidelines,
          chartStartInset: widget.startInset,
          colorScheme: colorScheme,
        ),
      ),
      CustomPaint(
        painter: TimelineGridPainter(
          zoom: zoom,
          constraints: constraints,
          verticalController: verticalController,
          horizontalController: horizontalController,
          chartStartInset: widget.startInset,
          chartEndInset: widget.endInset,
          flameChartWidth: widthWithZoom,
          duration: widget.time.duration,
          colorScheme: colorScheme,
        ),
      ),
      CustomPaint(
        painter: SelectedFrameBracketPainter(
          _selectedFrame,
          zoom: zoom,
          constraints: constraints,
          verticalController: verticalController,
          horizontalController: horizontalController,
          chartStartInset: widget.startInset,
          startTimeOffsetMicros: startTimeOffset,
          startingPxPerMicro: startingPxPerMicro,
          // Subtract [rowHeight] because [_calculateVerticalGuidelineStartY]
          // returns the Y value at the bottom of the flame chart node, and we
          // want the Y value at the top of the node.
          yForEvent: (event) =>
              _calculateVerticalGuidelineStartY(event) - rowHeight,
          colorScheme: colorScheme,
        ),
      ),
      CustomPaint(
        painter: SectionLabelPainter(
          _timelineController.data.eventGroups,
          zoom: zoom,
          constraints: constraints,
          verticalController: verticalController,
          horizontalController: horizontalController,
          chartStartInset: widget.startInset,
          colorScheme: colorScheme,
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
          bool allChildrenAreAsyncInstantEvents = true;
          for (var child in event.children) {
            if (!child.isAsyncInstantEvent) {
              allChildrenAreAsyncInstantEvents = false;
              break;
            }
          }
          // Continue if there are no children we should draw async guidelines
          // to.
          if (event.children.isEmpty || allChildrenAreAsyncInstantEvents) {
            continue;
          }

          // Vertical guideline that will connect [node] with its children
          // nodes. The line will end at [node]'s last child.
          final verticalGuidelineX =
              node.rect.left + TimelineFlameChart.asyncGuidelineOffset;
          final verticalGuidelineStartY =
              _calculateVerticalGuidelineStartY(event);
          final verticalGuidelineEndY =
              _calculateHorizontalGuidelineY(event.lowestDisplayChild);
          verticalGuidelines.add(VerticalLineSegment(
            Offset(verticalGuidelineX, verticalGuidelineStartY),
            Offset(verticalGuidelineX, verticalGuidelineEndY),
          ));

          // Draw the horizontal guideline to the first child event that is not
          // an instant event, since it is guaranteed to be connected to
          // the main vertical we just created.
          final firstChild = event.children
              .firstWhere((TimelineEvent e) => !e.isAsyncInstantEvent);
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
            if (child.isAsyncInstantEvent) continue;

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

            FlameChartNode previousSiblingInRow(FlameChartNode child) {
              final previousNodeIndex = child.row.nodes.indexOf(child) - 1;
              final previousNode = previousNodeIndex >= 0
                  ? child.row.nodes[previousNodeIndex]
                  : null;
              final isSibling = previousNode?.data?.parent == node.data;
              return isSibling ? previousNode : null;
            }

            if (childNode.row.index == node.row.index + 1) {
              FlameChartNode previousSibling = previousSiblingInRow(childNode);
              // Look back until we find the first sibling in this row that is
              // not an instant event (if present).
              while (previousSibling != null &&
                  (previousSibling.data as AsyncTimelineEvent)
                      .isAsyncInstantEvent) {
                previousSibling = previousSiblingInRow(previousSibling);
              }
              if (previousSibling != null) {
                generateSubsequentVerticalGuideline(previousSibling.rect.right);
              }
            }

            final horizontalGuidelineEndX = childNode.rect.left;
            final horizontalGuidelineY = _calculateHorizontalGuidelineY(child);
            horizontalGuidelines.add(HorizontalLineSegment(
              Offset(horizontalGuidelineStartX, horizontalGuidelineY),
              Offset(horizontalGuidelineEndX, horizontalGuidelineY),
            ));
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
    return chartNodesByEvent[event].sectionIndex + rowOffsetForTopPadding;
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

class SectionLabelPainter extends FlameChartPainter {
  SectionLabelPainter(
    this.eventGroups, {
    @required double zoom,
    @required BoxConstraints constraints,
    @required ScrollController verticalController,
    @required LinkedScrollControllerGroup horizontalController,
    @required double chartStartInset,
    @required ColorScheme colorScheme,
  }) : super(
          zoom: zoom,
          constraints: constraints,
          verticalController: verticalController,
          horizontalController: horizontalController,
          chartStartInset: chartStartInset,
          colorScheme: colorScheme,
        );

  final SplayTreeMap<String, TimelineEventGroup> eventGroups;

  @override
  void paint(Canvas canvas, Size size) {
    final verticalScrollOffset = verticalController.offset;
    canvas.clipRect(Rect.fromLTWH(
      0.0,
      rowHeight, // We do not want to paint inside the timestamp section.
      constraints.maxWidth,
      constraints.maxHeight - rowHeight,
    ));

    // Start at row height to account for timestamps at top of chart.
    var startSectionPx =
        sectionSpacing * TimelineFlameChart.rowOffsetForTopPadding;
    for (String groupName in eventGroups.keys) {
      final group = eventGroups[groupName];
      final labelTop = startSectionPx - verticalScrollOffset;

      final textPainter = TextPainter(
        text: TextSpan(
          text: groupName,
          style: TextStyle(color: colorScheme.chartTextColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelWidth = textPainter.width + 2 * densePadding;
      final backgroundColor = alternatingColorForIndex(
        eventGroups.values.toList().indexOf(group),
        colorScheme,
      );
      final backgroundWithOpacity = Color.fromRGBO(
        backgroundColor.red,
        backgroundColor.green,
        backgroundColor.blue,
        0.85,
      );

      canvas.drawRect(
        Rect.fromLTWH(
          0.0,
          labelTop,
          labelWidth,
          rowHeightWithPadding,
        ),
        Paint()..color = backgroundWithOpacity,
      );

      textPainter.paint(
        canvas,
        Offset(densePadding, labelTop + rowPadding),
      );

      startSectionPx += group.displaySizePx;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is SectionLabelPainter) {
      return eventGroups != oldDelegate.eventGroups ||
          super.shouldRepaint(oldDelegate);
    }
    return true;
  }
}

class AsyncGuidelinePainter extends FlameChartPainter {
  AsyncGuidelinePainter({
    @required double zoom,
    @required BoxConstraints constraints,
    @required ScrollController verticalController,
    @required LinkedScrollControllerGroup horizontalController,
    @required double chartStartInset,
    @required this.verticalGuidelines,
    @required this.horizontalGuidelines,
    @required ColorScheme colorScheme,
  }) : super(
          zoom: zoom,
          constraints: constraints,
          verticalController: verticalController,
          horizontalController: horizontalController,
          chartStartInset: chartStartInset,
          colorScheme: colorScheme,
        );

  final List<VerticalLineSegment> verticalGuidelines;

  final List<HorizontalLineSegment> horizontalGuidelines;

  @override
  void paint(Canvas canvas, Size size) {
    // The guideline objects are calculated with a base zoom level of 1.0. We
    // need to convert the zoomed left offset into the unzoomed left offset for
    // proper calculation of the first vertical guideline index.
    final visible = visibleRect;
    final unzoomedOffset = math.max(0.0, visible.left - chartStartInset) / zoom;
    final leftBoundWithoutZoom = chartStartInset + unzoomedOffset;

    final firstVerticalGuidelineIndex = lowerBound(
      verticalGuidelines,
      VerticalLineSegment(
        Offset(leftBoundWithoutZoom, visible.top),
        Offset(leftBoundWithoutZoom, visible.bottom),
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
    final horizontalScrollOffset = horizontalController.offset;
    final verticalScrollOffset = verticalController.offset;

    final paint = Paint()..color = colorScheme.treeGuidelineColor;
    var lastOpacity = 1.0;
    for (int i = firstLineIndex; i < guidelines.length; i++) {
      final line = guidelines[i];
      // Take [chartStartInset] and
      // [FullTimelineFlameChart.asyncGuidelineOffset] into account when
      // calculating [zoomedLine] because these units of space should not scale.
      final unzoomableOffsetLineStart =
          TimelineFlameChart.asyncGuidelineOffset + chartStartInset;

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
        final opacity = zoomedLine.opacity;
        if (opacity != lastOpacity) {
          paint.color = colorScheme.treeGuidelineColor.withOpacity(opacity);
          lastOpacity = opacity;
        }
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
          paint,
        );
      }
    }
  }

  // TODO(kenz): does this have to return true all the time? Is it cheaper to
  // compare delegates or to just paint?
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class TimelineGridPainter extends FlameChartPainter {
  TimelineGridPainter({
    @required double zoom,
    @required BoxConstraints constraints,
    @required ScrollController verticalController,
    @required LinkedScrollControllerGroup horizontalController,
    @required double chartStartInset,
    @required this.chartEndInset,
    @required this.flameChartWidth,
    @required this.duration,
    @required ColorScheme colorScheme,
  }) : super(
          zoom: zoom,
          constraints: constraints,
          verticalController: verticalController,
          horizontalController: horizontalController,
          chartStartInset: chartStartInset,
          colorScheme: colorScheme,
        );

  static const baseGridIntervalPx = 150.0;
  static const timestampOffset = 6.0;

  final double chartEndInset;

  final double flameChartWidth;

  final Duration duration;

  @override
  void paint(Canvas canvas, Size size) {
    // Paint background for the section that will contain the timestamps. This
    // section will appear sticky to the top of the viewport.
    final visible = visibleRect;
    canvas.drawRect(
      Rect.fromLTWH(
        0.0,
        0.0,
        constraints.maxWidth,
        math.min(constraints.maxHeight, rowHeight),
      ),
      Paint()..color = colorScheme.defaultBackgroundColor,
    );

    // Paint the timeline grid lines and corresponding timestamps in the flame
    // chart.
    final intervalWidth = _intervalWidth();
    final microsPerInterval = _microsPerInterval(intervalWidth);
    int timestampMicros = _startingTimestamp(intervalWidth, microsPerInterval);
    double lineX;
    if (visible.left <= chartStartInset) {
      lineX = chartStartInset - visible.left;
    } else {
      lineX =
          intervalWidth - ((visible.left - chartStartInset) % intervalWidth);
    }

    while (lineX < constraints.maxWidth) {
      _paintTimestamp(canvas, timestampMicros, intervalWidth, lineX);
      _paintGridLine(canvas, lineX);
      lineX += intervalWidth;
      timestampMicros += microsPerInterval;
    }
  }

  void _paintTimestamp(
    Canvas canvas,
    int timestampMicros,
    double intervalWidth,
    double lineX,
  ) {
    final timestampText = msText(
      Duration(microseconds: timestampMicros),
      fractionDigits: timestampMicros == 0 ? 1 : 3,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: timestampText,
        style: TextStyle(color: colorScheme.chartTextColor),
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: intervalWidth);

    // TODO(kenz): figure out a way for the timestamps to scroll out of view
    // smoothly instead of dropping off. Consider using a horizontal list view
    // of text widgets for the timestamps instead of painting them.
    final xOffset = lineX - textPainter.width - timestampOffset;
    if (xOffset > 0) {
      textPainter.paint(canvas, Offset(xOffset, 5.0));
    }
  }

  void _paintGridLine(Canvas canvas, double lineX) {
    canvas.drawLine(
      Offset(lineX, 0.0),
      Offset(lineX, constraints.maxHeight),
      Paint()..color = colorScheme.chartAccentColor,
    );
  }

  double _intervalWidth() {
    final log2ZoomLevel = log2(zoom);

    final gridZoomFactor = math.pow(2, log2ZoomLevel);
    final gridIntervalPx = baseGridIntervalPx / gridZoomFactor;

    /// The physical pixel width of the grid interval at [zoom].
    return gridIntervalPx * zoom;
  }

  int _microsPerInterval(double intervalWidth) {
    final contentWidth = flameChartWidth - chartStartInset - chartEndInset;
    final numCompleteIntervals =
        (flameChartWidth - chartStartInset - chartEndInset) ~/ intervalWidth;
    final remainderContentWidth =
        contentWidth - (numCompleteIntervals * intervalWidth);
    final remainderMicros =
        remainderContentWidth * duration.inMicroseconds / contentWidth;
    return ((duration.inMicroseconds - remainderMicros) / numCompleteIntervals)
        .round();
  }

  int _startingTimestamp(double intervalWidth, int microsPerInterval) {
    final horizontalScrollOffset = horizontalController.offset;

    final startingIntervalIndex = horizontalScrollOffset < chartStartInset
        ? 0
        : (horizontalScrollOffset - chartStartInset) ~/ intervalWidth + 1;
    return startingIntervalIndex * microsPerInterval;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => this != oldDelegate;

  @override
  bool operator ==(other) {
    return zoom == other.zoom &&
        constraints == other.constraints &&
        flameChartWidth == other.flameChartWidth &&
        horizontalController == other.horizontalController &&
        duration == other.duration &&
        colorScheme == other.colorScheme;
  }

  @override
  int get hashCode => hashValues(
        zoom,
        constraints,
        flameChartWidth,
        horizontalController,
        duration,
        colorScheme,
      );
}

class SelectedFrameBracketPainter extends FlameChartPainter {
  SelectedFrameBracketPainter(
    this.selectedFrame, {
    @required double zoom,
    @required BoxConstraints constraints,
    @required ScrollController verticalController,
    @required LinkedScrollControllerGroup horizontalController,
    @required double chartStartInset,
    @required this.startTimeOffsetMicros,
    @required this.startingPxPerMicro,
    @required this.yForEvent,
    @required ColorScheme colorScheme,
  }) : super(
          zoom: zoom,
          constraints: constraints,
          verticalController: verticalController,
          horizontalController: horizontalController,
          chartStartInset: chartStartInset,
          colorScheme: colorScheme,
        );

  static const strokeWidth = 4.0;
  static const bracketWidth = 24.0;
  static const bracketCurveWidth = 8.0;
  static const bracketVerticalPadding = 8.0;

  final TimelineFrame selectedFrame;

  final int startTimeOffsetMicros;

  final double startingPxPerMicro;

  final double Function(TimelineEvent) yForEvent;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedFrame == null) return;

    canvas.clipRect(Rect.fromLTWH(
      0.0,
      rowHeight, // We do not want to paint inside the timestamp section.
      constraints.maxWidth,
      constraints.maxHeight - rowHeight,
    ));

    final paint = Paint()
      ..color = defaultSelectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    _paintBrackets(canvas, paint, event: selectedFrame.uiEventFlow);
    _paintBrackets(canvas, paint, event: selectedFrame.rasterEventFlow);
  }

  void _paintBrackets(
    Canvas canvas,
    Paint paint, {
    @required TimelineEvent event,
  }) {
    final visible = visibleRect;
    final startMicros = event.time.start.inMicroseconds - startTimeOffsetMicros;
    final endMicros = event.time.end.inMicroseconds - startTimeOffsetMicros;
    final startPx = startMicros * startingPxPerMicro * zoom + chartStartInset;
    final endPx = endMicros * startingPxPerMicro * zoom + chartStartInset;

    final startBracketX =
        startPx - visible.left + (bracketWidth - bracketCurveWidth);
    final endBracketX =
        endPx - visible.left - (bracketWidth - bracketCurveWidth);
    final bracketTopY = yForEvent(event) - visible.top - bracketVerticalPadding;
    final bracketBottomY = bracketTopY +
        event.depth * rowHeightWithPadding -
        rowPadding +
        bracketVerticalPadding * 2;

    // Draw the start bracket.
    canvas.drawPath(
      Path()
        ..moveTo(startBracketX, bracketTopY)
        ..lineTo(startBracketX - bracketWidth + bracketCurveWidth, bracketTopY)
        ..arcTo(
          Rect.fromLTWH(
            startBracketX - bracketWidth,
            bracketTopY,
            bracketCurveWidth * 2,
            bracketCurveWidth * 2,
          ),
          degToRad(270),
          degToRad(-90),
          false,
        )
        ..lineTo(
          startBracketX - bracketWidth,
          bracketBottomY - bracketWidth,
        )
        ..arcTo(
          Rect.fromLTWH(
            startBracketX - bracketWidth,
            bracketBottomY - bracketVerticalPadding * 2,
            bracketCurveWidth * 2,
            bracketCurveWidth * 2,
          ),
          degToRad(180),
          degToRad(-90),
          false,
        )
        ..lineTo(startBracketX, bracketBottomY),
      paint,
    );

    // Draw the end bracket.
    // TODO(kenz): reuse the path of the start bracket and transform it to draw
    // the end bracket.
    canvas.drawPath(
      Path()
        ..moveTo(endBracketX, bracketTopY)
        ..lineTo(endBracketX + bracketWidth - bracketCurveWidth, bracketTopY)
        ..arcTo(
          Rect.fromLTWH(
            endBracketX + bracketWidth - bracketCurveWidth * 2,
            bracketTopY,
            bracketCurveWidth * 2,
            bracketCurveWidth * 2,
          ),
          degToRad(270),
          degToRad(90),
          false,
        )
        ..lineTo(
          endBracketX + bracketWidth,
          bracketBottomY - bracketWidth,
        )
        ..arcTo(
          Rect.fromLTWH(
            endBracketX + bracketWidth - bracketCurveWidth * 2,
            bracketBottomY - bracketVerticalPadding * 2,
            bracketCurveWidth * 2,
            bracketCurveWidth * 2,
          ),
          degToRad(0),
          degToRad(90),
          false,
        )
        ..lineTo(endBracketX, bracketBottomY),
      paint,
    );
  }

  @override
  bool shouldRepaint(SelectedFrameBracketPainter oldDelegate) =>
      this != oldDelegate;

  @override
  bool operator ==(Object other) {
    return other is SelectedFrameBracketPainter &&
        selectedFrame == other.selectedFrame &&
        zoom == other.zoom &&
        constraints == other.constraints &&
        verticalController == other.verticalController &&
        horizontalController == other.horizontalController &&
        colorScheme == other.colorScheme;
  }

  @override
  int get hashCode => hashValues(
        selectedFrame,
        zoom,
        constraints,
        verticalController,
        horizontalController,
        colorScheme,
      );
}

extension TimelineEventGroupDisplayExtension on TimelineEventGroup {
  int get displaySize => rows.length + FlameChart.rowOffsetForSectionSpacer;

  double get displaySizePx =>
      rows.length * rowHeightWithPadding +
      FlameChart.rowOffsetForSectionSpacer * sectionSpacing;
}
