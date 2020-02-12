// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widgets/flutter_widgets.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/theme.dart';
import '../../ui/colors.dart';
import '../../ui/fake_flutter/_real_flutter.dart';
import '../../utils.dart';

const double rowPadding = 2.0;
const double rowHeight = 25.0;
const double rowHeightWithPadding = rowHeight + rowPadding;
const double sectionSpacing = 15.0;
const double sideInset = 70.0;
const double sideInsetSmall = 40.0;

// TODO(kenz): remove the hard coded hack once
// https://github.com/flutter/flutter/issues/33675 is fixed.
// [PointerHoverEvent.localPosition] is actually the absolute position right
// now, so for mouse position detection in the flame chart container, we use
// this offset. Use `localPosition` once this is fixed.
const flameChartContainerOffset = 33.0;

// TODO(kenz): consider cleaning up by changing to a flame chart code to use a
// composition pattern instead of a class extension pattern.
abstract class FlameChart<T, V> extends StatefulWidget {
  const FlameChart(
    this.data, {
    @required this.time,
    @required this.totalStartingWidth,
    @required this.selected,
    @required this.onSelected,
    this.startInset = sideInset,
    this.endInset = sideInset,
  });

  final T data;

  final TimeRange time;

  final double totalStartingWidth;

  final double startInset;

  final double endInset;

  final V selected;

  final void Function(V data) onSelected;

  double get startingContentWidth => totalStartingWidth - startInset - endInset;
}

