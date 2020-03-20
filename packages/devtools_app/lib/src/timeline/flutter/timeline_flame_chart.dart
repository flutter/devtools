// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../charts/flutter/flame_chart.dart';
import '../../flutter/controllers.dart';
import '../../flutter/theme.dart';
import '../../geometry.dart';
import '../../ui/colors.dart';
import '../../ui/theme.dart';
import '../../utils.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';

class TimelineFlameChart extends FlameChart<TimelineData, TimelineEvent> {
  TimelineFlameChart(
    TimelineData data, {
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

  static double _calculateStartInset(TimelineData data) {
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

  final eventGroupStartXValues = Expando<double>();

  int widestRow = -1;

  TimelineController _timelineController;

  TimelineFrame _selectedFrame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Controllers.of(context).timeline;
    if (newController == _timelineController) return;
    _timelineController = newController;

    addAutoDisposeListener(
      _timelineController.selectedFrame,
      _handleSelectedFrame,
    );
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

      // Vertically scroll to the UI event group.
      final verticalScrollOffset =
          eventGroupStartXValues[widget.data.eventGroups[TimelineData.uiKey]];
      await verticalScrollController.animateTo(
        verticalScrollOffset,
        duration: shortDuration,
        curve: defaultCurve,
      );

      // Bail early if the selection has changed again while the animation was
      // in progress.
      if (selectedFrame != _selectedFrame) return;

      // Zoom the frame into view.
      final targetFrameWidth = widget.totalStartingWidth * 0.8;
      final startingFrameWidth =
          selectedFrame.time.duration.inMicroseconds * startingPxPerMicro;
      final zoom = targetFrameWidth / startingFrameWidth;
      final mouseXForZoom = (selectedFrame.time.start.inMicroseconds -
                  startTimeOffset +
                  selectedFrame.time.duration.inMicroseconds / 2) *
              startingPxPerMicro +
          widget.startInset;
      await zoomTo(zoom, forceMouseX: mouseXForZoom);

      // Bail early if the selection has changed again while the animation was
      // in progress.
      if (selectedFrame != _selectedFrame) return;

      // Horizontally scroll to the frame.
      final relativeStartTime =
          selectedFrame.time.start.inMicroseconds - startTimeOffset;
      final ratio =
          relativeStartTime / widget.data.time.duration.inMicroseconds;
      final offset = contentWidthWithZoom * ratio +
          widget.startInset -
          widget.totalStartingWidth * 0.1;
      await scrollToX(offset);
    }
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
        backgroundColor = nextAsyncColor(resetOffset: event.isRoot);
      } else if (event.isUiEvent) {
        backgroundColor = nextUiColor(resetOffset: event.isRoot);
      } else if (event.isRasterEvent) {
        backgroundColor = nextRasterColor(resetOffset: event.isRoot);
      } else {
        backgroundColor = nextUnknownColor(resetOffset: event.isRoot);
      }

      Color textColor;
      if (event.isRasterEvent) {
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
        useAlternateBackground: (TimelineEvent event) =>
            _selectedFrame != null && event.root.frameId == _selectedFrame.id,
        alternateBackgroundColor: nextSelectedColor(resetOffset: event.isRoot),
        sectionIndex: section,
      );
      chartNodesByEvent[event] = node;

      rows[row].addNode(node);
    }

    expandRows(rowOffsetForTopPadding);
    int currentRowIndex = rowOffsetForTopPadding;
    int currentSectionIndex = 0;
    double xOffset = 0.0;
    for (String groupName in widget.data.eventGroups.keys) {
      final TimelineEventGroup group = widget.data.eventGroups[groupName];
      // Expand rows to fit nodes in [group].
      assert(rows.length == currentRowIndex);
      expandRows(rows.length + group.displaySize);
      eventGroupStartXValues[group] = xOffset;
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
        case TimelineData.uiKey:
          sectionLabelBackgroundColor = mainUiColor;
          break;
        case TimelineData.rasterKey:
          sectionLabelBackgroundColor = mainRasterColor;
          break;
        case TimelineData.unknownKey:
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
      currentRowIndex += group.displaySize;
      currentSectionIndex++;
      xOffset += group.displaySizePx;
    }

