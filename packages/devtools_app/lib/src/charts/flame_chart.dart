// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe, unnecessary_null_comparison

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analytics/analytics.dart' as ga;
import '../primitives/auto_dispose_mixin.dart';
import '../primitives/extent_delegate_list.dart';
import '../primitives/flutter_widgets/linked_scroll_controller.dart';
import '../primitives/trees.dart';
import '../primitives/utils.dart';
import '../shared/common_widgets.dart';
import '../shared/dialogs.dart';
import '../shared/theme.dart';
import '../shared/utils.dart';
import '../ui/colors.dart';
import '../ui/search.dart';
import '../ui/utils.dart';

const double rowPadding = 2.0;
// Flame chart rows contain text so are not readable if they do not scale with
// the font factor.
double get rowHeight => scaleByFontFactor(22.0);
double get rowHeightWithPadding => rowHeight + rowPadding;

// This spacing needs to be scaled by the font factor otherwise section
// labels will not have enough room. Typically spacing values should not depend
// on the font size scale factor. TODO(jacobr): clean up the section spacing so
// it is not used in a case where it is not really spacing.
double get sectionSpacing => scaleByFontFactor(16.0);
const double sideInset = 70.0;
const double sideInsetSmall = 60.0;

double get baseTimelineGridIntervalPx => scaleByFontFactor(150.0);

// TODO(kenz): add some indication that we are scrolled out of the relevant area
// so that users don't get lost in the extra pixels at the end of the chart.

// TODO(kenz): consider cleaning up by changing to a flame chart code to use a
// composition pattern instead of a class extension pattern.
abstract class FlameChart<T, V> extends StatefulWidget {
  const FlameChart(
    this.data, {
    required this.time,
    required this.containerWidth,
    required this.containerHeight,
    required this.selectionNotifier,
    required this.onDataSelected,
    this.searchMatchesNotifier,
    this.activeSearchMatchNotifier,
    this.startInset = sideInset,
    this.endInset = sideInset,
  });

  static const minZoomLevel = 1.0;
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

  final ValueListenable<List<V>>? searchMatchesNotifier;

  final ValueListenable<V?>? activeSearchMatchNotifier;

  final void Function(V data) onDataSelected;

  double get startingContentWidth => containerWidth - startInset - endInset;
}

