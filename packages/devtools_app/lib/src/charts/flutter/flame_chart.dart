// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';

import '../../flutter/common_widgets.dart';
import '../../ui/colors.dart';
import '../../ui/fake_flutter/_real_flutter.dart';

const double rowPadding = 2.0;
const double rowHeight = 25.0;
const double rowHeightWithPadding = rowHeight + rowPadding;
const double sectionSpacing = 15.0;
const double topOffset = rowHeightWithPadding;
const double sideInset = 70.0;

abstract class FlameChart<T, V> extends StatefulWidget {
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

mixin FlameChartStateMixin<T extends FlameChart> on State<T> {
  static const startingScrollPosition = 0.0;
  ScrollController scrollControllerX;
  ScrollController scrollControllerY;
  double scrollOffsetX = startingScrollPosition;
  double scrollOffsetY = startingScrollPosition;

  List<FlameChartRow> rows;

  @override
  void initState() {
    super.initState();

    // TODO(kenz): improve this so we are not rebuilding on every scroll.
    scrollControllerX = ScrollController()
      ..addListener(() {
        setState(() {
          scrollOffsetX = scrollControllerX.offset;
        });
      });

    scrollControllerY = ScrollController()
      ..addListener(() {
        setState(() {
          scrollOffsetY = scrollControllerY.offset;
        });
      });
  }

  @override
  void didUpdateWidget(T oldWidget) {
    if (widget.data != oldWidget.data) {
      scrollControllerX.jumpTo(startingScrollPosition);
      scrollControllerY.jumpTo(startingScrollPosition);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    scrollControllerX.dispose();
    scrollControllerY.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): switch to creating a list of scroll views with a linked
    // scroll controller.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          child: SingleChildScrollView(
            controller: scrollControllerX,
            scrollDirection: Axis.horizontal,
            child: Scrollbar(
              child: SingleChildScrollView(
                controller: scrollControllerY,
                scrollDirection: Axis.vertical,
                child: buildFlameChartBody(constraints),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildFlameChartBody(BoxConstraints constraints);

  List<FlameChartNode> nodesInViewport(BoxConstraints constraints) {
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
}

class FlameChartRow {
  const FlameChartRow({
    @required this.nodes,
    @required this.index,
  });

  final List<FlameChartNode> nodes;
  final int index;
}

class FlameChartNode<T> extends StatelessWidget {
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
