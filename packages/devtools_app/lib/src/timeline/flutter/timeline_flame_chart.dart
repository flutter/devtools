// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../charts/flutter/flame_chart.dart';
import '../../flutter/auto_dispose_mixin.dart';
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
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).focusColor),
          ),
          child: controller.timelineMode == TimelineMode.frameBased
              ? FrameBasedTimelineFlameChart(
                  controller.frameBasedTimeline.data.selectedFrame,
                  width: constraints.maxWidth,
                  height: math.max(
                    constraints.maxHeight,
                    _frameBasedTimelineChartHeight(controller),
                  ),
                  selectionProvider: () =>
                      controller.frameBasedTimeline.data.selectedEvent,
                  onSelection: (e) => controller.selectTimelineEvent(e),
                )
              // TODO(kenz): implement full timeline flame chart.
              : Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Text('TODO Full Timeline Flame Chart'),
                  ),
                ),
        ),
      );
    });
  }

  double _frameBasedTimelineChartHeight(TimelineController controller) {
    return (controller.frameBasedTimeline.data.displayDepth + 2) *
            rowHeightWithPadding +
        sectionSpacing;
  }
}

// TODO(kenz): Abstract core flame chart logic for use in other flame charts.
class FrameBasedTimelineFlameChart extends StatefulWidget {
  FrameBasedTimelineFlameChart(
    this.data, {
    @required this.height,
    @required double width,
    @required this.selectionProvider,
    @required this.onSelection,
  })  : duration = data.time.duration,
        startInset = sideInset,
        totalStartingWidth = width;

  final TimelineFrame data;

  final Duration duration;

  final double startInset;

  final double totalStartingWidth;

  final double height;

  final TimelineEvent Function() selectionProvider;

  final void Function(TimelineEvent event) onSelection;

  double get startingContentWidth =>
      totalStartingWidth - startInset - sideInset;

  @override
  FrameBasedTimelineFlameChartState createState() =>
      FrameBasedTimelineFlameChartState();
}