// TODO(kenz): cap number of nodes we can show per row at once - need this for
// performance improvements. Optionally we could also do something clever with
// grouping nodes that are close together until they are zoomed in (quad tree
// like implementation).
abstract class FlameChartState<T extends FlameChart,
        V extends FlameChartDataMixin<V>> extends State<T>
    with AutoDisposeMixin, FlameChartColorMixin, TickerProviderStateMixin {
  int get rowOffsetForTopPadding => 2;

  // The "top" positional value for each flame chart node will be 0.0 because
  // each node is positioned inside its own list.
  final flameChartNodeTop = 0.0;

  final List<FlameChartRow<V>> rows = [];

  final List<FlameChartSection> sections = [];

  final focusNode = FocusNode(debugLabel: 'flame-chart');

  bool _altKeyPressed = false;

  double? mouseHoverX;

  late final FixedExtentDelegate verticalExtentDelegate;

  late final LinkedScrollControllerGroup verticalControllerGroup;

  late final LinkedScrollControllerGroup horizontalControllerGroup;

  late final ScrollController _flameChartScrollController;

  /// Animation controller for animating flame chart zoom changes.
  @visibleForTesting
  late final AnimationController zoomController;

  double currentZoom = FlameChart.minZoomLevel;

  double horizontalScrollOffset = FlameChart.minScrollOffset;

  double verticalScrollOffset = FlameChart.minScrollOffset;

  // Scrolling via WASD controls will pan the left/right 25% of the view.
  double get keyboardScrollUnit => widget.containerWidth * 0.25;

  // Zooming in via WASD controls will zoom the view in by 50% on each zoom. For
  // example, if the zoom level is 2.0, zooming by one unit would increase the
  // level to 3.0 (e.g. 2 + (2 * 0.5) = 3).
  double get keyboardZoomInUnit => currentZoom * 0.5;

  // Zooming out via WASD controls will zoom the view out to the previous zoom
  // level. For example, if the zoom level is 3.0, zooming out by one unit would
  // decrease the level to 2.0 (e.g. 3 - 3 * 1/3 = 2). See [wasdZoomInUnit]
  // for an explanation of how we previously zoomed from level 2.0 to level 3.0.
  double get keyboardZoomOutUnit => currentZoom * 1 / 3;

  double get contentWidthWithZoom => widget.startingContentWidth * currentZoom;

  double get widthWithZoom =>
      contentWidthWithZoom + widget.startInset + widget.endInset;

  TimeRange get visibleTimeRange {
    final horizontalScrollOffset = horizontalControllerGroup.offset;
    final startMicros = horizontalScrollOffset < widget.startInset
        ? startTimeOffset
        : startTimeOffset +
            (horizontalScrollOffset - widget.startInset) /
                currentZoom /
                startingPxPerMicro;

    final endMicros = startTimeOffset +
        (horizontalScrollOffset - widget.startInset + widget.containerWidth) /
            currentZoom /
            startingPxPerMicro;

    return TimeRange()
      ..start = Duration(microseconds: startMicros.round())
      ..end = Duration(microseconds: endMicros.round());
  }

  /// Starting pixels per microsecond in order to fit all the data in view at
  /// start.
  double get startingPxPerMicro =>
      widget.startingContentWidth / widget.time.duration.inMicroseconds;

  int get startTimeOffset => widget.time.start!.inMicroseconds;

  double get maxZoomLevel {
    // The max zoom level is hit when 1 microsecond is the width of each grid
    // interval (this may bottom out at 2 micros per interval due to rounding).
    return baseTimelineGridIntervalPx *
        widget.time.duration.inMicroseconds /
        widget.startingContentWidth;
  }

  /// Provides widgets to be layered on top of the flame chart, if overridden.
  ///
  /// The widgets will be layered in a [Stack] in the order that they are
  /// returned.
  List<Widget> buildChartOverlays(
    BoxConstraints constraints,
    BuildContext buildContext,
  ) {
    return const [];
  }

  @override
  void initState() {
    super.initState();
    initFlameChartElements();

    horizontalControllerGroup = LinkedScrollControllerGroup();
    verticalControllerGroup = LinkedScrollControllerGroup();

    addAutoDisposeListener(horizontalControllerGroup.offsetNotifier, () {
      setState(() {
        horizontalScrollOffset = horizontalControllerGroup.offset;
      });
    });
    addAutoDisposeListener(verticalControllerGroup.offsetNotifier, () {
      setState(() {
        verticalScrollOffset = verticalControllerGroup.offset;
      });
    });

    _flameChartScrollController = verticalControllerGroup.addAndGet();

    zoomController = AnimationController(
      value: FlameChart.minZoomLevel,
      lowerBound: FlameChart.minZoomLevel,
      upperBound: maxZoomLevel,
      vsync: this,
    )..addListener(_handleZoomControllerValueUpdate);

    verticalExtentDelegate = FixedExtentDelegate(
      computeExtent: (index) =>
          rows[index].nodes.isEmpty ? sectionSpacing : rowHeightWithPadding,
      computeLength: () => rows.length,
    );

    if (widget.activeSearchMatchNotifier != null) {
      addAutoDisposeListener(widget.activeSearchMatchNotifier, () async {
        final activeSearch = widget.activeSearchMatchNotifier as V?;
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

    autoDisposeFocusNode(focusNode);
  }

  @override
  void didUpdateWidget(T oldWidget) {
    if (widget.data != oldWidget.data) {
      initFlameChartElements();
      horizontalControllerGroup.resetScroll();
      verticalControllerGroup.resetScroll();
      zoomController.reset();
      verticalExtentDelegate.recompute();
    }
    FocusScope.of(context).requestFocus(focusNode);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): handle tooltips hover here instead of wrapping each row in a
    // MouseRegion widget.
    return MouseRegion(
      onHover: _handleMouseHover,
      child: RawKeyboardListener(
        autofocus: true,
        focusNode: focusNode,
        onKey: (event) => _handleKeyEvent(event),
        // Scrollbar needs to wrap [LayoutBuilder] so that the scroll bar is
        // rendered on top of the custom painters defined in [buildCustomPaints]
        child: Scrollbar(
          controller: _flameChartScrollController,
          isAlwaysShown: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartOverlays = buildChartOverlays(constraints, context);
              final flameChart = _buildFlameChart(constraints);
              return chartOverlays.isNotEmpty
                  ? Stack(
                      children: [
                        flameChart,
                        ...chartOverlays,
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
    return ExtentDelegateListView(
      physics: const ClampingScrollPhysics(),
      controller: _flameChartScrollController,
      extentDelegate: verticalExtentDelegate,
      customPointerSignalHandler: _handlePointerSignal,
      childrenDelegate: SliverChildBuilderDelegate(
        (context, index) {
          final nodes = rows[index].nodes;
          var rowBackgroundColor = Colors.transparent;
          if (index >= rowOffsetForTopPadding && nodes.isEmpty) {
            // If this is a spacer row, we should use the background color of
            // the previous row with nodes.
            for (int i = index; i >= rowOffsetForTopPadding; i--) {
              // Look back until we find the first non-empty row.
              if (rows[i].nodes.isNotEmpty) {
                rowBackgroundColor = alternatingColorForIndex(
                  rows[i].nodes.first.sectionIndex,
                  Theme.of(context).colorScheme,
                );
                break;
              }
            }
          } else if (nodes.isNotEmpty) {
            rowBackgroundColor = alternatingColorForIndex(
              nodes.first.sectionIndex,
              Theme.of(context).colorScheme,
            );
          }
          // TODO(polinach): figure out how to get rid of the type cast.
          // See https://github.com/flutter/devtools/pull/3738#discussion_r817135162
          return ScrollingFlameChartRow<V>(
            linkedScrollControllerGroup: horizontalControllerGroup,
            nodes: nodes,
            width: math.max(constraints.maxWidth, widthWithZoom),
            startInset: widget.startInset,
            selectionNotifier: widget.selectionNotifier as ValueListenable<V>,
            searchMatchesNotifier:
                widget.searchMatchesNotifier as ValueListenable<List<V>>?,
            activeSearchMatchNotifier:
                widget.activeSearchMatchNotifier as ValueListenable<V?>?,
            onTapUp: focusNode.requestFocus,
            backgroundColor: rowBackgroundColor,
            zoom: currentZoom,
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
          maxZoomLevel,
          currentZoom + keyboardZoomInUnit,
        ));
      } else if (keyLabel == 's') {
        zoomTo(math.max(
          FlameChart.minZoomLevel,
          currentZoom - keyboardZoomOutUnit,
        ));
      } else if (keyLabel == 'a') {
        scrollToX(horizontalControllerGroup.offset - keyboardScrollUnit);
      } else if (keyLabel == 'd') {
        scrollToX(horizontalControllerGroup.offset + keyboardScrollUnit);
      }
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) async {
    if (event is PointerScrollEvent) {
      final deltaX = event.scrollDelta.dx;
      double deltaY = event.scrollDelta.dy;
      if (deltaY.abs() >= deltaX.abs()) {
        if (_altKeyPressed) {
          verticalControllerGroup.jumpTo(math.max(
            math.min(
              verticalControllerGroup.offset + deltaY,
              verticalControllerGroup.position.maxScrollExtent,
            ),
            0.0,
          ));
        } else {
          deltaY = deltaY.clamp(
            -FlameChart.maxScrollWheelDelta,
            FlameChart.maxScrollWheelDelta,
          );
          // TODO(kenz): if https://github.com/flutter/flutter/issues/52762 is,
          // resolved, consider adjusting the multiplier based on the scroll device
          // kind (mouse or track pad).
          final multiplier = FlameChart.zoomMultiplier * currentZoom;
          final newZoomLevel = (currentZoom + deltaY * multiplier).clamp(
            FlameChart.minZoomLevel,
            maxZoomLevel,
          );
          await zoomTo(newZoomLevel, jump: true);
          if (newZoomLevel == FlameChart.minZoomLevel &&
              horizontalControllerGroup.offset != 0.0) {
            // We do not need to call this in a post frame callback because
            // `FlameChart.minScrollOffset` (0.0) is guaranteed to be less than
            // the scroll controllers max scroll extent.
            await scrollToX(FlameChart.minScrollOffset);
          }
        }
      }
    }
  }

  void _handleZoomControllerValueUpdate() {
    final previousZoom = currentZoom;
    final newZoom = zoomController.value;
    if (previousZoom == newZoom) return;

    // Store current scroll values for re-calculating scroll location on zoom.
    final lastScrollOffset = horizontalControllerGroup.offset;

    final safeMouseHoverX = mouseHoverX ?? widget.containerWidth / 2;
    // Position in the zoomable coordinate space that we want to keep fixed.
    final fixedX = safeMouseHoverX + lastScrollOffset - widget.startInset;

    // Calculate the new horizontal scroll position.
    final newScrollOffset = fixedX >= 0
        ? fixedX * newZoom / previousZoom + widget.startInset - safeMouseHoverX
        // We are in the fixed portion of the window - no need to transform.
        : lastScrollOffset;

    setState(() {
      currentZoom = zoomController.value;
      // TODO(kenz): consult with Flutter team to see if there is a better place
      // to call this that guarantees the scroll controller offsets will be
      // updated for the new zoom level and layout size
      // https://github.com/flutter/devtools/issues/2012.
      scrollToX(newScrollOffset, jump: true);
    });
  }

  Future<void> zoomTo(
    double zoom, {
    double? forceMouseX,
    bool jump = false,
  }) async {
    if (forceMouseX != null) {
      mouseHoverX = forceMouseX;
    }
    await zoomController.animateTo(
      zoom.clamp(FlameChart.minZoomLevel, maxZoomLevel),
      duration: jump ? Duration.zero : shortDuration,
    );
  }

  /// Scroll the flame chart horizontally to [offset] scroll position.
  ///
  /// If this is being called immediately after a zoom call, without a chance
  /// for the UI to build between the zoom call and the call to
  /// this method, the call to this method should be placed inside of a
  /// postFrameCallback:
  /// `WidgetsBinding.instance.addPostFrameCallback((_) { ... });`.
  FutureOr<void> scrollToX(
    double offset, {
    bool jump = false,
  }) async {
    final target = offset.clamp(
      FlameChart.minScrollOffset,
      horizontalControllerGroup.position.maxScrollExtent,
    );
    if (jump) {
      horizontalControllerGroup.jumpTo(target);
    } else {
      await horizontalControllerGroup.animateTo(
        target,
        curve: defaultCurve,
        duration: shortDuration,
      );
    }
  }

  Future<void> scrollVerticallyToData(V data) async {
    await verticalControllerGroup.animateTo(
      // Subtract [2 * rowHeightWithPadding] to give the target scroll event top padding.
      (topYForData(data) - 2 * rowHeightWithPadding).clamp(
        FlameChart.minScrollOffset,
        verticalControllerGroup.position.maxScrollExtent,
      ),
      duration: shortDuration,
      curve: defaultCurve,
    );
  }

  /// Scroll the flame chart horizontally to put [data] in view.
  ///
  /// If this is being called immediately after a zoom call, the call to
  /// this method should be placed inside of a postFrameCallback:
  /// `WidgetsBinding.instance.addPostFrameCallback((_) { ... });`.
  Future<void> scrollHorizontallyToData(V data) async {
    final offset =
        startXForData(data) + widget.startInset - widget.containerWidth * 0.1;
    await scrollToX(offset);
  }

  Future<void> zoomAndScrollToData({
    required int startMicros,
    required int durationMicros,
    required V data,
    bool scrollVertically = true,
    bool jumpZoom = false,
  }) async {
    await zoomToTimeRange(
      startMicros: startMicros,
      durationMicros: durationMicros,
      jump: jumpZoom,
    );
    // Call these in a post frame callback so that the scroll controllers have
    // had time to update their scroll extents. Otherwise, we can hit a race
    // where are trying to scroll to an offset that is beyond what the scroll
    // controller thinks its max scroll extent is.
    WidgetsBinding.instance!.addPostFrameCallback((_) async {
      await Future.wait([
        scrollHorizontallyToData(data),
        if (scrollVertically) scrollVerticallyToData(data),
      ]);
    });
  }

  Future<void> zoomToTimeRange({
    required int startMicros,
    required int durationMicros,
    double? targetWidth,
    bool jump = false,
  }) async {
    targetWidth ??= widget.containerWidth * 0.8;
    final startingWidth = durationMicros * startingPxPerMicro;
    final zoom = targetWidth / startingWidth;
    final mouseXForZoom = (startMicros - startTimeOffset + durationMicros / 2) *
            startingPxPerMicro +
        widget.startInset;
    await zoomTo(zoom, forceMouseX: mouseXForZoom, jump: jump);
  }

  bool isDataVerticallyInView(V data);

  bool isDataHorizontallyInView(V data);

  double topYForData(V data);

  double startXForData(V data);
}

class ScrollingFlameChartRow<V extends FlameChartDataMixin<V>>
    extends StatefulWidget {
  const ScrollingFlameChartRow({
    required this.linkedScrollControllerGroup,
    required this.nodes,
    required this.width,
    required this.startInset,
    required this.selectionNotifier,
    required this.searchMatchesNotifier,
    required this.activeSearchMatchNotifier,
    required this.onTapUp,
    required this.backgroundColor,
    required this.zoom,
  });

  final LinkedScrollControllerGroup linkedScrollControllerGroup;

  final List<FlameChartNode<V>> nodes;

  final double width;

  final double startInset;

  final ValueListenable<V?> selectionNotifier;

  final ValueListenable<List<V>>? searchMatchesNotifier;

  final ValueListenable<V?>? activeSearchMatchNotifier;

  final VoidCallback onTapUp;

  final Color backgroundColor;

  final double zoom;

  @override
  ScrollingFlameChartRowState<V> createState() =>
      ScrollingFlameChartRowState<V>();
}

class ScrollingFlameChartRowState<V extends FlameChartDataMixin<V>>
    extends State<ScrollingFlameChartRow<V>> with AutoDisposeMixin {
  late final ScrollController scrollController;

  late final _ScrollingFlameChartRowExtentDelegate extentDelegate;

  /// Convenience getter for widget.nodes.
  List<FlameChartNode<V>> get nodes => widget.nodes;

  late List<V> _nodeData;

  V? selected;

  V? hovered;

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

    _initNodeDataList();

    selected = widget.selectionNotifier.value;
    addAutoDisposeListener(widget.selectionNotifier, () {
      final containsPreviousSelected = _nodeData.contains(selected);
      final containsNewSelected =
          _nodeData.contains(widget.selectionNotifier.value);
      selected = widget.selectionNotifier.value;
      // We only want to rebuild the row if it contains the previous or new
      // selected node.
      if (containsPreviousSelected || containsNewSelected) {
        setState(() {});
      }
    });

    if (widget.searchMatchesNotifier != null) {
      addAutoDisposeListener(widget.searchMatchesNotifier);
    }

    if (widget.activeSearchMatchNotifier != null) {
      addAutoDisposeListener(widget.activeSearchMatchNotifier);
    }
  }

  @override
  void didUpdateWidget(ScrollingFlameChartRow<V> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes != widget.nodes) {
      _initNodeDataList();
    }
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

  void _initNodeDataList() {
    _nodeData = nodes.map((node) => node.data).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return EmptyFlameChartRow(
        height: sectionSpacing,
        width: widget.width,
        backgroundColor: widget.backgroundColor,
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
          color: widget.backgroundColor,
          // TODO(kenz): investigate if `addAutomaticKeepAlives: false` and
          // `addRepaintBoundaries: false` are needed here for perf improvement.
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: FlameChartNodeRow(
              nodes: nodes,
              zoom: widget.zoom,
              startInset: widget.startInset,
              chartWidth: widget.width,
              selected: selected,
              hovered: hovered,
              extentDelegate: extentDelegate,
              controller: scrollController,
            ),
          ),
        ),
      ),
    );
  }

  void _handleMouseHover(PointerHoverEvent event) {
    final hoverNodeData =
        binarySearchForNode(event.localPosition.dx + scrollController.offset)
            ?.data;

    if (hoverNodeData != hovered) {
      setState(() {
        hovered = hoverNodeData;
      });
    }
  }

  void _handleTapUp(TapUpDetails details) {
    final referenceBox = context.findRenderObject() as RenderBox;
    final tapPosition = referenceBox.globalToLocal(details.globalPosition);
    final nodeToSelect =
        binarySearchForNode(tapPosition.dx + scrollController.offset);
    if (nodeToSelect != null) {
      nodeToSelect.onSelected(nodeToSelect.data);
    }
    widget.onTapUp();
  }

  @visibleForTesting
  FlameChartNode<V>? binarySearchForNode(double x) {
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

class FlameChartNodeRow extends LeafRenderObjectWidget {
  const FlameChartNodeRow({
    Key? key,
    required this.nodes,
    required this.zoom,
    required this.startInset,
    required this.chartWidth,
    required this.selected,
    required this.hovered,
    required this.extentDelegate,
    required this.controller,
  }) : super(key: key);

  final List<FlameChartNode> nodes;

  final double zoom;

  final double startInset;

  final double chartWidth;

  final Object? selected;

  final Object? hovered;

  final _ScrollingFlameChartRowExtentDelegate extentDelegate;

  final ScrollController controller;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderFlameRow()
      ..nodes = nodes
      ..zoom = zoom
      ..startInset = startInset
      ..chartWidth = chartWidth
      ..selected = selected
      ..hovered = hovered
      ..extentDelegate = extentDelegate
      ..controller = controller
      ..colorScheme = Theme.of(context).colorScheme;
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderFlameRow renderObject) {
    renderObject
      ..nodes = nodes
      ..zoom = zoom
      ..startInset = startInset
      ..chartWidth = chartWidth
      ..selected = selected
      ..hovered = hovered
      ..extentDelegate = extentDelegate
      ..controller = controller
      ..colorScheme = Theme.of(context).colorScheme;
  }
}

class _RenderFlameRow extends RenderBox {
   _RenderFlameRow();

  _ScrollingFlameChartRowExtentDelegate? extentDelegate;
  ScrollController? _controller;
  set controller(ScrollController value) {
    if (_controller == value) {
      return;
    }
    _controller?.removeListener(markNeedsPaint);
    _controller = value;
    _controller?.addListener(markNeedsPaint);
  }

  List<FlameChartNode> get nodes => _nodes;
  List<FlameChartNode> _nodes = [];
  set nodes(List<FlameChartNode> values) {
    if (identical(values, nodes)) {
      return;
    }
    _nodes = values;
    markNeedsLayout();
  }

  double get zoom => _zoom;
  double _zoom = 0.5;
  set zoom(double value) {
    if (value == zoom) {
      return;
    }
    _zoom = value;
    markNeedsPaint();
  }

  double get startInset => _startInset;
  double _startInset = 0;
  set startInset(double value) {
    if (value == startInset) {
      return;
    }
    _startInset = value;
    markNeedsLayout();
  }

  double get chartWidth => _chartWidth;
  double _chartWidth = 0;
  set chartWidth(double value) {
    if (value == chartWidth) {
      return;
    }
    _chartWidth = value;
    markNeedsLayout();
  }

  Object? get selected => _selected;
  Object? _selected;
  set selected(Object? value) {
    if (value == selected) {
      return;
    }
    _selected = value;
    markNeedsPaint();
  }

  Object? get hovered => _hovered;
  Object? _hovered ;
  set hovered(Object? value) {
    if (value == _hovered) {
      return;
    }
    _hovered = value;
    markNeedsPaint();
  }

  ColorScheme get colorScheme => _colorScheme!;
  ColorScheme? _colorScheme;
  set colorScheme(ColorScheme value) {
    if (value == _colorScheme) {
      return;
    }
    _colorScheme = value;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    final width = extentDelegate!.chartWidth;
    size = Size(
      width,
      constraints.maxHeight,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var accumulated = 0.0;
    var index = 0;
    for (var node in nodes) {
      final left = FlameChartUtils.leftPaddingForNode(
        index,
        nodes,
        chartZoom: zoom,
        chartStartInset: startInset,
      );
      node.draw(
        canvas: context.canvas,
        topLeft: offset + Offset(left + accumulated, 0),
        selected: node == selected,
        hovered: node == hovered,
        searchMatch:  node.data.isSearchMatch,
        activeSearchMatch: node.data.isActiveSearchMatch,
        zoom: zoom,
        colorScheme: colorScheme,
      );
      accumulated += extentDelegate!.itemExtent(index);
      index += 1;
    }
  }
}

extension NodeListExtension on List<FlameChartNode> {
  List<Range> toPaddedZoomedIntervals({
    required double zoom,
    required double chartStartInset,
    required double chartWidth,
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

// ignore: avoid_classes_with_only_static_members
class FlameChartUtils {
  static double leftPaddingForNode(
    int index,
    List<FlameChartNode> nodes, {
    required double chartZoom,
    required double chartStartInset,
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
    required double chartZoom,
    required double chartStartInset,
    required double chartWidth,
  }) {
    // TODO(kenz): workaround for https://github.com/flutter/devtools/issues/2012.
    // This is a ridiculous amount of padding but it ensures that we don't hit
    // the issue described in the bug where the scroll extent is smaller than
    // where we want to `jumpTo`. Smaller values were experimented with but the
    // issue still persisted, so we are using a very large number.
    if (index == nodes.length - 1) return 1000000000000.0;
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

  static double zoomForNode(FlameChartNode? node, double chartZoom) {
    return node != null && node.selectable
        ? chartZoom
        : FlameChart.minZoomLevel;
  }

  static Range paddedZoomedInterval(
    int index,
    List<FlameChartNode> nodes, {
    required double chartZoom,
    required double chartStartInset,
    required double chartWidth,
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
    required this.startRow,
    required this.endRow,
  });

  final int index;

  /// Start row (inclusive) for this section.
  final int startRow;

  /// End row (exclusive) for this section.
  final int endRow;
}

class FlameChartRow<T extends FlameChartDataMixin<T>> {
  FlameChartRow(this.index);

  final List<FlameChartNode<T>> nodes = [];

  final int index;

  /// Adds a node to [nodes] and assigns [this] to the nodes [row] property.
  ///
  /// If [index] is specified and in range of the list, [node] will be added at
  /// [index]. Otherwise, [node] will be added to the end of [nodes]
  void addNode(FlameChartNode<T> node, {int? index}) {
    if (index != null && index >= 0 && index < nodes.length) {
      nodes.insert(index, node);
    } else {
      nodes.add(node);
    }
    node.row = this;
  }
}

mixin FlameChartDataMixin<T extends TreeNode<T>>
    on TreeDataSearchStateMixin<T> {
  String get tooltip;
}

// TODO(kenz): consider de-coupling this API from the dual background color
// scheme.
class FlameChartNode<T extends FlameChartDataMixin<T>> {
  FlameChartNode({
    this.key,
    required this.text,
    required this.rect,
    required this.colorPair,
    required this.data,
    required this.onSelected,
    this.selectable = true,
    this.sectionIndex = 0,
  }) {
    final paragraphBuilder = ParagraphBuilder(
      ParagraphStyle(
        ellipsis: '...',
        textAlign: TextAlign.left,
        maxLines: 1,
        fontStyle: FontStyle.normal,
        textDirection: TextDirection.ltr,
        fontSize: 10,
      ),
    );
    paragraphBuilder.pushStyle(ui.TextStyle(color: _darkTextColor));
    paragraphBuilder.addText(text);
    paragraph = paragraphBuilder.build();
  }

  static const _darkTextColor = Colors.black;

  // We would like this value to be smaller, but zoom performance does not allow
  // for that. We should decrease this value if we can improve flame chart zoom
  // performance.
  static const _minWidthForText = 30.0;

  final Key? key;
  final Rect rect;
  final String text;
  final ThemedColorPair colorPair;
  final T data;
  final void Function(T) onSelected;
  final bool selectable;

  late FlameChartRow row;
  late Paragraph paragraph;

  int sectionIndex;

  void draw({
    required Canvas canvas,
    required Offset topLeft,
    required bool selected,
    required bool hovered,
    required bool searchMatch,
    required bool activeSearchMatch,
    required double zoom,
    required ColorScheme colorScheme,
  }) {
    // This math.max call prevents using a rect with negative width for
    // small events that have padding.
    //
    // See https://github.com/flutter/devtools/issues/1503 for details.
    final zoomedWidth = math.max(0.0, rect.width * zoom);

    // TODO(kenz): this is intended to improve performance but can probably be
    // improved. Perhaps we should still show a solid line and fade it out?
    if (zoomedWidth < 0.5) {
      return;
    }

    selected = selectable ? selected : false;
    hovered = selectable ? hovered : false;
    final drawnRect = Rect.fromLTWH(topLeft.dx, topLeft.dy, rect.width * zoom, rect.height * zoom);
    final paint = Paint()
      ..color = _backgroundColor(
        selected: selected,
        searchMatch: searchMatch,
        activeSearchMatch: activeSearchMatch,
        colorScheme: colorScheme,
      );
    canvas.drawRect(drawnRect, paint);
    if (zoomedWidth >= _minWidthForText) {
      paragraph.layout(ParagraphConstraints(width: drawnRect.width));
      canvas.drawParagraph(paragraph, topLeft);
    }
  }

  Color _backgroundColor({
    required bool selected,
    required bool searchMatch,
    required bool activeSearchMatch,
    required ColorScheme colorScheme,
  }) {
    if (selected) return defaultSelectionColor;
    if (activeSearchMatch) return activeSearchMatchColor;
    if (searchMatch) return searchMatchColor;
    return colorPair.background.colorFor(colorScheme);
  }

  Color _textColor({
    required bool selected,
    required bool searchMatch,
    required bool activeSearchMatch,
    required ColorScheme colorScheme,
  }) {
    if (selected || searchMatch || activeSearchMatch) return _darkTextColor;
    return colorPair.foreground.colorFor(colorScheme);
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
  ColorPair nextUiColor(int row) {
    return uiColorPalette[row % uiColorPalette.length];
  }

  ColorPair nextRasterColor(int row) {
    return rasterColorPalette[row % rasterColorPalette.length];
  }

  ColorPair nextAsyncColor(int row) {
    return asyncColorPalette[row % asyncColorPalette.length];
  }

  ColorPair nextUnknownColor(int row) {
    return unknownColorPalette[row % unknownColorPalette.length];
  }
}

/// [ExtentDelegate] implementation for the case where size and position is
/// known for each list item.
class _ScrollingFlameChartRowExtentDelegate extends ExtentDelegate {
  _ScrollingFlameChartRowExtentDelegate({
    required this.nodeIntervals,
    required this.zoom,
    required this.chartStartInset,
    required this.chartWidth,
  }) {
    recompute();
  }

  List<Range> nodeIntervals = [];

  double zoom;

  double chartStartInset;

  double chartWidth;

  void recomputeWith({
    required List<Range> nodeIntervals,
    required double zoom,
    required double chartStartInset,
    required double chartWidth,
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
    return nodeIntervals[index].size as double;
  }

  @override
  double layoutOffset(int? index) {
    if (index! <= 0) return 0.0;
    if (index >= length) return nodeIntervals.last.end as double;
    return nodeIntervals[index].begin as double;
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
    required this.zoom,
    required this.constraints,
    required this.verticalScrollOffset,
    required this.horizontalScrollOffset,
    required this.chartStartInset,
    required this.colorScheme,
  });

  final double zoom;

  final BoxConstraints constraints;

  final double verticalScrollOffset;

  final double horizontalScrollOffset;

  final double chartStartInset;

  /// The absolute coordinates of the flame chart's visible section.
  Rect get visibleRect {
    return Rect.fromLTWH(
      horizontalScrollOffset,
      verticalScrollOffset,
      constraints.maxWidth,
      constraints.maxHeight,
    );
  }

  final ColorScheme colorScheme;

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is FlameChartPainter) {
      return verticalScrollOffset != oldDelegate.verticalScrollOffset ||
          horizontalScrollOffset != oldDelegate.horizontalScrollOffset ||
          constraints != oldDelegate.constraints ||
          zoom != oldDelegate.zoom ||
          chartStartInset != oldDelegate.chartStartInset ||
          oldDelegate.colorScheme != colorScheme;
    }
    return true;
  }
}

class TimelineGridPainter extends FlameChartPainter {
  TimelineGridPainter({
    required double zoom,
    required BoxConstraints constraints,
    required double verticalScrollOffset,
    required double horizontalScrollOffset,
    required double chartStartInset,
    required this.chartEndInset,
    required this.flameChartWidth,
    required this.duration,
    required ColorScheme colorScheme,
  }) : super(
          zoom: zoom,
          constraints: constraints,
          verticalScrollOffset: verticalScrollOffset,
          horizontalScrollOffset: horizontalScrollOffset,
          chartStartInset: chartStartInset,
          colorScheme: colorScheme,
        );

  static const timestampOffset = 6.0;

  final double chartEndInset;

  final double flameChartWidth;

  final Duration duration;

  @override
  void paint(Canvas canvas, Size size) {
    // Paint background for the section that will contain the timestamps. This
    // section will appear sticky to the top of the viewport.
    final visible = visibleRect;
    canvas.drawRect(
      Rect.fromLTWH(
        0.0,
        0.0,
        constraints.maxWidth,
        math.min(constraints.maxHeight, rowHeight),
      ),
      Paint()..color = colorScheme.defaultBackgroundColor,
    );

    // Paint the timeline grid lines and corresponding timestamps in the flame
    // chart.
    final intervalWidth = _intervalWidth();
    final microsPerInterval = _microsPerInterval(intervalWidth);
    int timestampMicros = _startingTimestamp(intervalWidth, microsPerInterval);
    double lineX;
    if (visible.left <= chartStartInset) {
      lineX = chartStartInset - visible.left;
    } else {
      lineX =
          intervalWidth - ((visible.left - chartStartInset) % intervalWidth);
    }

    while (lineX < constraints.maxWidth) {
      _paintTimestamp(canvas, timestampMicros, intervalWidth, lineX);
      _paintGridLine(canvas, lineX);
      lineX += intervalWidth;
      timestampMicros += microsPerInterval;
    }
  }

  void _paintTimestamp(
    Canvas canvas,
    int timestampMicros,
    double intervalWidth,
    double lineX,
  ) {
    final timestampText = msText(
      Duration(microseconds: timestampMicros),
      fractionDigits: timestampMicros == 0 ? 1 : 3,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: timestampText,
        style: TextStyle(
          color: colorScheme.chartTextColor,
          fontSize: defaultFontSize,
        ),
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: intervalWidth);

    // TODO(kenz): figure out a way for the timestamps to scroll out of view
    // smoothly instead of dropping off. Consider using a horizontal list view
    // of text widgets for the timestamps instead of painting them.
    final xOffset = lineX - textPainter.width - timestampOffset;
    if (xOffset > 0) {
      textPainter.paint(canvas, Offset(xOffset, rowPadding));
    }
  }

  void _paintGridLine(Canvas canvas, double lineX) {
    canvas.drawLine(
      Offset(lineX, 0.0),
      Offset(lineX, constraints.maxHeight),
      Paint()..color = colorScheme.chartAccentColor,
    );
  }

  double _intervalWidth() {
    final log2ZoomLevel = log2(zoom);

    final gridZoomFactor = math.pow(2, log2ZoomLevel);
    final gridIntervalPx = baseTimelineGridIntervalPx / gridZoomFactor;

    /// The physical pixel width of the grid interval at [zoom].
    return gridIntervalPx * zoom;
  }

  int _microsPerInterval(double intervalWidth) {
    final contentWidth = flameChartWidth - chartStartInset - chartEndInset;
    final numCompleteIntervals = contentWidth ~/ intervalWidth;
    final remainderContentWidth =
        contentWidth - (numCompleteIntervals * intervalWidth);
    final remainderMicros =
        remainderContentWidth * duration.inMicroseconds / contentWidth;
    return ((duration.inMicroseconds - remainderMicros) / numCompleteIntervals)
        .round();
  }

  int _startingTimestamp(double intervalWidth, int microsPerInterval) {
    final startingIntervalIndex = horizontalScrollOffset < chartStartInset
        ? 0
        : (horizontalScrollOffset - chartStartInset) ~/ intervalWidth + 1;
    return startingIntervalIndex * microsPerInterval;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => this != oldDelegate;

  @override
  bool operator ==(other) {
    if (other is! TimelineGridPainter) return false;
    return zoom == other.zoom &&
        constraints == other.constraints &&
        flameChartWidth == other.flameChartWidth &&
        horizontalScrollOffset == other.horizontalScrollOffset &&
        duration == other.duration &&
        colorScheme == other.colorScheme;
  }

  @override
  int get hashCode => hashValues(
        zoom,
        constraints,
        flameChartWidth,
        horizontalScrollOffset,
        duration,
        colorScheme,
      );
}

class FlameChartHelpButton extends StatelessWidget {
  const FlameChartHelpButton({
    required this.gaScreen,
    required this.gaSelection,
    this.additionalInfo = const <Widget>[],
  });

  final String gaScreen;

  final String gaSelection;

  final List<Widget> additionalInfo;

  @override
  Widget build(BuildContext context) {
    return HelpButton(
      onPressed: () {
        ga.select(gaScreen, gaSelection);
        showDialog(
          context: context,
          builder: (context) => _FlameChartHelpDialog(
            additionalInfo: additionalInfo,
          ),
        );
      },
      gaScreen: gaScreen,
      gaSelection: gaSelection,
    );
  }
}

class _FlameChartHelpDialog extends StatelessWidget {
  const _FlameChartHelpDialog({this.additionalInfo = const <Widget>[]});

  final List<Widget> additionalInfo;

  /// A fixed width for the first column in the help dialog to ensure that the
  /// subsections are aligned.
  double get firstColumnWidth => scaleByFontFactor(190.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: dialogTitleText(theme, 'Flame Chart Help'),
      includeDivider: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...dialogSubHeader(theme, 'Navigation'),
          _buildNavigationInstructions(theme),
          const SizedBox(height: denseSpacing),
          ...dialogSubHeader(theme, 'Zoom'),
          _buildZoomInstructions(theme),
          if (additionalInfo.isNotEmpty) const SizedBox(height: denseSpacing),
          ...additionalInfo,
        ],
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }

  Widget _buildNavigationInstructions(ThemeData theme) {
    return Row(
      children: [
        SizedBox(
          width: firstColumnWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'click + drag • ',
                style: theme.fixedFontStyle,
              ),
              Text(
                'click + fling • ',
                style: theme.fixedFontStyle,
              ),
              Text(
                'alt/option + scroll • ',
                style: theme.fixedFontStyle,
              ),
              Text(
                'scroll left / right • ',
                style: theme.fixedFontStyle,
              ),
              Text(
                'a / d • ',
                style: theme.fixedFontStyle,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pan chart up / down / left / right',
              style: theme.subtleTextStyle,
            ),
            Text(
              'Fling chart up / down / left / right',
              style: theme.subtleTextStyle,
            ),
            Text(
              'Pan chart up / down',
              style: theme.subtleTextStyle,
            ),
            Text(
              'Pan chart left / right',
              style: theme.subtleTextStyle,
            ),
            Text(
              'Pan chart left / right',
              style: theme.subtleTextStyle,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildZoomInstructions(ThemeData theme) {
    return Row(
      children: [
        SizedBox(
          width: firstColumnWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'scroll up / down • ',
                style: theme.fixedFontStyle,
              ),
              Text(
                'w / s • ',
                style: theme.fixedFontStyle,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'zoom in / out',
              style: theme.subtleTextStyle,
            ),
            Text(
              'zoom in / out',
              style: theme.subtleTextStyle,
            ),
          ],
        ),
      ],
    );
  }
}

class EmptyFlameChartRow extends StatelessWidget {
  const EmptyFlameChartRow({
    required this.height,
    required this.width,
    required this.backgroundColor,
  });

  final double height;

  final double width;

  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      color: backgroundColor,
    );
  }
}
