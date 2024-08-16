// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/diagnostics/diagnostics_node.dart';
import '../../../../shared/primitives/math_utils.dart';
import '../../../../shared/primitives/utils.dart';
import '../../inspector_data_models.dart';
import '../ui/free_space.dart';
import '../ui/layout_explorer_widget.dart';
import '../ui/theme.dart';
import '../ui/utils.dart';
import '../ui/widget_constraints.dart';
import '../ui/widgets_theme.dart';

class BoxLayoutExplorerWidget extends LayoutExplorerWidget {
  const BoxLayoutExplorerWidget(
    super.inspectorController, {
    super.key,
  });

  static bool shouldDisplay(RemoteDiagnosticsNode _) {
    // Pretend this layout explorer is always available. This layout explorer
    // will gracefully fall back to an error message if the required properties
    // are not needed.
    // TODO(jacobr) pass a RemoteDiagnosticsNode to this method that contains
    // the layout explorer related supplemental properties so that we can
    // accurately determine whether the widget uses box layout.
    return true;
  }

  @override
  State<BoxLayoutExplorerWidget> createState() =>
      BoxLayoutExplorerWidgetState();
}

class BoxLayoutExplorerWidgetState extends LayoutExplorerWidgetState<
    BoxLayoutExplorerWidget, LayoutProperties> {
  @override
  RemoteDiagnosticsNode? getRoot(RemoteDiagnosticsNode? node) {
    final nodeLocal = node;
    if (nodeLocal == null) return null;
    if (!shouldDisplay(nodeLocal)) return null;
    return node;
  }

  @override
  bool shouldDisplay(RemoteDiagnosticsNode node) {
    final selectedNodeLocal = selectedNode;
    if (selectedNodeLocal == null) return false;
    return BoxLayoutExplorerWidget.shouldDisplay(selectedNodeLocal);
  }

  @override
  AnimatedLayoutProperties computeAnimatedProperties(
    LayoutProperties nextProperties,
  ) {
    return AnimatedLayoutProperties(
      // If an animation is in progress, freeze it and start animating from there, else start a fresh animation from widget.properties.
      animatedProperties?.copyWith() ?? properties!,
      nextProperties,
      changeAnimation,
    );
  }

  @override
  LayoutProperties computeLayoutProperties(RemoteDiagnosticsNode node) =>
      LayoutProperties(node);

  @override
  void updateHighlighted(LayoutProperties? newProperties) {
    setState(() {
      // This implementation will need to change if we support showing more than
      // a single widget in the box visualization for the layout explorer.
      highlighted = newProperties != null && selectedNode == newProperties.node
          ? newProperties
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (properties == null) {
      final selectedNodeLocal = selectedNode;
      return Center(
        child: Text(
          '${selectedNodeLocal?.description ?? 'Widget'} has no layout properties to display.',
          textAlign: TextAlign.center,
          overflow: TextOverflow.clip,
        ),
      );
    }
    return AnimatedBuilder(
      animation: changeController,
      builder: (context, _) {
        return LayoutBuilder(builder: _buildLayout);
      },
    );
  }

  List<Widget> _paddingWidgets({
    required LayoutProperties childProperties,
    required LayoutProperties parentProperties,
    required LayoutWidthsAndHeights widthsAndHeights,
    required ColorScheme colorScheme,
    required Color widgetColor,
  }) {
    if (!widthsAndHeights.hasAnyPadding) return <Widget>[];

    final LayoutWidthsAndHeights(
      :topPadding,
      :bottomPadding,
      :leftPadding,
      :rightPadding,
      :displayTopPadding,
      :displayBottomPadding,
      :displayLeftPadding,
      :displayRightPadding,
      :displayWidgetHeight,
      :displayWidgetWidth,
      :hasTopPadding,
      :hasBottomPadding,
      :hasLeftPadding,
      :hasRightPadding,
    ) = widthsAndHeights;

    final parentHeight = parentProperties.size.height;
    final parentWidth = parentProperties.size.width;

    return [
      LayoutExplorerBackground(colorScheme: colorScheme),
      PositionedBackgroundLabel(
        labelText: describeBoxName(parentProperties),
        labelColor: widgetColor,
        topPadding: hasTopPadding,
        bottomPadding: hasBottomPadding,
        leftPadding: hasLeftPadding,
        rightPadding: hasRightPadding,
      ),
      if (hasLeftPadding)
        PaddingVisualizerWidget(
          RenderProperties(
            axis: Axis.horizontal,
            size: Size(displayLeftPadding, displayWidgetHeight),
            offset: Offset(0, displayTopPadding),
            realSize: Size(leftPadding, parentHeight),
            layoutProperties: childProperties,
            isFreeSpace: true,
          ),
          horizontal: true,
        ),
      if (hasTopPadding)
        PaddingVisualizerWidget(
          RenderProperties(
            axis: Axis.horizontal,
            size: Size(displayWidgetWidth, displayTopPadding),
            offset: Offset(displayLeftPadding, 0),
            realSize: Size(parentWidth, topPadding),
            layoutProperties: childProperties,
            isFreeSpace: true,
          ),
          horizontal: false,
        ),
      if (hasRightPadding)
        PaddingVisualizerWidget(
          RenderProperties(
            axis: Axis.horizontal,
            size: Size(displayRightPadding, displayWidgetHeight),
            offset: Offset(
              displayLeftPadding + displayWidgetWidth,
              displayTopPadding,
            ),
            realSize: Size(rightPadding, parentHeight),
            layoutProperties: childProperties,
            isFreeSpace: true,
          ),
          horizontal: true,
        ),
      if (hasBottomPadding)
        PaddingVisualizerWidget(
          RenderProperties(
            axis: Axis.horizontal,
            size: Size(displayWidgetWidth, displayBottomPadding),
            offset: Offset(
              displayLeftPadding,
              displayTopPadding + displayWidgetHeight,
            ),
            realSize: Size(parentWidth, bottomPadding),
            layoutProperties: childProperties,
            isFreeSpace: true,
          ),
          horizontal: false,
        ),
    ];
  }

  LayoutProperties? get parentProperties {
    final parentElement = properties?.node.parentRenderElement;
    if (parentElement == null) return null;
    final parentProperties = computeLayoutProperties(parentElement);
    return parentProperties;
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final propertiesLocal = properties!;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parentProperties = this.parentProperties ??
        propertiesLocal; // Fall back to this node's properties if there is no parent.

    final parentSize = parentProperties.size;
    final offset = propertiesLocal.node.parentData;

    final child = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Subtract out one pixel border on each side.
        final availableHeight = constraints.maxHeight - 2;
        final availableWidth = constraints.maxWidth - 2;

        // 3 element array with [left padding, widget width, right padding].
        final widgetWidths = [
          offset.offset.dx,
          propertiesLocal.size.width,
          parentSize.width - (propertiesLocal.size.width + offset.offset.dx),
        ];
        // 3 element array with [top padding, widget height, bottom padding].
        final widgetHeights = [
          offset.offset.dy,
          propertiesLocal.size.height,
          parentSize.height - (propertiesLocal.size.height + offset.offset.dy),
        ];

        final widthsAndHeights = LayoutWidthsAndHeights(
          widths: widgetWidths,
          heights: widgetHeights,
          availableWidth: availableWidth,
          availableHeight: availableHeight,
        );

        final widgetColor =
            WidgetTheme.fromName(properties?.node.description).color;
        return Column(
          children: [
            Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              decoration: BoxDecoration(
                border: Border.all(
                  color: widgetColor,
                ),
              ),
              child: Stack(
                children: [
                  ..._paddingWidgets(
                    childProperties: propertiesLocal,
                    parentProperties: parentProperties,
                    widthsAndHeights: widthsAndHeights,
                    colorScheme: colorScheme,
                    widgetColor: widgetColor,
                  ),
                  BoxChildVisualizer(
                    isSelected: true,
                    state: this,
                    layoutProperties: propertiesLocal,
                    renderProperties: RenderProperties(
                      axis: Axis.horizontal,
                      size: Size(
                        widthsAndHeights.displayWidgetWidth,
                        widthsAndHeights.displayWidgetHeight,
                      ),
                      offset: Offset(
                        widthsAndHeights.displayLeftPadding,
                        widthsAndHeights.displayTopPadding,
                      ),
                      realSize: propertiesLocal.size,
                      layoutProperties: propertiesLocal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    return Container(
      constraints: BoxConstraints(
        maxWidth: constraints.maxWidth,
        maxHeight: constraints.maxHeight,
      ),
      child: child,
    );
  }
}

String describeBoxName(LayoutProperties properties) =>
    properties.node.description ?? '';

/// Represents a box widget and its surrounding padding.
class BoxChildAndPaddingVisualizer extends StatelessWidget {
  const BoxChildAndPaddingVisualizer({
    super.key,
    required this.state,
    required this.layoutProperties,
    required this.renderProperties,
    required this.isSelected,
  });

  final BoxLayoutExplorerWidgetState state;

  final bool isSelected;
  final LayoutProperties layoutProperties;
  final RenderProperties renderProperties;

  LayoutProperties? get properties => renderProperties.layoutProperties;

  @override
  Widget build(BuildContext context) {
    final renderSize = renderProperties.size;
    final renderOffset = renderProperties.offset;

    Widget buildEntranceAnimation(BuildContext _, Widget? child) {
      final size = renderSize;
      // TODO(jacobr): does this entrance animation really add value.
      return Opacity(
        opacity: min([state.entranceCurve.value * 5, 1.0]),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: math.max(0.0, (renderSize.width - size.width) / 2),
            vertical: math.max(0.0, (renderSize.height - size.height) / 2),
          ),
          child: child,
        ),
      );
    }

    final propertiesLocal = properties!;

    return Positioned(
      top: renderOffset.dy,
      left: renderOffset.dx,
      child: InkWell(
        onTap: () => unawaited(state.onTap(propertiesLocal)),
        onDoubleTap: () => state.onDoubleTap(propertiesLocal),
        child: SizedBox(
          width: safePositiveDouble(renderSize.width),
          height: safePositiveDouble(renderSize.height),
          child: AnimatedBuilder(
            animation: state.entranceController,
            builder: buildEntranceAnimation,
            child: WidgetVisualizer(
              isSelected: isSelected,
              layoutProperties: layoutProperties,
              title: describeBoxName(propertiesLocal),
              // TODO(jacobr): consider surfacing the overflow size information
              // if we determine
              // overflowSide: properties.overflowSide,

              // We only show one child at a time so a large title is safe.
              largeTitle: true,
              child: VisualizeWidthAndHeightWithConstraints(
                arrowHeadSize: arrowHeadSize,
                properties: propertiesLocal,
                warnIfUnconstrained: false,
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget that represents and visualize a direct child of Flex widget.
class BoxChildVisualizer extends StatelessWidget {
  const BoxChildVisualizer({
    super.key,
    required this.state,
    required this.layoutProperties,
    required this.renderProperties,
    required this.isSelected,
  });

  final BoxLayoutExplorerWidgetState state;

  final bool isSelected;
  final LayoutProperties layoutProperties;
  final RenderProperties renderProperties;

  LayoutProperties? get properties => renderProperties.layoutProperties;

  @override
  Widget build(BuildContext context) {
    final renderSize = renderProperties.size;
    final renderOffset = renderProperties.offset;

    Widget buildEntranceAnimation(BuildContext _, Widget? child) {
      final size = renderSize;
      // TODO(jacobr): does this entrance animation really add value.
      return Opacity(
        opacity: min([state.entranceCurve.value * 5, 1.0]),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: math.max(0.0, (renderSize.width - size.width) / 2),
            vertical: math.max(0.0, (renderSize.height - size.height) / 2),
          ),
          child: child,
        ),
      );
    }

    final propertiesLocal = properties!;

    return Positioned(
      top: renderOffset.dy,
      left: renderOffset.dx,
      child: InkWell(
        onTap: () => unawaited(state.onTap(propertiesLocal)),
        onDoubleTap: () => state.onDoubleTap(propertiesLocal),
        child: SizedBox(
          width: safePositiveDouble(renderSize.width),
          height: safePositiveDouble(renderSize.height),
          child: AnimatedBuilder(
            animation: state.entranceController,
            builder: buildEntranceAnimation,
            child: WidgetVisualizer(
              isSelected: isSelected,
              layoutProperties: layoutProperties,
              title: describeBoxName(propertiesLocal),
              // TODO(jacobr): consider surfacing the overflow size information
              // if we determine
              // overflowSide: properties.overflowSide,

              // We only show one child at a time so a large title is safe.
              largeTitle: true,
              child: VisualizeWidthAndHeightWithConstraints(
                arrowHeadSize: arrowHeadSize,
                properties: propertiesLocal,
                warnIfUnconstrained: false,
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encapsulation of [widths] and [heights] for the layout.
class LayoutWidthsAndHeights {
  LayoutWidthsAndHeights({
    required this.widths,
    required this.heights,
    required this.availableWidth,
    required this.availableHeight,
  })  : assert(widths.length == 3),
        assert(heights.length == 3) {
    _displayWidths = _simpleFractionalLayout(
      availableSize: availableWidth,
      sizes: widths,
    );
    _displayHeights = _simpleFractionalLayout(
      availableSize: availableHeight,
      sizes: heights,
    );
  }

  final List<double> widths;
  final List<double> heights;
  late List<double> _displayWidths;
  late List<double> _displayHeights;
  final double availableWidth;
  final double availableHeight;

  double get widgetWidth => widths[1];

  double get widgetHeight => heights[1];

  double get leftPadding => widths[0];

  double get rightPadding => widths[2];

  double get topPadding => heights[0];

  double get bottomPadding => heights[2];

  double get displayWidgetWidth => _displayWidths[1];

  double get displayWidgetHeight => _displayHeights[1];

  double get displayLeftPadding => _displayWidths[0];

  double get displayRightPadding => _displayWidths[2];

  double get displayTopPadding => _displayHeights[0];

  double get displayBottomPadding => _displayHeights[2];

  bool get hasLeftPadding => leftPadding != 0;

  bool get hasRightPadding => rightPadding != 0;

  bool get hasTopPadding => topPadding != 0;

  bool get hasBottomPadding => bottomPadding != 0;

  bool get hasAnyPadding =>
      hasLeftPadding || hasRightPadding || hasTopPadding || hasBottomPadding;

  /// Simplistic layout algorithm that will return sizes for the padding, width,
  /// and height of the widget based on the display's [availableSize] along with
  /// [sizes] of the widget.
  ///
  /// Uses a constant [paddingFraction] for the display padding, regardless of
  /// the actual size.
  ///
  /// The return value and [sizes] parameter correspond to either:
  /// - left padding width, widget width, right padding width
  /// - top padding height, widget height, bottom padding height
  List<double> _simpleFractionalLayout({
    required double availableSize,
    required List<double?> sizes,
  }) {
    final paddingASize = sizes[0] ?? 0;
    final paddingBSize = sizes[2] ?? 0;

    final paddingFraction = paddingASize != 0 && paddingBSize != 0 ? 0.3 : 0.35;

    final paddingAFraction = paddingASize > 0 ? paddingFraction : 0.0;
    final paddingBFraction = paddingBSize > 0 ? paddingFraction : 0.0;
    final widgetFraction = 1 - paddingAFraction - paddingBFraction;

    return [
      paddingAFraction,
      widgetFraction,
      paddingBFraction,
    ].map((fraction) => fraction * availableSize).toList();
  }
}
