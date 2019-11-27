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
          addAutomaticKeepAlives: false,
          itemCount: rows.length,
          itemBuilder: (context, index) {
            return ScrollingFlameChartRow<V>(
              linkedScrollControllerGroup: _linkedScrollControllerGroup,
              nodes: rows[index].nodes,
              width: math.max(constraints.maxWidth, widget.totalStartingWidth),
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

  void expandRows(int newRowLength) {
    final currentLength = rows.length;
    for (int i = currentLength; i < newRowLength; i++) {
      rows.add(FlameChartRow());
    }
  }
}

class ScrollingFlameChartRow<V> extends StatefulWidget {
  const ScrollingFlameChartRow({
    @required this.linkedScrollControllerGroup,
    @required this.nodes,
    @required this.width,
    @required this.selected,
  });

  final LinkedScrollControllerGroup linkedScrollControllerGroup;

  final List<FlameChartNode> nodes;

  final double width;

  final V selected;

  @override
  _ScrollingFlameChartRowState createState() => _ScrollingFlameChartRowState();
}

class _ScrollingFlameChartRowState extends State<ScrollingFlameChartRow>
    with AutoDisposeMixin {
  ScrollController scrollController;

  /// Convenience getter for widget.nodes.
  List<FlameChartNode> get nodes => widget.nodes;

  @override
  void initState() {
    super.initState();
    scrollController = widget.linkedScrollControllerGroup.addAndGet();
  }

  @override
  void didUpdateWidget(ScrollingFlameChartRow oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return nodes.isEmpty
        ? SizedBox(
            height: sectionSpacing,
            width: widget.width,
          )
        : SizedBox(
            height: rowHeightWithPadding,
            width: widget.width,
            child: ListView.builder(
              addAutomaticKeepAlives: false,
              // The flame chart nodes are inexpensive to paint, so removing the
              // repaint boundary improves efficiency.
              addRepaintBoundaries: false,
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: nodes.length,
              itemBuilder: (context, index) {
                final node = nodes[index];
                final nextNode =
                    index == nodes.length - 1 ? null : nodes[index + 1];
                final paddingLeft = index == 0 ? node.rect.left : 0.0;
                final paddingRight = nextNode == null
                    ? widget.width - node.rect.right
                    : nextNode.rect.left - node.rect.right;
                return Padding(
                  padding: EdgeInsets.only(
                    left: paddingLeft,
                    right: paddingRight,
                    bottom: rowPadding,
                  ),
                  child: node.buildWidget(node.data == widget.selected),
                );
              },
            ),
          );
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
    return Tooltip(
      message: tooltip,
      waitDuration: tooltipWait,
      preferBelow: false,
      child: GestureDetector(
        onTap: () => onSelected(data),
        child: Container(
          width: rect.width,
          height: rect.height,
          padding: const EdgeInsets.only(left: 6.0),
          alignment: Alignment.centerLeft,
          color: selected ? _selectedNodeColor : backgroundColor,
          child: rect.width > 10.0
              ? Text(
                  text,
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.black : textColor,
                  ),
                )
              : const SizedBox(),
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
