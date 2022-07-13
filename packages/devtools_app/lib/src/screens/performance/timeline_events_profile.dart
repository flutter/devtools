// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';

import '../../charts/flame_chart.dart';
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../ui/utils.dart';
import '../performance/performance_model.dart';

class TimelineEventsProfileView extends StatelessWidget {
  const TimelineEventsProfileView({
    Key? key,
    required this.framePhase,
  }) : super(key: key);

  final FramePhase framePhase;

  @override
  Widget build(BuildContext context) {
    assert(
      () {
        for (final root in framePhase.events) {
          if (root.parent != null) {
            return false;
          }
        }
        return true;
      }(),
    );
    if (framePhase.events.isEmpty) {
      return Center(
        child: Text(
          'No timeline event data for \'${framePhase.title}\'.',
        ),
      );
    }

    return RoundedOutlinedBorder(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return TimelineEventsProfileFlameChart(
            data: framePhase.timelineEventsProfile.root,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          );
        },
      ),
    );
  }
}

class TimelineEventsProfile {
  TimelineEventsProfile(List<SyncTimelineEvent> events) {
    final eventsCopy =
        List.generate(events.length, (index) => events[index].deepCopy());
    mergeProfileRoots(eventsCopy);
    assert(eventsCopy.length == 1);
    _root = eventsCopy.first;
  }

  SyncTimelineEvent get root => _root;

  late final SyncTimelineEvent _root;
}

class TimelineEventsProfileFlameChart
    extends FlameChart<SyncTimelineEvent, SyncTimelineEvent?> {
  TimelineEventsProfileFlameChart({
    required SyncTimelineEvent data,
    required double width,
    required double height,
    // required ValueListenable<CpuStackFrame?> selectionNotifier,
    // required ValueListenable<List<CpuStackFrame>> searchMatchesNotifier,
    // required ValueListenable<CpuStackFrame?> activeSearchMatchNotifier,
    // required void Function(CpuStackFrame? stackFrame) onDataSelected,
  }) : super(
          data,
          time: data.profileMetaData.time!,
          containerWidth: width,
          containerHeight: height,
          startInset: sideInsetSmall,
          endInset: sideInsetSmall,
          selectionNotifier: ImmediateValueNotifier(null),
          searchMatchesNotifier: null,
          activeSearchMatchNotifier: null,
          onDataSelected: (_) {},
        );

  @override
  _TimelineEventsProfileFlameChartState createState() =>
      _TimelineEventsProfileFlameChartState();
}

class _TimelineEventsProfileFlameChartState
    extends FlameChartState<TimelineEventsProfileFlameChart, TimelineEvent> {
  static const eventPadding = 1;

  final eventLefts = <TimelineEvent, double>{};

  @override
  void initFlameChartElements() {
    super.initFlameChartElements();
    expandRows(
      widget.data.depth +
          rowOffsetForTopPadding +
          FlameChart.rowOffsetForBottomPadding,
    );

    void createChartNodes(SyncTimelineEvent event, int row) {
      final double width =
          widget.startingContentWidth * event.totalTimeRatio - eventPadding;
      final left = startingLeftForEvent(event);
      final colorPair = _colorPairForEvent(event);

      final node = FlameChartNode<TimelineEvent>(
        key: Key('${event.name} ${event.traceEvents.first.wrapperId}'),
        text: event.name!,
        rect: Rect.fromLTWH(left, flameChartNodeTop, width, rowHeight),
        colorPair: colorPair,
        data: event,
        onSelected: (_) => {},
      )..sectionIndex = 0;

      rows[row].addNode(node);

      for (final child in event.children.cast<SyncTimelineEvent>()) {
        createChartNodes(child, row + 1);
      }
    }

    createChartNodes(widget.data, rowOffsetForTopPadding);
  }

  @override
  List<Widget> buildChartOverlays(
    BoxConstraints constraints,
    BuildContext buildContext,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return [
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
    ];
  }

  @override
  bool isDataVerticallyInView(TimelineEvent data) {
    return true;
    // final verticalScrollOffset = verticalControllerGroup.offset;
    // final stackFrameTopY = topYForData(data);
    // return stackFrameTopY > verticalScrollOffset &&
    //     stackFrameTopY + rowHeightWithPadding <
    //         verticalScrollOffset + widget.containerHeight;
  }

  @override
  bool isDataHorizontallyInView(TimelineEvent data) {
    return true;
    // final horizontalScrollOffset = horizontalControllerGroup.offset;
    // final startX = startXForData(data);
    // return startX >= horizontalScrollOffset &&
    //     startX <= horizontalScrollOffset + widget.containerWidth;
  }

  @override
  double topYForData(TimelineEvent data) {
    return data.level * rowHeightWithPadding;
  }

  @override
  double startXForData(TimelineEvent data) {
    final x = eventLefts[data]! - widget.startInset;
    return x * currentZoom;
  }

  double startingLeftForEvent(TimelineEvent event) {
    final TimelineEvent? parent = event.parent;
    late double left;
    if (parent == null) {
      left = widget.startInset;
    } else {
      final eventIndex = parent.children.indexOf(event);
      if (eventIndex == 0) {
        // This is the first child of parent. [left] should equal the left
        // value of [event]'s parent.
        left = eventLefts[parent]!;
      } else {
        assert(eventIndex != -1);
        // [event] is not the first child of its parent. [left] should
        // equal the right value of its previous sibling.
        final SyncTimelineEvent previous =
            parent.children[eventIndex - 1] as SyncTimelineEvent;
        left = eventLefts[previous]! +
            (widget.startingContentWidth * previous.totalTimeRatio);
      }
    }
    eventLefts[event] = left;
    return left;
  }

  ThemedColorPair _colorPairForEvent(TimelineEvent event) {
    return _color;
  }

  static const _color = ThemedColorPair(
    background: ThemedColor(
      light: Color(0xFF007B83),
      dark: Color(0xFF72B6C6),
    ),
    foreground: ThemedColor(
      light: Color(0xFFF8F9FA),
      dark: Color(0xFF202124),
    ),
  );
}