abstract class FlameChartState<T extends FlameChart, V> extends State<T>
    with AutoDisposeMixin, FlameChartColorMixin, TickerProviderStateMixin {
  static const minZoomLevel = 1.0;
  static const maxZoomLevel = 100.0;
  static const minScrollOffset = 0.0;

  final rowOffsetForBottomPadding = 1;
  final rowOffsetForSectionSpacer = 1;

  int get rowOffsetForTopPadding => 2;

  // The "top" positional value for each flame chart node will be 0.0 because
  // each node is positioned inside its own list.
  final flameChartNodeTop = 0.0;

  final List<FlameChartRow> rows = [];

  final List<FlameChartSection> sections = [];

  final focusNode = FocusNode();

  bool _shiftKeyPressed = false;

  double mouseHoverX;

  ScrollController verticalScrollController;

  LinkedScrollControllerGroup linkedHorizontalScrollControllerGroup;

  double get maxScrollOffset =>
      widget.totalStartingWidth * (zoomController.value - 1);

  double linkedScrollGroupCacheExtent;

  /// Animation controller for animating flame chart zoom changes.
  AnimationController zoomController;

  double previousZoom = minZoomLevel;

  double verticalScrollOffset = 0.0;

  double horizontalScrollOffset = 0.0;

  // Scrolling via WASD controls will pan the left/right 25% of the view.
  double get keyboardScrollUnit => widget.totalStartingWidth * 0.25;

  // Zooming in via WASD controls will zoom the view in by 50% on each zoom. For
  // example, if the zoom level is 2.0, zooming by one unit would increase the
  // level to 3.0 (e.g. 2 + (2 * 0.5) = 3).
  double get keyboardZoomInUnit => zoomController.value * 0.5;

  // Zooming out via WASD controls will zoom the view out to the previous zoom
  // level. For example, if the zoom level is 3.0, zooming out by one unit would
  // decrease the level to 2.0 (e.g. 3 - 3 * 1/3 = 2). See [wasdZoomInUnit]
  // for an explanation of how we previously zoomed from level 2.0 to level 3.0.
  double get keyboardZoomOutUnit => zoomController.value * 1 / 3;

  double get widthWithZoom =>
      widget.startingContentWidth * zoomController.value +
      widget.startInset +
      widget.endInset;

  /// Starting pixels per microsecond in order to fit all the data in view at
  /// start.
  double get startingPxPerMicro =>
      widget.startingContentWidth / widget.data.time.duration.inMicroseconds;

  int get startTimeOffset => widget.data.time.start.inMicroseconds;

  /// Provides CustomPaint widgets to be painted on top of the flame chart, if
  /// overridden.
  ///
  /// The painters will be painted in the order that they are returned.
  List<CustomPaint> buildCustomPaints(BoxConstraints constraints) => [];

  @override
  void initState() {
    super.initState();
    initFlameChartElements();

    linkedHorizontalScrollControllerGroup = LinkedScrollControllerGroup()
      ..addOffsetChangedListener(() {
        setState(() {
          horizontalScrollOffset = linkedHorizontalScrollControllerGroup.offset;
        });
      });
    verticalScrollController = ScrollController()
      ..addListener(() {
        if (verticalScrollOffset != verticalScrollController.offset) {
          setState(() {
            verticalScrollOffset = verticalScrollController.offset;
          });
        }
      });

    zoomController = AnimationController(
      value: minZoomLevel,
      lowerBound: minZoomLevel,
      upperBound: maxZoomLevel,
      vsync: this,
    )
      ..addStatusListener(_handleZoomControllerStatusChange)
      ..addListener(_handleZoomControllerValueUpdate);
  }

  @override
  void didUpdateWidget(T oldWidget) {
    if (widget.data != oldWidget.data) {
      initFlameChartElements();
      linkedHorizontalScrollControllerGroup.resetScroll();
      verticalScrollController.jumpTo(minScrollOffset);
      previousZoom = minZoomLevel;
      zoomController.reset();
    }
    FocusScope.of(context).requestFocus(focusNode);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    verticalScrollController.dispose();
    zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): handle tooltips hover here instead of wrapping each row in a
    // MouseRegion widget.
    return MouseRegion(
      onEnter: _handleMouseEnter,
      onExit: _handleMouseExit,
      onHover: _handleMouseHover,
      child: RawKeyboardListener(
        focusNode: focusNode,
        onKey: (event) => _handleKeyEvent(event),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: (event) => _handlePointerSignal(event),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final customPaints = buildCustomPaints(constraints);
              final flameChart = _buildFlameChart(constraints);
              return customPaints.isNotEmpty
                  ? Stack(
                      children: [
                        flameChart,
                        ...customPaints,
                      ],
                    )
                  : flameChart;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFlameChart(BoxConstraints constraints) {
    return ListView.builder(
      controller: verticalScrollController,
      addAutomaticKeepAlives: false,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        // TODO(kenz): investigate if we are building too many
        // ScrollingFlameChartRow widgets on zoom / pan.
        return ScrollingFlameChartRow<V>(
          linkedScrollControllerGroup: linkedHorizontalScrollControllerGroup,
          nodes: rows[index].nodes,
          width: math.max(constraints.maxWidth, widthWithZoom),
          startInset: widget.startInset,
          selected: widget.selected,
          zoom: zoomController.value,
          cacheExtent: linkedScrollGroupCacheExtent,
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
      rows.add(FlameChartRow(i));
    }
  }

  void _handleMouseEnter(PointerEnterEvent event) {
    focusNode.requestFocus();
  }

  void _handleMouseExit(PointerExitEvent event) {
    focusNode.unfocus();
  }

  void _handleMouseHover(PointerHoverEvent event) {
    mouseHoverX = event.position.dx - flameChartContainerOffset;
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event.isShiftPressed) {
      _shiftKeyPressed = true;
    } else {
      _shiftKeyPressed = false;
    }

    // Only handle down events so logic is not duplicated on key up.
    if (event is RawKeyDownEvent) {
      // Handle zooming / navigation from W-A-S-D keys.
      final keyLabel = event.data.keyLabel;
      // TODO(kenz): zoom in/out faster if key is held. It actually zooms slower
      // if the key is held currently.
      if (keyLabel == 'w') {
        _zoomTo(
            math.min(maxZoomLevel, zoomController.value + keyboardZoomInUnit));
      } else if (keyLabel == 's') {
        _zoomTo(
            math.max(minZoomLevel, zoomController.value - keyboardZoomOutUnit));
      } else if (keyLabel == 'a') {
        _scrollTo(
            linkedHorizontalScrollControllerGroup.offset - keyboardScrollUnit);
      } else if (keyLabel == 'd') {
        _scrollTo(
            linkedHorizontalScrollControllerGroup.offset + keyboardScrollUnit);
      }
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (_shiftKeyPressed) {
        // TODO(kenz): scroll vertical list regularly / zoom. See
        // https://github.com/flutter/devtools/issues/1600.
      } else {
        // TODO(kenz): scroll vertical list regularly / zoom. See
        // https://github.com/flutter/devtools/issues/1600.
      }
    }
  }

  void _handleZoomControllerStatusChange(AnimationStatus status) {
    // We set [linkedScrollGroupCacheExtent] based on the state of the
    // animation because we need to know the size of off screen widgets as we
    // zoom.
    if (status == AnimationStatus.forward &&
        linkedScrollGroupCacheExtent !=
            linkedHorizontalScrollControllerGroup.offset) {
      setState(() {
        // Set the cache extent to the offset of the scroll group so
        // that the size of the off-screen elements are not lost on
        // zoom.
        linkedScrollGroupCacheExtent = linkedHorizontalScrollControllerGroup
            .offset
            .clamp(minScrollOffset, maxScrollOffset);
      });
    }
    if (status == AnimationStatus.completed &&
        linkedScrollGroupCacheExtent != null) {
      setState(() {
        // If [zoomController] is no longer animating, reset the cache
        // extent so that we are not building unnecessary widgets on
        // scroll.
        linkedScrollGroupCacheExtent = null;
      });
    }
  }

  void _handleZoomControllerValueUpdate() {
    setState(() {
      final currentZoom = zoomController.value;
      if (currentZoom == previousZoom) return;

      // Store current scroll values for re-calculating scroll location on zoom.
      final lastScrollOffset = linkedHorizontalScrollControllerGroup.offset;

      // Position in the zoomable coordinate space that we want to keep fixed.
      final fixedX = mouseHoverX + lastScrollOffset - widget.startInset;

      // Calculate the new horizontal scroll position.
      final newScrollOffset = fixedX >= 0
          ? fixedX * currentZoom / previousZoom +
              widget.startInset -
              mouseHoverX
          // We are in the fixed portion of the window - no need to transform.
          : lastScrollOffset;

      previousZoom = currentZoom;
      linkedHorizontalScrollControllerGroup
          .jumpTo(newScrollOffset.clamp(minScrollOffset, maxScrollOffset));
    });
  }

  void _zoomTo(double zoom) {
    zoomController.animateTo(zoom, duration: defaultDuration);
  }

  void _scrollTo(double offset) {
    linkedHorizontalScrollControllerGroup.animateTo(
      offset.clamp(minScrollOffset, maxScrollOffset),
      curve: defaultCurve,
      duration: defaultDuration,
    );
  }
}

class ScrollingFlameChartRow<V> extends StatefulWidget {
  const ScrollingFlameChartRow({
    @required this.linkedScrollControllerGroup,
    @required this.nodes,
    @required this.width,
    @required this.startInset,
    @required this.selected,
    @required this.zoom,
    @required this.cacheExtent,
  });

  final LinkedScrollControllerGroup linkedScrollControllerGroup;

  final List<FlameChartNode> nodes;

  final double width;

  final double startInset;

  final V selected;

  final double zoom;

  final double cacheExtent;

  @override
  ScrollingFlameChartRowState<V> createState() =>
      ScrollingFlameChartRowState<V>();
}

class ScrollingFlameChartRowState<V> extends State<ScrollingFlameChartRow>
    with AutoDisposeMixin {
  ScrollController scrollController;

  /// Convenience getter for widget.nodes.
  List<FlameChartNode> get nodes => widget.nodes;

  V hovered;

  @override
  void initState() {
    super.initState();
    scrollController = widget.linkedScrollControllerGroup.addAndGet();
  }

  @override
  void didUpdateWidget(ScrollingFlameChartRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resetHovered();
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
    _resetHovered();
  }

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return SizedBox(
        height: sectionSpacing,
        width: widget.width,
      );
    }
    // Having each row handle gestures and mouse events instead of each node
    // handling its own improves performance.
    return MouseRegion(
      onHover: _handleMouseHover,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _handleTapUp,
        child: SizedBox(
          height: rowHeightWithPadding,
          width: widget.width,
          child: ListView.builder(
            addAutomaticKeepAlives: false,
            // The flame chart nodes are inexpensive to paint, so removing the
            // repaint boundary improves efficiency.
            addRepaintBoundaries: false,
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            cacheExtent: widget.cacheExtent,
            itemCount: nodes.length,
            itemBuilder: (context, index) => _buildFlameChartNode(index),
          ),
        ),
      ),
    );
  }

  Widget _buildFlameChartNode(int index) {
    final node = nodes[index];
    return Padding(
      padding: EdgeInsets.only(
        left: leftPaddingForNode(index),
        right: rightPaddingForNode(index),
        bottom: rowPadding,
      ),
      child: node.buildWidget(
        selected: node.data == widget.selected,
        hovered: node.data == hovered,
        zoom: _zoomForNode(node),
      ),
    );
  }

  @visibleForTesting
  double leftPaddingForNode(int index) {
    final node = nodes[index];
    if (index != 0) {
      return 0.0;
    } else if (!node.selectable) {
      return node.rect.left;
    } else {
      return (node.rect.left - widget.startInset) * _zoomForNode(node) +
          widget.startInset;
    }
  }

  @visibleForTesting
  double rightPaddingForNode(int index) {
    final node = nodes[index];
    final nextNode = index == nodes.length - 1 ? null : nodes[index + 1];
    final nodeZoom = _zoomForNode(node);
    final nextNodeZoom = _zoomForNode(nextNode);

    // Node right with zoom and insets taken into consideration.
    final nodeRight =
        (node.rect.right - widget.startInset) * nodeZoom + widget.startInset;
    return nextNode == null
        ? widget.width - nodeRight
        : ((nextNode.rect.left - widget.startInset) * nextNodeZoom +
                widget.startInset) -
            nodeRight;
  }

  double _zoomForNode(FlameChartNode node) {
    return node != null && node.selectable
        ? widget.zoom
        : FlameChartState.minZoomLevel;
  }

  void _handleMouseHover(PointerHoverEvent event) {
    final hoverNodeData = binarySearchForNode(event.position.dx -
            flameChartContainerOffset +
            scrollController.offset)
        ?.data;

    if (hoverNodeData != hovered) {
      setState(() {
        hovered = hoverNodeData;
      });
    }
  }

  void _handleTapUp(TapUpDetails details) {
    final RenderBox referenceBox = context.findRenderObject();
    final tapPosition = referenceBox.globalToLocal(details.globalPosition);
    final nodeToSelect =
        binarySearchForNode(tapPosition.dx + scrollController.offset);
    if (nodeToSelect != null) {
      nodeToSelect.onSelected(nodeToSelect.data);
    }
  }

  @visibleForTesting
  FlameChartNode binarySearchForNode(double x) {
    int min = 0;
    int max = nodes.length;
    while (min < max) {
      final mid = min + ((max - min) >> 1);
      final node = nodes[mid];
      if (x >= node.rect.left && x <= node.rect.right) {
        return node;
      }
      if (x < node.rect.left) {
        max = mid;
      }
      if (x > node.rect.right) {
        min = mid + 1;
      }
    }
    return null;
  }

  void _resetHovered() {
    hovered = null;
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
  FlameChartRow(this.index);

  final List<FlameChartNode> nodes = [];

  final int index;

  /// Adds a node to [nodes] and assigns [this] to the nodes [row] property.
  ///
  /// If [index] is specified and in range of the list, [node] will be added at
  /// [index]. Otherwise, [node] will be added to the end of [nodes]
  void addNode(FlameChartNode node, {int index}) {
    if (index != null && index >= 0 && index < nodes.length) {
      nodes.insert(index, node);
    } else {
      nodes.add(node);
    }
    node.row = this;
  }
}