class FrameBasedTimelineFlameChartState
    extends State<FrameBasedTimelineFlameChart> with AutoDisposeMixin {
  static const startingScrollPosition = 0.0;
  ScrollController _scrollControllerX;
  ScrollController _scrollControllerY;
  double scrollOffsetX = startingScrollPosition;
  double scrollOffsetY = startingScrollPosition;

  List<FlameChartRow> rows;

  TimelineController _controller;

  int get gpuSectionStartRow => widget.data.uiEventFlow.depth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = Controllers.of(context).timeline;
    autoDispose(_controller.onSelectedTimelineEvent.listen((_) {
      setState(() {});
    }));
  }

  @override
  void didUpdateWidget(FrameBasedTimelineFlameChart oldWidget) {
    if (oldWidget.data != widget.data) {
      _scrollControllerX.jumpTo(startingScrollPosition);
      _scrollControllerY.jumpTo(startingScrollPosition);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    super.initState();

    // TODO(kenz): improve this so we are not rebuilding on every scroll.
    _scrollControllerX = ScrollController()
      ..addListener(() {
        setState(() {
          scrollOffsetX = _scrollControllerX.offset;
        });
      });

    _scrollControllerY = ScrollController()
      ..addListener(() {
        setState(() {
          scrollOffsetY = _scrollControllerY.offset;
        });
      });
  }

  @override
  void dispose() {
    _scrollControllerX.dispose();
    _scrollControllerY.dispose();
    // TODO(kenz): dispose [_controller] here.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          child: SingleChildScrollView(
            controller: _scrollControllerX,
            scrollDirection: Axis.horizontal,
            child: Scrollbar(
              child: SingleChildScrollView(
                controller: _scrollControllerY,
                scrollDirection: Axis.vertical,
                child: _flameChartBody(constraints),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _flameChartBody(BoxConstraints constraints) {
    final width = math.max(constraints.maxWidth, widget.totalStartingWidth);
    final height = math.max(constraints.maxHeight, widget.height);

    // TODO(kenz): rewrite this using slivers instead of a stack.
    return Stack(
      children: [
        Container(
          width: width,
          height: height,
        ),
        ..._nodesInViewport(constraints), // pick what to show
      ],
    );
  }

  List<FlameChartNode> _nodesInViewport(BoxConstraints constraints) {
    // TODO(kenz): is creating all the FlameChartNode objects expensive even if
    // we won't add them to the view? We create all the FlameChartNode objects
    // and place them in FlameChart rows, but we only add [nodesInViewport] to
    // the widget tree.
    _buildFlameChartElements();

    // TODO(kenz): Use binary search method we use in html full timeline here.
    final nodesInViewport = <FlameChartNode>[];
    for (var row in rows) {
      for (var node in row.nodes) {
        final fitsHorizontally = node.rect.right >= scrollOffsetX &&
            node.rect.left - scrollOffsetX <= constraints.maxWidth;
        final fitsVertically = node.rect.bottom >= scrollOffsetY &&
            node.rect.top - scrollOffsetY <= constraints.maxHeight;
        if (fitsHorizontally && fitsVertically) {
          nodesInViewport.add(node);
        }
      }
    }
    return nodesInViewport;
  }

  // TODO(kenz): when optimizing this code, consider passing in the viewport
  // to only construct FlameChartNode elements that are in view.
  void _buildFlameChartElements() {
    _resetColorOffsets();

    rows = List.generate(
      widget.data.uiEventFlow.depth + widget.data.gpuEventFlow.depth,
      (i) => FlameChartRow(nodes: [], index: i),
    );
    final int frameStartOffset = widget.data.time.start.inMicroseconds;

    double getTopForRow(int row) {
      // This accounts for the section spacing between the UI events and the GPU
      // events.
      final additionalPadding =
          row >= gpuSectionStartRow ? sectionSpacing : 0.0;
      return row * rowHeightWithPadding + topOffset + additionalPadding;
    }

    // Pixels per microsecond in order to fit the entire frame in view.
    final double pxPerMicro =
        widget.startingContentWidth / widget.data.time.duration.inMicroseconds;

    // Add UI section label.
    final uiSectionLabel = FlameChartNode.sectionLabel(
      text: 'UI',
      textColor: Colors.black,
      backgroundColor: mainUiColor,
      top: getTopForRow(0),
      width: 28.0,
    );
    rows[0].nodes.add(uiSectionLabel);

    // Add GPU section label.
    final gpuSectionLabel = FlameChartNode.sectionLabel(
      text: 'GPU',
      textColor: Colors.white,
      backgroundColor: mainGpuColor,
      top: getTopForRow(gpuSectionStartRow),
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
      final top = getTopForRow(row);
      final backgroundColor =
          event.isUiEvent ? _nextUiColor() : _nextGpuColor();

      final node = FlameChartNode<TimelineEvent>(
        key: Key('${event.name} ${event.time.start.inMicroseconds}'),
        text: event.name,
        tooltip: '${event.name} - ${msText(event.time.duration)}',
        rect: Rect.fromLTRB(left, top, right, top + rowHeight),
        backgroundColor: backgroundColor,
        textColor: event.isUiEvent
            ? ThemedColor.fromSingleColor(Colors.black)
            : ThemedColor.fromSingleColor(contrastForegroundWhite),
        data: event,
        selected: event == widget.selectionProvider(),
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

    createChartNodes(widget.data.uiEventFlow, 0);
    createChartNodes(widget.data.gpuEventFlow, gpuSectionStartRow);
  }

  double get calculatedContentWidth {
    // The farthest right node in the graph will either be the root UI event or
    // the root GPU event.
    return math.max(rows[gpuSectionStartRow].nodes.last.rect.right,
            rows[gpuSectionStartRow].nodes.last.rect.right) -
        widget.startInset;
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
