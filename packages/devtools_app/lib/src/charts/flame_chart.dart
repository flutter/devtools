// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../extent_delegate_list.dart';
import '../flutter_widgets/linked_scroll_controller.dart';
import '../theme.dart';
import '../ui/colors.dart';
import '../ui/search.dart';
import '../utils.dart';

const double rowPadding = 2.0;
const double rowHeight = 25.0;
const double rowHeightWithPadding = rowHeight + rowPadding;
const double sectionSpacing = 15.0;
const double sideInset = 70.0;
const double sideInsetSmall = 40.0;

// TODO(kenz): add some indication that we are scrolled out of the relevant area
// so that users don't get lost in the extra pixels at the end of the chart.

// TODO(kenz): consider cleaning up by changing to a flame chart code to use a
// composition pattern instead of a class extension pattern.
abstract class FlameChart<T, V> extends StatefulWidget {
  const FlameChart(
    this.data, {
    @required this.time,
    @required this.containerWidth,
    @required this.containerHeight,
    @required this.selectionNotifier,
    @required this.onSelected,
    this.searchMatchesNotifier,
    this.activeSearchMatchNotifier,
    this.startInset = sideInset,
    this.endInset = sideInset,
  });

  static const minZoomLevel = 1.0;
  static const maxZoomLevel = double.infinity;
  static const zoomMultiplier = 0.01;
  static const minScrollOffset = 0.0;
  static const rowOffsetForBottomPadding = 1;
  static const rowOffsetForSectionSpacer = 1;

  /// Maximum scroll delta allowed for scroll wheel based zooming.
  ///
  /// This isn't really needed but is a reasonable for safety in case we
  /// aren't handling some mouse based scroll wheel behavior well, etc.
  static const double maxScrollWheelDelta = 20.0;

  final T data;

  final TimeRange time;

  final double containerWidth;

  final double containerHeight;

  final double startInset;

  final double endInset;

  final ValueListenable<V> selectionNotifier;

  final ValueListenable<List<V>> searchMatchesNotifier;

  final ValueListenable<V> activeSearchMatchNotifier;

  final void Function(V data) onSelected;

  double get startingContentWidth => containerWidth - startInset - endInset;
}

