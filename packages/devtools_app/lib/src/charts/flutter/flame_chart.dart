// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_widgets/flutter_widgets.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/common_widgets.dart';
import '../../ui/colors.dart';
import '../../ui/fake_flutter/_real_flutter.dart';

const double rowPadding = 2.0;
const double rowHeight = 25.0;
const double rowHeightWithPadding = rowHeight + rowPadding;
const double sectionSpacing = 15.0;
const double topOffset = rowHeightWithPadding;
const double sideInset = 70.0;

// TODO(kenz): consider cleaning up by changing to a flame chart code to use a
// composition pattern instead of a class extension pattern.
abstract class FlameChart<T, V extends FlameChartNodeDataMixin>
    extends StatefulWidget {
  const FlameChart(
    this.data, {
    @required this.duration,
    @required this.height,
    @required this.totalStartingWidth,
    @required this.startInset,
    @required this.selected,
    @required this.onSelected,
  });

  final T data;

  final Duration duration;

  final double totalStartingWidth;

  final double height;

  final double startInset;

  final V selected;

  final void Function(V data) onSelected;

  double get startingContentWidth =>
      totalStartingWidth - startInset - sideInset;
}

abstract class FlameChartState<T extends FlameChart> extends State<T>
    with AutoDisposeMixin, FlameChartColorMixin {
  // The "top" positional value for each flame chart node will be 0.0 because
  // each node is positioned inside its own stack.
  final flameChartNodeTop = 0.0;

  LinkedScrollControllerGroup _linkedScrollControllerGroup;

  List<FlameChartRow> rows = [];

  /// Starting pixels per microsecond in order to fit all the data in view at
  /// start.
  double get startingPxPerMicro =>
      widget.startingContentWidth / widget.data.time.duration.inMicroseconds;

  int get startTimeOffset => widget.data.time.start.inMicroseconds;

  @override
  void initState() {
    super.initState();
    initFlameChartElements();
    _linkedScrollControllerGroup = LinkedScrollControllerGroup();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    if (widget.data != oldWidget.data) {
      _linkedScrollControllerGroup.resetScroll();
      initFlameChartElements();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            return ScrollingFlameChartRow(
              linkedScrollControllerGroup: _linkedScrollControllerGroup,
              sortedNodes: rows[index].nodes
                ..sort((a, b) => a.rect.left.compareTo(b.rect.left)),
              width: math.max(constraints.maxWidth, widget.totalStartingWidth),
            );
          },
        );
      },
    );
  }

  // This method must be overridden by all subclasses.
  @mustCallSuper
  void initFlameChartElements() {
    resetColorOffsets();
  }
}

class ScrollingFlameChartRow extends StatefulWidget {
  const ScrollingFlameChartRow({
    @required this.linkedScrollControllerGroup,
    @required this.sortedNodes,
    @required this.width,
  });

  final LinkedScrollControllerGroup linkedScrollControllerGroup;

  final List<FlameChartNode> sortedNodes;

  final double width;

  @override
  _ScrollingFlameChartRowState createState() => _ScrollingFlameChartRowState();
}

class _ScrollingFlameChartRowState extends State<ScrollingFlameChartRow>
    with AutoDisposeMixin {
  ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = widget.linkedScrollControllerGroup.addAndGet();
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: widget.sortedNodes.isEmpty
          ? SizedBox(
              height: sectionSpacing,
              width: widget.width,
            )
          // TODO(kenz): consider using a Flow layout or a custom multi-child
          // layout.
          : Stack(
              children: [
                Container(
                  height: rowHeightWithPadding,
                  width: widget.width,
                ),
                // TODO(kenz): reevaluate passing in all the data once we have a
                // large data set to test with.
                ...widget.sortedNodes,
              ],
            ),
    );
  }

// TODO(kenz): consider using this method when we have a larger data set to
// test with.
//  List<FlameChartNode> rowNodesInViewport(
//    List<FlameChartNode> nodes,
//    BoxConstraints constraints,
//  ) {
//    // TODO(kenz): Use binary search method we use in html full timeline here.
//    final nodesInViewport = <FlameChartNode>[];
//    for (var node in nodes) {
//      final horizontalScrollOffset = scrollController.hasClients
//          ? scrollController.offset
//          : scrollController.initialScrollOffset;
//      final fitsHorizontally = node.rect.right >= horizontalScrollOffset &&
//          node.rect.left - horizontalScrollOffset <= constraints.maxWidth;
//      if (fitsHorizontally) {
//        nodesInViewport.add(node);
//      }
//    }
//    return nodesInViewport;
//  }
}

class FlameChartRow {
  const FlameChartRow({
    @required this.nodes,
    @required this.index,
  });

  final List<FlameChartNode> nodes;
  final int index;
}

class FlameChartNode<T extends FlameChartNodeDataMixin>
    extends StatelessWidget {
  const FlameChartNode({
    Key key,
    @required this.text,
    @required this.tooltip,
    @required this.rect,
    @required this.backgroundColor,
    @required this.textColor,
    @required this.data,
    @required this.selected,
    @required this.onSelected,
  }) : super(key: key);

  FlameChartNode.sectionLabel({
    Key key,
    @required this.text,
    @required this.textColor,
    @required this.backgroundColor,
    @required double top,
    @required double width,
  })  : rect = Rect.fromLTRB(rowPadding, top, width, top + rowHeight),
        tooltip = '',
        data = null,
        selected = false,
        onSelected = ((_) {});

  static const _selectedNodeColor = mainUiColorSelectedLight;

  final Rect rect;
  final String text;
  final String tooltip;
  final Color backgroundColor;
  final Color textColor;
  final T data;
  final bool selected;
  final void Function(T) onSelected;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: Tooltip(
        message: tooltip,
        waitDuration: tooltipWait,
        preferBelow: false,
        child: InkWell(
          onTap: () => onSelected(data),
          child: Container(
            padding: const EdgeInsets.only(left: 6.0),
            alignment: Alignment.centerLeft,
            color: selected ? _selectedNodeColor : backgroundColor,
            child: Text(
              text,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.black : textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

mixin FlameChartNodeDataMixin {
  bool selected = false;
}

mixin FlameChartColorMixin {
  int _uiColorOffset = 0;
  Color nextUiColor() {
    final color = uiColorPalette[_uiColorOffset % uiColorPalette.length];
    _uiColorOffset++;
    return color;
  }

  int _gpuColorOffset = 0;
  Color nextGpuColor() {
    final color = gpuColorPalette[_gpuColorOffset % gpuColorPalette.length];
    _gpuColorOffset++;
    return color;
  }

  void resetColorOffsets() {
    _uiColorOffset = 0;
    _gpuColorOffset = 0;
  }
}
