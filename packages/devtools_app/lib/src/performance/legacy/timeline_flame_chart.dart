// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(kenz): delete this legacy implementation after
// https://github.com/flutter/flutter/commit/78a96b09d64dc2a520e5b269d5cea1b9dde27d3f
// hits flutter stable.

import 'dart:math' as math;
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auto_dispose_mixin.dart';
import '../../charts/flame_chart.dart';
import '../../common_widgets.dart';
import '../../flutter_widgets/linked_scroll_controller.dart';
import '../../geometry.dart';
import '../../notifications.dart';
import '../../theme.dart';
import '../../trace_event.dart';
import '../../ui/colors.dart';
import '../../ui/search.dart';
import '../../utils.dart';
import 'performance_controller.dart';
import 'performance_model.dart';
import 'performance_utils.dart';

final legacyTimelineSearchFieldKey =
    GlobalKey(debugLabel: 'LegacyTimelineSearchFieldKey');

class LegacyTimelineFlameChartContainer extends StatefulWidget {
  const LegacyTimelineFlameChartContainer({
    @required this.processing,
    @required this.processingProgress,
  });

  @visibleForTesting
  static const emptyTimelineKey = Key('Empty Timeline');

  final bool processing;

  final double processingProgress;

  @override
  _LegacyTimelineFlameChartContainerState createState() =>
      _LegacyTimelineFlameChartContainerState();
}