class FlameChartNode<T> {
  FlameChartNode({
    this.key,
    @required this.text,
    @required this.tooltip,
    @required this.rect,
    @required this.backgroundColor,
    @required this.textColor,
    @required this.data,
    @required this.onSelected,
    this.selectable = true,
    this.sectionIndex,
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

  static const _minWidthForText = 22.0;

  final Key key;
  final Rect rect;
  final String text;
  final String tooltip;
  final Color backgroundColor;
  final Color textColor;
  final T data;
  final void Function(T) onSelected;
  final bool selectable;

  FlameChartRow row;

  int sectionIndex;

  Widget buildWidget({
    @required bool selected,
    @required bool hovered,
    @required double zoom,
  }) {
    selected = selectable ? selected : false;
    hovered = selectable ? hovered : false;

    final node = Container(
      key: hovered ? null : key,
      // This math.max call prevents using a rect with negative width for
      // small events that have padding.
      //
      // See https://github.com/flutter/devtools/issues/1503 for details.
      width: math.max(0.0, rect.width * zoom),
      height: rect.height,
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      alignment: Alignment.centerLeft,
      color: selected ? _selectedNodeColor : backgroundColor,
      child: rect.width * zoom >= _minWidthForText
          ? Text(
              text,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.black : textColor,
              ),
            )
          : const SizedBox(),
    );
    if (hovered) {
      return Tooltip(
        key: key,
        message: tooltip,
        preferBelow: false,
        waitDuration: tooltipWait,
        child: node,
      );
    } else {
      return node;
    }
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