// TODO(kenz): cap number of nodes we can show per row at once - need this for
// performance improvements. Optionally we could also do something clever with
// grouping nodes that are close together until they are zoomed in (quad tree
// like implementation).
abstract class FlameChartState<T extends FlameChart, V> extends State<T>
    with AutoDisposeMixin, FlameChartColorMixin, TickerProviderStateMixin {
  int get rowOffsetForTopPadding => 1;

  // The "top" positional value for each flame chart node will be 0.0 because
  // each node is positioned inside its own list.
  final flameChartNodeTop = 0.0;

  final List<FlameChartRow<V>> rows = [];

  final List<FlameChartSection> sections = [];

  final focusNode = FocusNode();

  bool _altKeyPressed = false;

  double mouseHoverX;

  ScrollController verticalController;

  FixedExtentDelegate verticalExtentDelegate;

  LinkedScrollControllerGroup horizontalController;

  double get maxScrollOffset =>
      widget.containerWidth * (zoomController.value - 1);

  /// Animation controller for animating flame chart zoom changes.
  AnimationController zoomController;

  double previousZoom = FlameChart.minZoomLevel;

  // Scrolling via WASD controls will pan the left/right 25% of the view.
  double get keyboardScrollUnit => widget.containerWidth * 0.25;

  // Zooming in via WASD controls will zoom the view in by 50% on each zoom. For
  // example, if the zoom level is 2.0, zooming by one unit would increase the
  // level to 3.0 (e.g. 2 + (2 * 0.5) = 3).
  double get keyboardZoomInUnit => zoomController.value * 0.5;

  // Zooming out via WASD controls will zoom the view out to the previous zoom
  // level. For example, if the zoom level is 3.0, zooming out by one unit would
  // decrease the level to 2.0 (e.g. 3 - 3 * 1/3 = 2). See [wasdZoomInUnit]
  // for an explanation of how we previously zoomed from level 2.0 to level 3.0.
  double get keyboardZoomOutUnit => zoomController.value * 1 / 3;

  double get contentWidthWithZoom =>
      widget.startingContentWidth * zoomController.value;

  double get widthWithZoom =>
      contentWidthWithZoom + widget.startInset + widget.endInset;

  TimeRange get visibleTimeRange {
    final horizontalScrollOffset = horizontalController.offset;
    final startMicros = horizontalScrollOffset < widget.startInset
        ? startTimeOffset
        : startTimeOffset +
            (horizontalScrollOffset - widget.startInset) /
                zoomController.value /
                startingPxPerMicro;

    final endMicros = startTimeOffset +
        (horizontalScrollOffset - widget.startInset + widget.containerWidth) /
            zoomController.value /
            startingPxPerMicro;

    return TimeRange()
      ..start = Duration(microseconds: startMicros.round())
      ..end = Duration(microseconds: endMicros.round());
  }

  /// Starting pixels per microsecond in order to fit all the data in view at
  /// start.
  double get startingPxPerMicro =>
      widget.startingContentWidth / widget.data.time.duration.inMicroseconds;

  int get startTimeOffset => widget.data.time.start.inMicroseconds;

  /// Provides CustomPaint widgets to be painted on top of the flame chart, if
  /// overridden.
  ///
  /// The painters will be painted in the order that they are returned.
  List<CustomPaint> buildCustomPaints(
    BoxConstraints constraints,
    BuildContext buildContext,
  ) {
    return const [];
  }

  @override
  void initState() {
    super.initState();
    initFlameChartElements();

    horizontalController = LinkedScrollControllerGroup();
    verticalController = ScrollController();

    zoomController = AnimationController(
      value: FlameChart.minZoomLevel,
      lowerBound: FlameChart.minZoomLevel,
      upperBound: FlameChart.maxZoomLevel,
      vsync: this,
    )..addListener(_handleZoomControllerValueUpdate);

    verticalExtentDelegate = FixedExtentDelegate(
      computeExtent: (index) =>
          rows[index].nodes.isEmpty ? sectionSpacing : rowHeightWithPadding,
      computeLength: () => rows.length,
    );

    if (widget.activeSearchMatchNotifier != null) {
      addAutoDisposeListener(widget.activeSearchMatchNotifier, () async {
        final activeSearch = widget.activeSearchMatchNotifier.value;
        if (activeSearch == null) return;

        // Ensure the [activeSearch] is vertically in view.
        if (!isDataVerticallyInView(activeSearch)) {
          await scrollVerticallyToData(activeSearch);
        }

        // TODO(kenz): zoom if the event is less than some min width.

        // Ensure the [activeSearch] is horizontally in view.
        if (!isDataHorizontallyInView(activeSearch)) {
          await scrollHorizontallyToData(activeSearch);
        }
      });
    }
  }

  @override
  void didUpdateWidget(T oldWidget) {
    if (widget.data != oldWidget.data) {
      initFlameChartElements();
      horizontalController.resetScroll();
      verticalController.jumpTo(FlameChart.minScrollOffset);
      previousZoom = FlameChart.minZoomLevel;
      zoomController.reset();
      verticalExtentDelegate.recompute();
    }
    FocusScope.of(context).requestFocus(focusNode);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    verticalController.dispose();
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final customPaints = buildCustomPaints(constraints, context);
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
    );
  }

  Widget _buildFlameChart(BoxConstraints constraints) {
    return ExtentDelegateListView(
      controller: verticalController,
      extentDelegate: verticalExtentDelegate,
      customPointerSignalHandler: _handlePointerSignal,
      childrenDelegate: SliverChildBuilderDelegate(
        (context, index) {
          return ScrollingFlameChartRow<V>(
            linkedScrollControllerGroup: horizontalController,
            nodes: rows[index].nodes,
            width: math.max(constraints.maxWidth, widthWithZoom),
            startInset: widget.startInset,
            selectionNotifier: widget.selectionNotifier,
            searchMatchesNotifier: widget.searchMatchesNotifier,
            activeSearchMatchNotifier: widget.activeSearchMatchNotifier,
            zoom: zoomController.value,
          );
        },
        childCount: rows.length,
        addAutomaticKeepAlives: false,
      ),
    );
  }

  // This method must be overridden by all subclasses.
  @mustCallSuper
  void initFlameChartElements() {
    rows.clear();
    sections.clear();
  }

  void expandRows(int newRowLength) {
    final currentLength = rows.length;
    for (int i = currentLength; i < newRowLength; i++) {
      rows.add(FlameChartRow<V>(i));
    }
  }

  void _handleMouseEnter(PointerEnterEvent event) {
    focusNode.requestFocus();
  }

  void _handleMouseExit(PointerExitEvent event) {
    focusNode.unfocus();
  }

  void _handleMouseHover(PointerHoverEvent event) {
    mouseHoverX = event.localPosition.dx;
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event.isAltPressed) {
      _altKeyPressed = true;
    } else {
      _altKeyPressed = false;
    }

    // Only handle down events so logic is not duplicated on key up.
    if (event is RawKeyDownEvent) {
      // Handle zooming / navigation from W-A-S-D keys.
      final keyLabel = event.data.keyLabel;
      // TODO(kenz): zoom in/out faster if key is held. It actually zooms slower
      // if the key is held currently.
      if (keyLabel == 'w') {
        zoomTo(math.min(
          FlameChart.maxZoomLevel,
          zoomController.value + keyboardZoomInUnit,
        ));
      } else if (keyLabel == 's') {
        zoomTo(math.max(
          FlameChart.minZoomLevel,
          zoomController.value - keyboardZoomOutUnit,
        ));
      } else if (keyLabel == 'a') {
        scrollToX(horizontalController.offset - keyboardScrollUnit);
      } else if (keyLabel == 'd') {
        scrollToX(horizontalController.offset + keyboardScrollUnit);
      }
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) async {
    if (event is PointerScrollEvent) {
      final deltaX = event.scrollDelta.dx;
      double deltaY = event.scrollDelta.dy;
      if (deltaY.abs() >= deltaX.abs()) {
        if (_altKeyPressed) {
          verticalController.jumpTo(verticalController.offset + deltaY);
        } else {
          deltaY = deltaY.clamp(
            -FlameChart.maxScrollWheelDelta,
            FlameChart.maxScrollWheelDelta,
          );
          final currentZoom = zoomController.value;
          // TODO(kenz): if https://github.com/flutter/flutter/issues/52762 is,
          // resolved, consider adjusting the multiplier based on the scroll device
          // kind (mouse or track pad).
          final multiplier = FlameChart.zoomMultiplier * currentZoom;
          final newZoomLevel = (currentZoom + deltaY * multiplier).clamp(
            FlameChart.minZoomLevel,
            FlameChart.maxZoomLevel,
          );
          await zoomTo(newZoomLevel, jump: true);
        }
      }
    }
  }

  void _handleZoomControllerValueUpdate() {
    setState(() {
      final currentZoom = zoomController.value;
      if (currentZoom == previousZoom) return;

      // Store current scroll values for re-calculating scroll location on zoom.
      final lastScrollOffset = horizontalController.offset;

      final safeMouseHoverX = mouseHoverX ?? widget.containerWidth / 2;
      // Position in the zoomable coordinate space that we want to keep fixed.
      final fixedX = safeMouseHoverX + lastScrollOffset - widget.startInset;

      // Calculate the new horizontal scroll position.
      final newScrollOffset = fixedX >= 0
          ? fixedX * currentZoom / previousZoom +
              widget.startInset -
              safeMouseHoverX
          // We are in the fixed portion of the window - no need to transform.
          : lastScrollOffset;

      previousZoom = currentZoom;

      // TODO(kenz): consult with Flutter team to see if there is a better place
      // to call this that guarantees the scroll controller offsets will be
      // updated for the new zoom level and layout size
      // https://github.com/flutter/devtools/issues/2012.
      horizontalController.jumpTo(
          newScrollOffset.clamp(FlameChart.minScrollOffset, maxScrollOffset));
    });
  }

  Future<void> zoomTo(
    double zoom, {
    double forceMouseX,
    bool jump = false,
  }) async {
    if (forceMouseX != null) {
      mouseHoverX = forceMouseX;
    }
    await zoomController.animateTo(
      zoom.clamp(FlameChart.minZoomLevel, FlameChart.maxZoomLevel),
      duration: jump ? Duration.zero : shortDuration,
    );
  }

  FutureOr<void> scrollToX(
    double offset, {
    bool jump = false,
  }) async {
    final target = offset.clamp(FlameChart.minScrollOffset, maxScrollOffset);
    if (jump) {
      horizontalController.jumpTo(target);
    } else {
      await horizontalController.animateTo(
        target,
        curve: defaultCurve,
        duration: shortDuration,
      );
    }
  }

  Future<void> scrollVerticallyToData(V data) async {
    await verticalController.animateTo(
      // Subtract [2 * rowHeightWithPadding] to give the target scroll event top padding.
      (topYForData(data) - 2 * rowHeightWithPadding)
          .clamp(0.0, verticalController.position.maxScrollExtent),
      duration: shortDuration,
      curve: defaultCurve,
    );
  }

  Future<void> scrollHorizontallyToData(V data) async {
    final offset =
        startXForData(data) + widget.startInset - widget.containerWidth * 0.1;
    await scrollToX(offset);
  }

  bool isDataVerticallyInView(V data);

  bool isDataHorizontallyInView(V data);

  double topYForData(V data);

  double startXForData(V data);
}