class _LegacyTimelineFlameChartContainerState
    extends State<LegacyTimelineFlameChartContainer>
    with AutoDisposeMixin, SearchFieldMixin<LegacyTimelineFlameChartContainer> {
  LegacyPerformanceController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<LegacyPerformanceController>(context);
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
              ? Center(
                  key: LegacyTimelineFlameChartContainer.emptyTimelineKey,
                  child: Text(
                    'No timeline events',
                    style: Theme.of(context).subtleTextStyle,
                  ),
                )
              : _buildProcessingInfo();
        },
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          return LegacyTimelineFlameChart(
            controller.data,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            selectionNotifier: controller.selectedTimelineEvent,
            searchMatchesNotifier: controller.searchMatches,
            activeSearchMatchNotifier: controller.activeSearchMatch,
            onDataSelected: (e) => controller.selectTimelineEvent(e),
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
          AreaPaneHeader(
            title: const Text('Timeline Events'),
            tall: true,
            needsTopBorder: false,
            rightPadding: 0.0,
            rightActions: [
              _buildSearchField(searchFieldEnabled),
              FlameChartHelpButton(),
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

  Widget _buildSearchField(bool searchFieldEnabled) {
    return Container(
      width: wideSearchTextWidth,
      height: defaultTextFieldHeight,
      child: buildSearchField(
        controller: controller,
        searchFieldKey: legacyTimelineSearchFieldKey,
        searchFieldEnabled: searchFieldEnabled,
        shouldRequestFocus: false,
        supportsNavigation: true,
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

class LegacyTimelineFlameChart
    extends FlameChart<LegacyPerformanceData, LegacyTimelineEvent> {
  LegacyTimelineFlameChart(
    LegacyPerformanceData data, {
    @required double width,
    @required double height,
    @required ValueListenable<LegacyTimelineEvent> selectionNotifier,
    @required ValueListenable<List<LegacyTimelineEvent>> searchMatchesNotifier,
    @required ValueListenable<LegacyTimelineEvent> activeSearchMatchNotifier,
    @required Function(LegacyTimelineEvent event) onDataSelected,
  }) : super(
          data,
          time: data.time,
          containerWidth: width,
          containerHeight: height,
          startInset: _calculateStartInset(data),
          selectionNotifier: selectionNotifier,
          searchMatchesNotifier: searchMatchesNotifier,
          activeSearchMatchNotifier: activeSearchMatchNotifier,
          onDataSelected: onDataSelected,
        );

  static double _calculateStartInset(LegacyPerformanceData data) {
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
  LegacyTimelineFlameChartState createState() =>
      LegacyTimelineFlameChartState();
}

class LegacyTimelineFlameChartState
    extends FlameChartState<LegacyTimelineFlameChart, LegacyTimelineEvent> {
  /// Stores the [FlameChartNode] for each [LegacyTimelineEvent] in the chart.
  ///
  /// We need to be able to look up a [FlameChartNode] based on its
  /// corresponding [LegacyTimelineEvent] when we traverse the event tree.
  final chartNodesByEvent = <LegacyTimelineEvent, FlameChartNode>{};

  /// Async guideline segments drawn in the direction of the x-axis.
  final horizontalGuidelines = <HorizontalLineSegment>[];

  /// Async guideline segments drawn in the direction of the y-axis.
  final verticalGuidelines = <VerticalLineSegment>[];

  final eventGroupStartYValues = Expando<double>();

  int widestRow = -1;

  LegacyPerformanceController _performanceController;

  LegacyFlutterFrame _selectedFrame;

  ScrollController _groupLabelScrollController;

  ScrollController _previousInGroupButtonsScrollController;

  ScrollController _nextInGroupButtonsScrollController;

  @override
  int get rowOffsetForTopPadding =>
      LegacyTimelineFlameChart.rowOffsetForTopPadding;

  @override
  void initState() {
    super.initState();
    _groupLabelScrollController = verticalControllerGroup.addAndGet();
    _previousInGroupButtonsScrollController =
        verticalControllerGroup.addAndGet();
    _nextInGroupButtonsScrollController = verticalControllerGroup.addAndGet();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Provider.of<LegacyPerformanceController>(context);
    if (newController == _performanceController) return;
    _performanceController = newController;

    addAutoDisposeListener(
      _performanceController.selectedFrame,
      _handleSelectedFrame,
    );
  }

  @override
  bool isDataVerticallyInView(LegacyTimelineEvent data) {
    final eventTopY = topYForData(data);
    final verticalScrollOffset = verticalControllerGroup.offset;
    return eventTopY > verticalScrollOffset &&
        eventTopY + rowHeightWithPadding <
            verticalScrollOffset + widget.containerHeight;
  }

  @override
  bool isDataHorizontallyInView(LegacyTimelineEvent data) {
    return (visibleTimeRange.contains(data.time.start) &&
            visibleTimeRange.contains(data.time.end)) ||
        (data.time.start <= visibleTimeRange.start &&
            data.time.end >= visibleTimeRange.end);
  }

  @override
  double topYForData(LegacyTimelineEvent data) {
    final eventGroup = widget.data.eventGroups[legacyComputeEventGroupKey(
      data,
      _performanceController.threadNamesById,
    )];
    assert(eventGroup != null);
    final rowOffsetInGroup = eventGroup.rowIndexForEvent[data];
    return eventGroupStartYValues[eventGroup] +
        rowOffsetInGroup * rowHeightWithPadding;
  }

  @override
  double startXForData(LegacyTimelineEvent data) {
    final timeMicros = data.time.start.inMicroseconds;
    // Horizontally scroll to the frame.
    final relativeStartTime = timeMicros - startTimeOffset;
    final ratio = relativeStartTime / widget.data.time.duration.inMicroseconds;
    return contentWidthWithZoom * ratio;
  }

  int _indexOfFirstEventInView(LegacyTimelineEventGroup group) {
    final boundEvent = LegacySyncTimelineEvent(
      TraceEventWrapper(
        TraceEvent({'ts': visibleTimeRange.start.inMicroseconds})
          ..type = TimelineEventType.other,
        0, // This is arbitrary
      ),
    )..time = visibleTimeRange;
    return lowerBound(
      group.sortedEventRoots,
      boundEvent,
      compare: (LegacyTimelineEvent a, LegacyTimelineEvent b) =>
          a.time.start.compareTo(b.time.start),
    );
  }

  Future<void> _viewPreviousEventInGroup(LegacyTimelineEventGroup group) async {
    final firstInViewIndex = _indexOfFirstEventInView(group);
    if (firstInViewIndex > 0) {
      final event = group.sortedEventRoots[firstInViewIndex - 1];
      await zoomAndScrollToData(
        startMicros: event.time.start.inMicroseconds,
        durationMicros: event.time.duration.inMicroseconds,
        data: event,
        scrollVertically: false,
        jumpZoom: true,
      );
      return;
    }
    // This notification should not be shown, as we are disabling the previous
    // button when there are no more events out of view for the group. Leave
    // this here as a fallback though, so that we do not give the user a
    // completely broken experience if we regress or if there is a race.
    Notifications.of(context).push(
      'There are no events on this thread that occurred before this time range.',
    );
  }

  Future<void> _viewNextEventInGroup(LegacyTimelineEventGroup group) async {
    final boundEvent = LegacySyncTimelineEvent(
      TraceEventWrapper(
        TraceEvent({'ts': visibleTimeRange.end.inMicroseconds})
          ..type = TimelineEventType.other,
        0, // This is arbitrary
      ),
    )..time = (TimeRange()
      ..start = visibleTimeRange.end
      ..end = visibleTimeRange.end);
    final firstOutOfViewIndex = lowerBound(
      group.sortedEventRoots,
      boundEvent,
      compare: (LegacyTimelineEvent a, LegacyTimelineEvent b) =>
          a.time.end.compareTo(b.time.end),
    );

    LegacyTimelineEvent zoomTo;
    // If there are no events in this group that occur after the visible time
    // range, and the first event in the visible time range is the first event
    // in the group, zoom to this event. This covers the case where a user is
    // viewing a very zoomed out chart and would like to jump to the first in
    // view. If the first event in the group occurs before the visible time
    // range, then the user will be able to use the previous button to navigate
    // to that event.
    if (firstOutOfViewIndex == group.sortedEventRoots.length) {
      final firstInViewIndex = _indexOfFirstEventInView(group);
      if (firstInViewIndex == 0) {
        zoomTo = group.sortedEventRoots.first;
      }
    } else if (firstOutOfViewIndex < group.sortedEventRoots.length) {
      zoomTo = group.sortedEventRoots[firstOutOfViewIndex];
    }

    if (zoomTo != null) {
      await zoomAndScrollToData(
        startMicros: zoomTo.time.start.inMicroseconds,
        durationMicros: zoomTo.time.duration.inMicroseconds,
        data: zoomTo,
        scrollVertically: false,
        jumpZoom: true,
      );
      return;
    }

    // TODO(kenz): once the performance view records live frame data, perform
    // a refresh of timeline events here if we know there are more events we
    // have yet to render.

    // This notification should not be shown, as we are disabling the next
    // button when there are no more events out of view for the group. Leave
    // this here as a fallback though, so that we do not give the user a
    // completely broken experience if we regress or if there is a race.
    Notifications.of(context).push(
      'There are no events on this thread that occurred after this time range.',
    );
  }

  void _handleSelectedFrame() async {
    final selectedFrame = _performanceController.selectedFrame.value;
    if (selectedFrame == _selectedFrame) return;

    setState(() {
      _selectedFrame = selectedFrame;
    });

    // TODO(kenz): consider using jumpTo for some of these animations to
    // improve performance.

    if (_selectedFrame != null) {
      // Zoom and scroll to the frame's UI event.
      await zoomAndScrollToData(
        startMicros: selectedFrame.time.start.inMicroseconds,
        durationMicros: selectedFrame.time.duration.inMicroseconds,
        data: selectedFrame.uiEventFlow,
        jumpZoom: true,
      );
    }
  }

  @override
  void initFlameChartElements() {
    super.initFlameChartElements();

    double leftForEvent(LegacyTimelineEvent event) {
      return (event.time.start.inMicroseconds - startTimeOffset) *
              startingPxPerMicro +
          widget.startInset;
    }

    double rightForEvent(LegacyTimelineEvent event) {
      return (event.time.end.inMicroseconds - startTimeOffset) *
              startingPxPerMicro +
          widget.startInset;
    }

    double maxRight = -1;
    void createChartNode(LegacyTimelineEvent event, int row, int section) {
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
      } else if (event.isGCEvent) {
        // TODO(kenz): should we have a different color palette for GC events?
        backgroundColor = nextUnknownColor(row);
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

      final node = FlameChartNode<LegacyTimelineEvent>(
        key: Key('${event.name} ${event.traceEvents.first.id}'),
        text: event.name,
        rect: Rect.fromLTRB(left, flameChartNodeTop, right, rowHeight),
        backgroundColor: backgroundColor,
        textColor: textColor,
        data: event,
        onSelected: (dynamic event) => widget.onDataSelected(event),
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
      final LegacyTimelineEventGroup group = widget.data.eventGroups[groupName];
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
  List<Widget> buildChartOverlays(
    BoxConstraints constraints,
    BuildContext buildContext,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return [
      CustomPaint(
        painter: LegacyAsyncGuidelinePainter(
          zoom: currentZoom,
          constraints: constraints,
          verticalScrollOffset: verticalScrollOffset,
          horizontalScrollOffset: horizontalScrollOffset,
          verticalGuidelines: verticalGuidelines,
          horizontalGuidelines: horizontalGuidelines,
          chartStartInset: widget.startInset,
          colorScheme: colorScheme,
        ),
      ),
      CustomPaint(
        painter: TimelineGridPainter(
          zoom: currentZoom,
          constraints: constraints,
          verticalScrollOffset: verticalScrollOffset,
          horizontalScrollOffset: horizontalScrollOffset,
          chartStartInset: widget.startInset,
          chartEndInset: widget.endInset,
          flameChartWidth: widthWithZoom,
          duration: widget.time.duration,
          colorScheme: colorScheme,
        ),
      ),
      CustomPaint(
        painter: LegacySelectedFrameBracketPainter(
          _selectedFrame,
          zoom: currentZoom,
          constraints: constraints,
          verticalScrollOffset: verticalScrollOffset,
          horizontalScrollOffset: horizontalScrollOffset,
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
      _buildSectionLabels(constraints: constraints),
      ..._buildEventThreadNavigationButtons(constraints: constraints),
    ];
  }

  Widget _buildSectionLabels({@required BoxConstraints constraints}) {
    final colorScheme = Theme.of(context).colorScheme;
    final eventGroups = _performanceController.data.eventGroups;

    final children = <Widget>[];
    for (int i = 0; i < eventGroups.length; i++) {
      var topSpacer = 0.0;
      var bottomSpacer = 0.0;
      if (i == 0) {
        // Add spacing to account for timestamps at top of chart.
        topSpacer +=
            sectionSpacing * LegacyTimelineFlameChart.rowOffsetForTopPadding -
                rowHeight;
      }
      if (i == eventGroups.length - 1) {
        // Add spacing to account for bottom row of padding.
        bottomSpacer = rowHeight;
      }

      final groupName = eventGroups.keys.elementAt(i);
      final group = eventGroups[groupName];
      final backgroundColor = alternatingColorForIndex(i, colorScheme);
      final backgroundWithOpacity = Color.fromRGBO(
        backgroundColor.red,
        backgroundColor.green,
        backgroundColor.blue,
        0.85,
      );
      children.add(
        Container(
          padding: EdgeInsets.only(top: topSpacer, bottom: bottomSpacer),
          alignment: Alignment.topLeft,
          height: group.displaySizePx + topSpacer + bottomSpacer,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: densePadding,
              vertical: rowPadding,
            ),
            color: backgroundWithOpacity,
            child: Text(
              groupName,
              style: TextStyle(color: colorScheme.chartTextColor),
            ),
          ),
        ),
      );
    }

    return Positioned(
      top: rowHeight, // Adjust for row of timestamps
      left: 0.0,
      height: constraints.maxHeight,
      width: widget.startInset,
      child: IgnorePointer(
        child: ListView(
          physics: const ClampingScrollPhysics(),
          controller: _groupLabelScrollController,
          children: children,
        ),
      ),
    );
  }

  List<Widget> _buildEventThreadNavigationButtons({
    @required BoxConstraints constraints,
  }) {
    const threadButtonContainerWidth = buttonMinWidth + defaultSpacing;
    final eventGroups = _performanceController.data.eventGroups;

    Widget buildNavigatorButton(int index, {@required bool isNext}) {
      // Add spacing to account for timestamps at top of chart.
      final topSpacer = index == 0
          ? sectionSpacing * LegacyTimelineFlameChart.rowOffsetForTopPadding -
              rowHeight
          : 0.0;
      // Add spacing to account for bottom row of padding.
      final bottomSpacer = index == eventGroups.length - 1 ? rowHeight : 0.0;

      final groupName = eventGroups.keys.elementAt(index);
      final group = eventGroups[groupName];
      final backgroundColor = alternatingColorForIndex(
        // Add 1 so that the color of the button contrasts with the group
        // background color.
        index + 1,
        Theme.of(context).colorScheme,
      );
      final backgroundWithOpacity = Color.fromRGBO(
        backgroundColor.red,
        backgroundColor.green,
        backgroundColor.blue,
        0.85,
      );
      return LegacyNavigateInThreadInButton(
        group: group,
        isNext: isNext,
        topSpacer: topSpacer,
        bottomSpacer: bottomSpacer,
        backgroundColor: backgroundWithOpacity,
        threadButtonContainerWidth: threadButtonContainerWidth,
        onPressed: () => isNext
            ? _viewNextEventInGroup(group)
            : _viewPreviousEventInGroup(group),
        shouldEnableButton: (g) => isNext
            ? _shouldEnableNextInThreadButton(g)
            : _shouldEnablePrevInThreadButton(g),
        horizontalController: horizontalControllerGroup,
      );
    }

    return [
      Positioned(
        top: rowHeight, // Adjust for row of timestamps
        left: 0.0,
        height: constraints.maxHeight,
        width: threadButtonContainerWidth,
        child: ListView.builder(
          physics: const ClampingScrollPhysics(),
          controller: _previousInGroupButtonsScrollController,
          itemCount: eventGroups.length,
          itemBuilder: (context, i) => buildNavigatorButton(i, isNext: false),
        ),
      ),
      Positioned(
        top: rowHeight, // Adjust for row of timestamps
        right: 0.0,
        height: constraints.maxHeight,
        width: threadButtonContainerWidth,
        child: ListView.builder(
          physics: const ClampingScrollPhysics(),
          controller: _nextInGroupButtonsScrollController,
          itemCount: eventGroups.length,
          itemBuilder: (context, i) => buildNavigatorButton(i, isNext: true),
        ),
      ),
    ];
  }

  bool _shouldEnablePrevInThreadButton(LegacyTimelineEventGroup group) {
    return horizontalControllerGroup.hasAttachedControllers &&
        group.earliestTimestampMicros < visibleTimeRange.start.inMicroseconds;
  }

  bool _shouldEnableNextInThreadButton(LegacyTimelineEventGroup group) {
    final firstEventInView = _indexOfFirstEventInView(group);
    final noEventsAfterVisibleTimeRange =
        horizontalControllerGroup.hasAttachedControllers &&
            group.latestTimestampMicros <= visibleTimeRange.end.inMicroseconds;
    return (firstEventInView == 0 && noEventsAfterVisibleTimeRange) ||
        horizontalControllerGroup.hasAttachedControllers &&
            group.latestTimestampMicros > visibleTimeRange.end.inMicroseconds;
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
        if (node.data is LegacyAsyncTimelineEvent) {
          final event = node.data as LegacyAsyncTimelineEvent;
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
              node.rect.left + LegacyTimelineFlameChart.asyncGuidelineOffset;
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
              .firstWhere((LegacyTimelineEvent e) => !e.isAsyncInstantEvent);
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
                  (previousSibling.data as LegacyAsyncTimelineEvent)
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

  int _spacerRowsBeforeEvent(LegacyTimelineEvent event) {
    // Add 1 to account for the first spacer row before section 0 begins.
    return chartNodesByEvent[event].sectionIndex + rowOffsetForTopPadding;
  }

  double _calculateVerticalGuidelineStartY(LegacyTimelineEvent event) {
    final spacerRowsBeforeEvent = _spacerRowsBeforeEvent(event);
    return spacerRowsBeforeEvent * sectionSpacing +
        (chartNodesByEvent[event].row.index - spacerRowsBeforeEvent) *
            rowHeightWithPadding +
        rowHeight;
  }

  double _calculateHorizontalGuidelineY(LegacyTimelineEvent event) {
    final spacerRowsBeforeEvent = _spacerRowsBeforeEvent(event);
    return spacerRowsBeforeEvent * sectionSpacing +
        (chartNodesByEvent[event].row.index - spacerRowsBeforeEvent) *
            rowHeightWithPadding +
        rowHeight / 2;
  }
}

class LegacyAsyncGuidelinePainter extends FlameChartPainter {
  LegacyAsyncGuidelinePainter({
    @required double zoom,
    @required BoxConstraints constraints,
    @required double verticalScrollOffset,
    @required double horizontalScrollOffset,
    @required double chartStartInset,
    @required this.verticalGuidelines,
    @required this.horizontalGuidelines,
    @required ColorScheme colorScheme,
  }) : super(
          zoom: zoom,
          constraints: constraints,
          verticalScrollOffset: verticalScrollOffset,
          horizontalScrollOffset: horizontalScrollOffset,
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
    final paint = Paint()..color = colorScheme.treeGuidelineColor;
    var lastOpacity = 1.0;
    for (int i = firstLineIndex; i < guidelines.length; i++) {
      final line = guidelines[i];
      // Take [chartStartInset] and
      // [FullTimelineFlameChart.asyncGuidelineOffset] into account when
      // calculating [zoomedLine] because these units of space should not scale.
      final unzoomableOffsetLineStart =
          LegacyTimelineFlameChart.asyncGuidelineOffset + chartStartInset;

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

class LegacySelectedFrameBracketPainter extends FlameChartPainter {
  LegacySelectedFrameBracketPainter(
    this.selectedFrame, {
    @required double zoom,
    @required BoxConstraints constraints,
    @required double verticalScrollOffset,
    @required double horizontalScrollOffset,
    @required double chartStartInset,
    @required this.startTimeOffsetMicros,
    @required this.startingPxPerMicro,
    @required this.yForEvent,
    @required ColorScheme colorScheme,
  }) : super(
          zoom: zoom,
          constraints: constraints,
          verticalScrollOffset: verticalScrollOffset,
          horizontalScrollOffset: horizontalScrollOffset,
          chartStartInset: chartStartInset,
          colorScheme: colorScheme,
        );

  static const strokeWidth = 4.0;
  static const bracketWidth = 24.0;
  static const bracketCurveWidth = 8.0;
  static const bracketVerticalPadding = 8.0;

  final LegacyFlutterFrame selectedFrame;

  final int startTimeOffsetMicros;

  final double startingPxPerMicro;

  final double Function(LegacyTimelineEvent) yForEvent;

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
    @required LegacyTimelineEvent event,
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
  bool shouldRepaint(LegacySelectedFrameBracketPainter oldDelegate) =>
      this != oldDelegate;

  @override
  bool operator ==(Object other) {
    return other is LegacySelectedFrameBracketPainter &&
        selectedFrame == other.selectedFrame &&
        zoom == other.zoom &&
        constraints == other.constraints &&
        verticalScrollOffset == other.verticalScrollOffset &&
        horizontalScrollOffset == other.horizontalScrollOffset &&
        colorScheme == other.colorScheme;
  }

  @override
  int get hashCode => hashValues(
        selectedFrame,
        zoom,
        constraints,
        verticalScrollOffset,
        horizontalScrollOffset,
        colorScheme,
      );
}

class LegacyNavigateInThreadInButton extends StatefulWidget {
  const LegacyNavigateInThreadInButton({
    @required this.group,
    @required this.isNext,
    @required this.topSpacer,
    @required this.bottomSpacer,
    @required this.backgroundColor,
    @required this.threadButtonContainerWidth,
    @required this.onPressed,
    @required this.shouldEnableButton,
    @required this.horizontalController,
  });

  final LegacyTimelineEventGroup group;

  final bool isNext;

  final double topSpacer;

  final double bottomSpacer;

  final Color backgroundColor;

  final double threadButtonContainerWidth;

  final VoidCallback onPressed;

  final bool Function(LegacyTimelineEventGroup) shouldEnableButton;

  final LinkedScrollControllerGroup horizontalController;

  static const topPaddingForMediumGroups = 20.0;

  @override
  _LegacyNavigateInThreadInButtonState createState() =>
      _LegacyNavigateInThreadInButtonState();
}

class _LegacyNavigateInThreadInButtonState
    extends State<LegacyNavigateInThreadInButton> with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    // Call set state each time the horizontal offset is updated. This will
    // ensure we are properly enabling/disabling the navigator button based on
    // the visible time range.
    addAutoDisposeListener(widget.horizontalController.offsetNotifier);
  }

  @override
  Widget build(BuildContext context) {
    final useSmallButton = !widget.isNext && widget.group.displayDepth <= 1;
    final topPadding = !widget.isNext && widget.group.displayDepth == 2
        ? LegacyNavigateInThreadInButton.topPaddingForMediumGroups
        : 0.0;
    return Container(
      margin: EdgeInsets.only(
        top: widget.topSpacer,
        bottom: widget.bottomSpacer,
      ),
      padding: EdgeInsets.only(
        top: topPadding,
        bottom: useSmallButton ? borderPadding : 0.0,
        right: widget.isNext ? defaultSpacing : 0.0,
        left: widget.isNext ? 0.0 : defaultSpacing,
      ),
      height: widget.group.displaySizePx,
      width: widget.threadButtonContainerWidth,
      alignment: useSmallButton ? Alignment.bottomCenter : Alignment.center,
      child: LegacyThreadNavigatorButton(
        useSmallButton: useSmallButton,
        backgroundColor: widget.backgroundColor,
        tooltip:
            widget.isNext ? 'Next event in thread' : 'Previous event in thread',
        icon: widget.isNext ? Icons.chevron_right : Icons.chevron_left,
        onPressed:
            widget.shouldEnableButton(widget.group) ? widget.onPressed : null,
      ),
    );
  }
}

class LegacyThreadNavigatorButton extends StatelessWidget {
  const LegacyThreadNavigatorButton({
    @required this.useSmallButton,
    @required this.backgroundColor,
    @required this.tooltip,
    @required this.icon,
    @required this.onPressed,
  });

  final bool useSmallButton;

  final Color backgroundColor;

  final String tooltip;

  final IconData icon;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: roundedBorderDecoration(context).copyWith(
        color: backgroundColor,
      ),
      // Using [buttonMinWidth] will result in a square button.
      height: useSmallButton ? smallButtonHeight : buttonMinWidth,
      width: buttonMinWidth,
      child: DevToolsTooltip(
        tooltip: tooltip,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(
            icon,
            size: actionsIconSize,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

extension LegacyTimelineEventGroupDisplayExtension on LegacyTimelineEventGroup {
  int get displaySize => rows.length + FlameChart.rowOffsetForSectionSpacer;

  double get displaySizePx =>
      rows.length * rowHeightWithPadding +
      FlameChart.rowOffsetForSectionSpacer * sectionSpacing;
}
