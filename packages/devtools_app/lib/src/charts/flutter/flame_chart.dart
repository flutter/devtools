// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;

import 'package:collection/collection.dart';
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
abstract class FlameChart<T, V> extends StatefulWidget {
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

abstract class FlameChartState<T extends FlameChart, V> extends State<T>
    with AutoDisposeMixin, FlameChartColorMixin {
  // The "top" positional value for each flame chart node will be 0.0 because
  // each node is positioned inside its own stack.
  final flameChartNodeTop = 0.0;

  LinkedScrollControllerGroup _linkedScrollControllerGroup;

  final List<FlameChartRow> rows = [];

  final List<FlameChartSection> sections = [];

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
      initFlameChartElements();
      _linkedScrollControllerGroup.resetScroll();
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
            return ScrollingFlameChartRow<V>(
              linkedScrollControllerGroup: _linkedScrollControllerGroup,
              nodes: rows[index].nodes,
              width: math.max(constraints.maxWidth, widget.totalStartingWidth),
              constraints: constraints,
              selected: widget.selected,
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
    rows.clear();
    sections.clear();
  }

  void expandRows(int newRows) {
    final currentLength = rows.length;
    for (int i = currentLength; i < currentLength + newRows; i++) {
      rows.add(FlameChartRow());
    }
  }
}

class ScrollingFlameChartRow<V> extends StatefulWidget {
  const ScrollingFlameChartRow({
    @required this.linkedScrollControllerGroup,
    @required this.nodes,
    @required this.width,
    @required this.constraints,
    @required this.selected,
  });

  final LinkedScrollControllerGroup linkedScrollControllerGroup;

  final List<FlameChartNode> nodes;

  final double width;

  final BoxConstraints constraints;

  final V selected;

  @override
  _ScrollingFlameChartRowState createState() => _ScrollingFlameChartRowState();
}

class _ScrollingFlameChartRowState extends State<ScrollingFlameChartRow>
    with AutoDisposeMixin {
  ScrollController scrollController;

  var lastStartNodeIndexInViewport = -1;

  double get horizontalScrollOffset => scrollController.hasClients
      ? scrollController.offset
      : scrollController.initialScrollOffset;

  @override
  void initState() {
    super.initState();
    scrollController = widget.linkedScrollControllerGroup.addAndGet();
    addAutoDisposeListener(scrollController);
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
    lastStartNodeIndexInViewport = -1;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: widget.nodes.isEmpty
          ? SizedBox(
              height: sectionSpacing,
              width: widget.width,
            )
          // TODO(kenz): use Flow instead of stack.
          : Stack(
              children: [
                Container(
                  height: rowHeightWithPadding,
                  width: widget.width,
                ),
                ...rowNodesInViewport(),
              ],
            ),
    );
  }

  List<Widget> rowNodesInViewport() {
    final nodes = widget.nodes;
    final nodesInViewport = <Widget>[];
    final startNodeIndex = findFirstIndexInView(nodes);
    if (startNodeIndex != -1) {
      for (int i = startNodeIndex; i < nodes.length; i++) {
        final node = nodes[i];
        if (!nodeFitsInViewport(node)) {
          break;
        }
        nodesInViewport.add(node.buildWidget(node.data == widget.selected));
      }
    }
    lastStartNodeIndexInViewport = startNodeIndex;
    return nodesInViewport;
  }

  int findFirstIndexInView(List<FlameChartNode> nodes) {
    // If we know the previous start node index, start there to find the current
    // start node index.
    if (lastStartNodeIndexInViewport != -1) {
      var index = lastStartNodeIndexInViewport;
      while (index >= 0 && index < nodes.length) {
        final node = nodes[index];
        if (nodeFitsInViewport(node)) {
          if (index > 0 && nodeFitsInViewport(nodes[index - 1])) {
            // Since the previous node also fits in the viewport, keep looking
            // left for the first fitting index.
            index--;
          } else {
            // [index] is the first fitting index.
            break;
          }
        } else {
          index++;
        }
      }
      // No nodes in this row fit within the viewport.
      if (index == nodes.length) return -1;
      return index;
    }
    // If we don't know the previous start node index, binary search to find the
    // first fitting index (if one exists).
    else {
      final index = lowerBound(
        nodes,
        // Dummy node that has the left edge of the visible viewport.
        FlameChartNode(
          text: null,
          tooltip: null,
          rect: Rect.fromLTRB(
            horizontalScrollOffset,
            0,
            horizontalScrollOffset + 1,
            rowHeightWithPadding,
          ),
          backgroundColor: null,
          textColor: null,
          data: null,
          onSelected: null,
          selectable: false,
        ),
        compare: (FlameChartNode a, FlameChartNode b) =>
            a.rect.left.compareTo(b.rect.left),
      );

      if (index == nodes.length) {
        // If index == nodes.length, then the left edge of all nodes is left of
        // the visible viewport. Check if the last node still overlaps with the
        // viewport, and if so, return the index of the last node. Otherwise,
        // return -1.
        if (index != 0 && nodeFitsInViewport(nodes[index - 1])) {
          return index - 1;
        } else {
          return -1;
        }
      } else if (!nodeFitsInViewport(nodes[index])) {
        // If nodes[index] met the lower bound check but is still not in the
        // viewport, then it must be positioned beyond the right bound of the
        // viewport.
        return -1;
      } else {
        return index;
      }
    }
  }

  bool nodeFitsInViewport(FlameChartNode node) {
    return node.rect.right >= horizontalScrollOffset &&
        node.rect.left - horizontalScrollOffset <= widget.constraints.maxWidth;
  }
}

class FlameChartSection {
  FlameChartSection(
    this.index, {
    @required this.startRow,
    @required this.endRow,
  });

  final int index;

  /// Start row (inclusive) for this section.
  final int startRow;

  /// End row (exclusive) for this section.
  final int endRow;
}

class FlameChartRow {
  final List<FlameChartNode> nodes = [];
}

class FlameChartNode<T> {
  const FlameChartNode({
    this.key,
    @required this.text,
    @required this.tooltip,
    @required this.rect,
    @required this.backgroundColor,
    @required this.textColor,
    @required this.data,
    @required this.onSelected,
    this.selectable = true,
  });

  FlameChartNode.sectionLabel({
    this.key,
    @required this.text,
    @required this.textColor,
    @required this.backgroundColor,
    @required double top,
    @required double width,
  })  : rect = Rect.fromLTRB(rowPadding, top, width, top + rowHeight),
        tooltip = text,
        data = null,
        onSelected = ((_) {}),
        selectable = false;

  static const _selectedNodeColor = mainUiColorSelectedLight;

  final Key key;
  final Rect rect;
  final String text;
  final String tooltip;
  final Color backgroundColor;
  final Color textColor;
  final T data;
  final void Function(T) onSelected;
  final bool selectable;

  Widget buildWidget(bool selected) {
    selected = selectable ? selected : false;
    return Positioned.fromRect(
      key: key,
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

  int _asyncColorOffset = 0;
  Color nextAsyncColor() {
    final color =
        asyncColorPalette[_asyncColorOffset % asyncColorPalette.length];
    _asyncColorOffset++;
    return color;
  }

  int _unknownColorOffset = 0;
  Color nextUnknownColor() {
    final color =
        unknownColorPalette[_unknownColorOffset % unknownColorPalette.length];
    _unknownColorOffset++;
    return color;
  }

  void resetColorOffsets() {
    _asyncColorOffset = 0;
    _uiColorOffset = 0;
    _gpuColorOffset = 0;
    _unknownColorOffset = 0;
  }
}