    // Ensure the nodes in each row are sorted in ascending positional order.
    for (var row in rows) {
      row.nodes.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    }

    _calculateAsyncGuidelines();
  }

  @override
  List<CustomPaint> buildCustomPaints(BoxConstraints constraints) {
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
      CustomPaint(
        painter: TimelineGridPainter(
          zoom: zoomController.value,
          constraints: constraints,
          verticalScrollOffset: verticalScrollOffset,
          horizontalScrollOffset: horizontalScrollOffset,
          chartStartInset: widget.startInset,
          chartEndInset: widget.endInset,
          flameChartWidth: widthWithZoom,
          duration: widget.time.duration,
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

class TimelineGridPainter extends CustomPainter {
  TimelineGridPainter({
    @required this.zoom,
    @required this.constraints,
    @required this.verticalScrollOffset,
    @required this.horizontalScrollOffset,
    @required this.chartStartInset,
    @required this.chartEndInset,
    @required this.flameChartWidth,
    @required this.duration,
  });

  static const baseGridIntervalPx = 150.0;
  static const gridLineColor = ThemedColor(
    Color(0xFFCCCCCC),
    Color(0xFF585858),
  );
  static const timestampOffset = 6.0;
  static const timestampColor = ThemedColor(
    Color(0xFF24292E),
    Color(0xFFFAFBFC),
  );

  static const origin = 0.0;

  final double zoom;

  final BoxConstraints constraints;

  final double verticalScrollOffset;

  final double horizontalScrollOffset;

  final double chartStartInset;

  final double chartEndInset;

  final double flameChartWidth;

  final Duration duration;

  @override
  void paint(Canvas canvas, Size size) {
    // The absolute coordinates of the flame chart's visible section.
    final visible = Rect.fromLTWH(
      horizontalScrollOffset,
      verticalScrollOffset,
      constraints.maxWidth,
      constraints.maxHeight,
    );

    // Paint background for the section that will contain the timestamps. This
    // section will appear sticky to the top of the viewport.
    canvas.drawRect(
      Rect.fromLTWH(
        origin,
        origin,
        constraints.maxWidth,
        math.min(constraints.maxHeight, rowHeight),
      ),
      Paint()..color = chartBackgroundColor,
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
        style: const TextStyle(color: timestampColor),
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: intervalWidth);

    // TODO(kenz): figure out a way for the timestamps to scroll out of view
    // smoothly instead of dropping off. Consider using a horizontal list view
    // of text widgets for the timestamps instead of painting them.
    final xOffset = lineX - textPainter.width - timestampOffset;
    if (xOffset > 0) {
      textPainter.paint(canvas, Offset(xOffset, origin + 5.0));
    }
  }

  void _paintGridLine(Canvas canvas, double lineX) {
    canvas.drawLine(
      Offset(lineX, origin),
      Offset(lineX, constraints.maxHeight),
      Paint()..color = gridLineColor,
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
    final startingIntervalIndex = horizontalScrollOffset < chartStartInset
        ? 0
        : (horizontalScrollOffset - chartStartInset) ~/ intervalWidth + 1;
    return startingIntervalIndex * microsPerInterval;
  }

  @override
  bool shouldRepaint(TimelineGridPainter oldDelegate) => this != oldDelegate;

  @override
  bool operator ==(other) {
    return zoom == other.zoom &&
        constraints == other.constraints &&
        flameChartWidth == other.flameChartWidth &&
        horizontalScrollOffset == other.horizontalScrollOffset &&
        duration == other.duration;
  }

  @override
  int get hashCode => hashValues(
        zoom,
        constraints,
        flameChartWidth,
        horizontalScrollOffset,
        duration,
      );
}

extension TimelineEventGroupDisplayExtension on TimelineEventGroup {
  int get displaySize => rows.length + FlameChart.rowOffsetForSectionSpacer;

  double get displaySizePx =>
      rows.length * rowHeightWithPadding +
      FlameChart.rowOffsetForSectionSpacer * sectionSpacing;
}
