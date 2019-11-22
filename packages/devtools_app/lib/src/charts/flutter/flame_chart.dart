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

abstract class FlameChart<T, V extends FlameChartNodeDataMixin>
    extends StatefulWidget {
  const FlameChart(
    this.data, {
    @required this.duration,
    @required this.height,
    @required this.totalStartingWidth,
    @required this.startInset,
    @required this.selectionNotifier,
    @required this.onSelection,
  });

  final T data;

  final Duration duration;

  final double totalStartingWidth;

  final double height;

  final double startInset;

  final ValueListenable<V> selectionNotifier;

  final void Function(V event) onSelection;

  double get startingContentWidth =>
      totalStartingWidth - startInset - sideInset;
}

abstract class FlameChartState<T extends FlameChart> extends State<T>
    with AutoDisposeMixin {
  LinkedScrollControllerGroup _linkedScrollControllerGroup;

  List<FlameChartRow> rows;

  @override
  void initState() {
    super.initState();
    addAutoDisposeListener(widget.selectionNotifier);
    _linkedScrollControllerGroup = LinkedScrollControllerGroup();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    if (widget.data != oldWidget.data) {
      _linkedScrollControllerGroup.resetScroll();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    // Initialize the flame chart elements before building.
    initFlameChartElements();

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            return ScrollingFlameChartRow(
              linkedScrollControllerGroup: _linkedScrollControllerGroup,
              row: rows[index],
              width: math.max(constraints.maxWidth, widget.totalStartingWidth),
            );
          },
        );
      },
    );
  }

  void initFlameChartElements();
}

class ScrollingFlameChartRow extends StatefulWidget {
  const ScrollingFlameChartRow({
    @required this.linkedScrollControllerGroup,
    @required this.row,
    @required this.width,
  });

  final LinkedScrollControllerGroup linkedScrollControllerGroup;

  final FlameChartRow row;

  final double width;

  @override
  _ScrollingFlameChartRowState createState() => _ScrollingFlameChartRowState();
}

class _ScrollingFlameChartRowState extends State<ScrollingFlameChartRow>
    with AutoDisposeMixin {
  ScrollController scrollController;

  @override
  void initState() {
    scrollController = widget.linkedScrollControllerGroup.addAndGet();
    super.initState();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: widget.row.nodes.isEmpty
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
                ...widget.row.nodes,
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
        onSelected = ((_) {});

  static const _selectedNodeColor = mainUiColorSelectedLight;

  final Rect rect;
  final String text;
  final String tooltip;
  final Color backgroundColor;
  final Color textColor;
  final T data;
  final void Function(T) onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = data?.selected ?? false;
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