class ScrollingFlameChartRow<V> extends StatefulWidget {
  const ScrollingFlameChartRow({
    @required this.linkedScrollControllerGroup,
    @required this.nodes,
    @required this.width,
    @required this.startInset,
    @required this.selectionNotifier,
    @required this.searchMatchesNotifier,
    @required this.activeSearchMatchNotifier,
    @required this.zoom,
  });

  final LinkedScrollControllerGroup linkedScrollControllerGroup;

  final List<FlameChartNode<V>> nodes;

  final double width;

  final double startInset;

  final ValueListenable<V> selectionNotifier;

  final ValueListenable<List<V>> searchMatchesNotifier;

  final ValueListenable<V> activeSearchMatchNotifier;

  final double zoom;

  @override
  ScrollingFlameChartRowState<V> createState() =>
      ScrollingFlameChartRowState<V>();
}

class ScrollingFlameChartRowState<V> extends State<ScrollingFlameChartRow>
    with AutoDisposeMixin, SearchableMixin<V> {
  ScrollController scrollController;

  _ScrollingFlameChartRowExtentDelegate extentDelegate;

  /// Convenience getter for widget.nodes.
  List<FlameChartNode<V>> get nodes => widget.nodes;

  List<V> get nodeData => nodes.map((node) => node.data).toList();

  V selected;

  V hovered;

  @override
  void initState() {
    super.initState();
    scrollController = widget.linkedScrollControllerGroup.addAndGet();
    extentDelegate = _ScrollingFlameChartRowExtentDelegate(
      nodeIntervals: nodes.toPaddedZoomedIntervals(
        zoom: widget.zoom,
        chartStartInset: widget.startInset,
        chartWidth: widget.width,
      ),
      zoom: widget.zoom,
      chartStartInset: widget.startInset,
      chartWidth: widget.width,
    );

    selected = widget.selectionNotifier.value;
    addAutoDisposeListener(widget.selectionNotifier, () {
      final containsPreviousSelected = nodeData.contains(selected);
      final containsNewSelected =
          nodeData.contains(widget.selectionNotifier.value);
      selected = widget.selectionNotifier.value;
      // We only want to rebuild the row if it contains the previous or new
      // selected node.
      if (containsPreviousSelected || containsNewSelected) {
        setState(() {});
      }
    });

    if (widget.searchMatchesNotifier != null) {
      searchMatches = widget.searchMatchesNotifier.value;
      addAutoDisposeListener(widget.searchMatchesNotifier, () {
        final previousSearchMatchesInRow =
            searchMatches.where((match) => nodeData.contains(match)).toList();
        final newSearchMatchesInRow = widget.searchMatchesNotifier.value
            .where((match) => nodeData.contains(match))
            .toList();
        searchMatches = widget.searchMatchesNotifier.value;

        // We only want to rebuild the row if it contains the search matches in
        // the row have changed.
        // TODO(kenz): should we check for unordered equality here? Are there
        // performance repercussions for doing so?
        if (!collectionEquals(
            previousSearchMatchesInRow, newSearchMatchesInRow)) {
          setState(() {});
        }
      });
    }

    if (widget.activeSearchMatchNotifier != null) {
      activeSearchMatch = widget.activeSearchMatchNotifier.value;
      addAutoDisposeListener(widget.activeSearchMatchNotifier, () {
        final containsPreviousActiveSearchMatch =
            nodeData.contains(activeSearchMatch);
        final containsNewActiveSearchMatch =
            nodeData.contains(widget.activeSearchMatchNotifier.value);
        activeSearchMatch = widget.activeSearchMatchNotifier.value;
        // We only want to rebuild the row if it contains the previous or new
        // active search match.
        if (containsPreviousActiveSearchMatch || containsNewActiveSearchMatch) {
          setState(() {});
        }
      });
    }
  }

  @override
  void didUpdateWidget(ScrollingFlameChartRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes != widget.nodes ||
        oldWidget.zoom != widget.zoom ||
        oldWidget.width != widget.width ||
        oldWidget.startInset != widget.startInset) {
      extentDelegate.recomputeWith(
        nodeIntervals: nodes.toPaddedZoomedIntervals(
          zoom: widget.zoom,
          chartStartInset: widget.startInset,
          chartWidth: widget.width,
        ),
        zoom: widget.zoom,
        chartStartInset: widget.startInset,
        chartWidth: widget.width,
      );
    }
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
        child: Container(
          height: rowHeightWithPadding,
          width: widget.width,
          color: alternatingColorForIndexWithContext(
            nodes.first.sectionIndex,
            context,
          ),
          // TODO(kenz): investigate if `addAutomaticKeepAlives: false` and
          // `addRepaintBoundaries: false` are needed here for perf improvement.
          child: ExtentDelegateListView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            extentDelegate: extentDelegate,
            childrenDelegate: SliverChildBuilderDelegate(
              (context, index) => _buildFlameChartNode(index),
              childCount: nodes.length,
              addRepaintBoundaries: false,
              addAutomaticKeepAlives: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlameChartNode(int index) {
    final node = nodes[index];
    return Padding(
      padding: EdgeInsets.only(
        left: FlameChartUtils.leftPaddingForNode(
          index,
          nodes,
          chartZoom: widget.zoom,
          chartStartInset: widget.startInset,
        ),
        right: FlameChartUtils.rightPaddingForNode(
          index,
          nodes,
          chartZoom: widget.zoom,
          chartStartInset: widget.startInset,
          chartWidth: widget.width,
        ),
        bottom: rowPadding,
      ),
      child: node.buildWidget(
        selected: node.data == selected,
        hovered: node.data == hovered,
        searchMatch: searchMatches?.contains(node.data) ?? false,
        activeSearchMatch: activeSearchMatch == node.data,
        zoom: FlameChartUtils.zoomForNode(node, widget.zoom),
      ),
    );
  }

  void _handleMouseHover(PointerHoverEvent event) {
    final hoverNodeData =
        binarySearchForNode(event.localPosition.dx - scrollController.offset)
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
      final zoomedNodeRect = node.zoomedRect(widget.zoom, widget.startInset);
      if (x >= zoomedNodeRect.left && x <= zoomedNodeRect.right) {
        return node;
      }
      if (x < zoomedNodeRect.left) {
        max = mid;
      }
      if (x > zoomedNodeRect.right) {
        min = mid + 1;
      }
    }
    return null;
  }

  void _resetHovered() {
    hovered = null;
  }
}

extension NodeListExtension on List<FlameChartNode> {
  List<Range> toPaddedZoomedIntervals({
    @required double zoom,
    @required double chartStartInset,
    @required double chartWidth,
  }) {
    return List<Range>.generate(
      length,
      (index) => FlameChartUtils.paddedZoomedInterval(
        index,
        this,
        chartZoom: zoom,
        chartStartInset: chartStartInset,
        chartWidth: chartWidth,
      ),
    );
  }
}

class FlameChartUtils {
  static double leftPaddingForNode(
    int index,
    List<FlameChartNode> nodes, {
    @required double chartZoom,
    @required double chartStartInset,
  }) {
    final node = nodes[index];
    double padding;
    if (index != 0) {
      padding = 0.0;
    } else if (!node.selectable) {
      padding = node.rect.left;
    } else {
      padding =
          (node.rect.left - chartStartInset) * zoomForNode(node, chartZoom) +
              chartStartInset;
    }
    // Floating point rounding error can result in slightly negative padding.
    return math.max(0.0, padding);
  }

  static double rightPaddingForNode(
    int index,
    List<FlameChartNode> nodes, {
    @required double chartZoom,
    @required double chartStartInset,
    @required double chartWidth,
  }) {
    // TODO(kenz): workaround for https://github.com/flutter/devtools/issues/2012.
    // This is a ridiculous amount of padding but it ensures that we don't hit
    // the issue described in the bug where the scroll extent is smaller than
    // where we want to `jumpTo`. Smaller values were experimented with but the
    // issue still persisted, so we are using a very large number.
    if (index == nodes.length - 1) return 10000000.0;
    final node = nodes[index];
    final nextNode = index == nodes.length - 1 ? null : nodes[index + 1];
    final nodeZoom = zoomForNode(node, chartZoom);
    final nextNodeZoom = zoomForNode(nextNode, chartZoom);

    // Node right with zoom and insets taken into consideration.
    final nodeRight =
        (node.rect.right - chartStartInset) * nodeZoom + chartStartInset;
    final padding = nextNode == null
        ? chartWidth - nodeRight
        : ((nextNode.rect.left - chartStartInset) * nextNodeZoom +
                chartStartInset) -
            nodeRight;
    // Floating point rounding error can result in slightly negative padding.
    return math.max(0.0, padding);
  }

  static double zoomForNode(FlameChartNode node, double chartZoom) {
    return node != null && node.selectable
        ? chartZoom
        : FlameChart.minZoomLevel;
  }

  static Range paddedZoomedInterval(
    int index,
    List<FlameChartNode> nodes, {
    @required double chartZoom,
    @required double chartStartInset,
    @required double chartWidth,
  }) {
    final node = nodes[index];
    final zoomedRect = node.zoomedRect(chartZoom, chartStartInset);
    final leftPadding = leftPaddingForNode(
      index,
      nodes,
      chartZoom: chartZoom,
      chartStartInset: chartStartInset,
    );
    final rightPadding = rightPaddingForNode(
      index,
      nodes,
      chartZoom: chartZoom,
      chartStartInset: chartStartInset,
      chartWidth: chartWidth,
    );
    final left = zoomedRect.left - leftPadding;
    final width = leftPadding + zoomedRect.width + rightPadding;
    return Range(left, left + width);
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

class FlameChartRow<T> {
  FlameChartRow(this.index);

  final List<FlameChartNode<T>> nodes = [];

  final int index;

  /// Adds a node to [nodes] and assigns [this] to the nodes [row] property.
  ///
  /// If [index] is specified and in range of the list, [node] will be added at
  /// [index]. Otherwise, [node] will be added to the end of [nodes]
  void addNode(FlameChartNode<T> node, {int index}) {
    if (index != null && index >= 0 && index < nodes.length) {
      nodes.insert(index, node);
    } else {
      nodes.add(node);
    }
    node.row = this;
  }
}

// TODO(kenz): consider de-coupling this API from the dual background color
// scheme.
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

  static const _darkTextColor = Colors.black;

  // We would like this value to be smaller, but zoom performance does not allow
  // for that. We should decrease this value if we can improve flame chart zoom
  // performance.
  static const _minWidthForText = 30.0;

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
    @required bool searchMatch,
    @required bool activeSearchMatch,
    @required double zoom,
  }) {
    // This math.max call prevents using a rect with negative width for
    // small events that have padding.
    //
    // See https://github.com/flutter/devtools/issues/1503 for details.
    final zoomedWidth = math.max(0.0, rect.width * zoom);

    // TODO(kenz): this is intended to improve performance but can probably be
    // improved. Perhaps we should still show a solid line and fade it out?
    if (zoomedWidth < 0.5) {
      return SizedBox(width: zoomedWidth);
    }

    selected = selectable ? selected : false;
    hovered = selectable ? hovered : false;

    final node = Container(
      key: hovered ? null : key,
      width: zoomedWidth,
      height: rect.height,
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      alignment: Alignment.centerLeft,
      color: _backgroundColor(
        selected: selected,
        searchMatch: searchMatch,
        activeSearchMatch: activeSearchMatch,
      ),
      child: zoomedWidth >= _minWidthForText
          ? Text(
              text,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: _textColor(
                selected: selected,
                searchMatch: searchMatch,
                activeSearchMatch: activeSearchMatch,
              )),
            )
          : const SizedBox(),
    );
    if (hovered || !selectable) {
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

  Color _backgroundColor({
    @required bool selected,
    @required bool searchMatch,
    @required bool activeSearchMatch,
  }) {
    if (selected) return defaultSelectionColor;
    if (activeSearchMatch) return activeSearchMatchColor;
    if (searchMatch) return searchMatchColor;
    return backgroundColor;
  }

  Color _textColor({
    @required bool selected,
    @required bool searchMatch,
    @required bool activeSearchMatch,
  }) {
    if (selected || searchMatch || activeSearchMatch) return _darkTextColor;
    return textColor;
  }

  Rect zoomedRect(double zoom, double chartStartInset) {
    // If a node is not selectable (e.g. section labels "UI", "Raster", etc.), it
    // will not be zoomed, so return the original rect.
    if (!selectable) return rect;

    // These math.max calls prevent using a rect with negative width for
    // small events that have padding.
    //
    // See https://github.com/flutter/devtools/issues/1503 for details.
    final zoomedLeft =
        math.max(0.0, (rect.left - chartStartInset) * zoom + chartStartInset);
    final zoomedWidth = math.max(0.0, rect.width * zoom);
    return Rect.fromLTWH(zoomedLeft, rect.top, zoomedWidth, rect.height);
  }
}

mixin FlameChartColorMixin {
  Color nextUiColor(int row) {
    return uiColorPalette[row % uiColorPalette.length];
  }

  Color nextRasterColor(int row) {
    return rasterColorPalette[row % rasterColorPalette.length];
  }

  Color nextAsyncColor(int row) {
    return asyncColorPalette[row % asyncColorPalette.length];
  }

  Color nextUnknownColor(int row) {
    return unknownColorPalette[row % unknownColorPalette.length];
  }
}

/// [ExtentDelegate] implementation for the case where size and position is
/// known for each list item.
class _ScrollingFlameChartRowExtentDelegate extends ExtentDelegate {
  _ScrollingFlameChartRowExtentDelegate({
    @required this.nodeIntervals,
    @required this.zoom,
    @required this.chartStartInset,
    @required this.chartWidth,
  }) {
    recompute();
  }

  List<Range> nodeIntervals = [];

  double zoom;

  double chartStartInset;

  double chartWidth;

  void recomputeWith({
    @required List<Range> nodeIntervals,
    @required double zoom,
    @required double chartStartInset,
    @required double chartWidth,
  }) {
    this.nodeIntervals = nodeIntervals;
    this.zoom = zoom;
    this.chartStartInset = chartStartInset;
    this.chartWidth = chartWidth;
    recompute();
  }

  @override
  double itemExtent(int index) {
    if (index >= length) return 0;
    return nodeIntervals[index].size;
  }

  @override
  double layoutOffset(int index) {
    if (index <= 0) return 0.0;
    if (index >= length) return nodeIntervals.last.end;
    return nodeIntervals[index].begin;
  }

  @override
  int get length => nodeIntervals.length;

  @override
  int minChildIndexForScrollOffset(double scrollOffset) {
    final boundInterval = Range(scrollOffset, scrollOffset + 1);
    int index = lowerBound(
      nodeIntervals,
      boundInterval,
      compare: (Range a, Range b) => a.begin.compareTo(b.begin),
    );
    if (index == 0) return 0;
    if (index >= nodeIntervals.length ||
        (nodeIntervals[index].begin - scrollOffset).abs() >
            precisionErrorTolerance) {
      index--;
    }
    assert(
        nodeIntervals[index].begin <= scrollOffset + precisionErrorTolerance);
    return index;
  }

  @override
  int maxChildIndexForScrollOffset(double endScrollOffset) {
    final boundInterval = Range(endScrollOffset, endScrollOffset + 1);
    int index = lowerBound(
      nodeIntervals,
      boundInterval,
      compare: (Range a, Range b) => a.begin.compareTo(b.begin),
    );
    if (index == 0) return 0;
    index--;
    assert(nodeIntervals[index].begin < endScrollOffset);
    return index;
  }
}

abstract class FlameChartPainter extends CustomPainter {
  FlameChartPainter({
    @required this.zoom,
    @required this.constraints,
    @required this.verticalController,
    @required this.horizontalController,
    @required this.chartStartInset,
    @required this.colorScheme,
  })  : assert(colorScheme != null),
        super(
            repaint: Listenable.merge([
          verticalController,
          horizontalController.offsetNotifier,
        ]));

  final double zoom;

  final BoxConstraints constraints;

  final ScrollController verticalController;

  final LinkedScrollControllerGroup horizontalController;

  final double chartStartInset;

  /// The absolute coordinates of the flame chart's visible section.
  Rect get visibleRect {
    return Rect.fromLTWH(
      horizontalController.offset,
      verticalController.offset,
      constraints.maxWidth,
      constraints.maxHeight,
    );
  }

  final ColorScheme colorScheme;

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is FlameChartPainter) {
      return verticalController != oldDelegate.verticalController ||
          horizontalController != oldDelegate.horizontalController ||
          constraints != oldDelegate.constraints ||
          zoom != oldDelegate.zoom ||
          chartStartInset != oldDelegate.chartStartInset ||
          oldDelegate.colorScheme != colorScheme;
    }
    return true;
  }
}