// class TimelineEventsProfileCallTree extends StatelessWidget {
//   const TimelineEventsProfileCallTree({
//     Key? key,
//     required this.frameAnalysisBlockData,
//   }) : super(key: key);
//   final FrameAnalysisBlockData frameAnalysisBlockData;
//
//   static const totalTimeTooltip =
//       'Time that a method spent executing its own code as well as the code for '
//       'the\nmethod that it called (which is displayed as an ancestor in the '
//       'bottom up tree).';
//
//   static const selfTimeTooltip =
//       'For top-level events in the bottom-up tree (leaf events in the '
//       'timeline),\nthis is the duration of the event. For sub-events (the\n'
//       'parent events in the timeline), this value is the self-time of the child'
//       ' event when this event is its parent.';
//
//   @override
//   Widget build(BuildContext context) {
//     final treeColumn = TimelineEventColumn();
//     final startingSortColumn = SelfTimeColumn(titleTooltip: selfTimeTooltip);
//     final columns = List<ColumnData<TimelineEvent>>.unmodifiable([
//       TotalTimeColumn(titleTooltip: totalTimeTooltip),
//       startingSortColumn,
//       treeColumn,
//     ]);
//     return TreeTable<TimelineEvent>(
//       dataRoots: frameAnalysisBlockData.events,
//       columns: columns,
//       treeColumn: treeColumn,
//       keyFactory: (event) =>
//           PageStorageKey<String>('${event.traceEvents.first.wrapperId}'),
//       sortColumn: startingSortColumn,
//       sortDirection: SortDirection.descending,
//     );
//   }
// }
//
// class SelfTimeColumn extends ColumnData<SyncTimelineEvent> {
//   SelfTimeColumn({required String titleTooltip})
//       : super(
//           'Self Time',
//           titleTooltip: titleTooltip,
//           fixedWidthPx: scaleByFontFactor(timeColumnWidthPx),
//         );
//
//   @override
//   bool get numeric => true;
//
//   @override
//   int compare(SyncTimelineEvent a, SyncTimelineEvent b) {
//     final int result = super.compare(a, b);
//     if (result == 0) {
//       return a.name!.compareTo(b.name!);
//     }
//     return result;
//   }
//
//   @override
//   dynamic getValue(SyncTimelineEvent dataObject) =>
//       dataObject.selfTime.inMicroseconds;
//
//   @override
//   String getDisplayValue(SyncTimelineEvent dataObject) {
//     return '${msText(dataObject.selfTime, fractionDigits: 2)} '
//         '(${percent2(dataObject.selfTimeRatio)})';
//   }
//
//   @override
//   String getTooltip(SyncTimelineEvent dataObject) => '';
// }
//
// class TotalTimeColumn extends ColumnData<SyncTimelineEvent> {
//   TotalTimeColumn({required String titleTooltip})
//       : super(
//           'Total Time',
//           titleTooltip: titleTooltip,
//           fixedWidthPx: scaleByFontFactor(timeColumnWidthPx),
//         );
//
//   @override
//   bool get numeric => true;
//
//   @override
//   int compare(SyncTimelineEvent a, SyncTimelineEvent b) {
//     final int result = super.compare(a, b);
//     if (result == 0) {
//       return a.name!.compareTo(b.name!);
//     }
//     return result;
//   }
//
//   @override
//   dynamic getValue(SyncTimelineEvent dataObject) =>
//       dataObject.time.duration.inMicroseconds;
//
//   @override
//   String getDisplayValue(SyncTimelineEvent dataObject) {
//     return '${msText(dataObject.time.duration, fractionDigits: 2)} '
//         '(${percent2(dataObject.totalTimeRatio)})';
//   }
//
//   @override
//   String getTooltip(SyncTimelineEvent dataObject) => '';
// }
//
// class TimelineEventColumn extends TreeColumnData<TimelineEvent> {
//   TimelineEventColumn() : super('Event');
//
//   @override
//   dynamic getValue(TimelineEvent dataObject) => dataObject.name;
//
//   @override
//   String getDisplayValue(TimelineEvent dataObject) {
//     return dataObject.name ?? '';
//   }
//
//   @override
//   bool get supportsSorting => true;
//
//   @override
//   String getTooltip(TimelineEvent dataObject) => dataObject.name ?? '';
// }
