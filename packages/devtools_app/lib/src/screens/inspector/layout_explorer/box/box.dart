// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_redundant_argument_values, import_of_legacy_library_into_null_safe

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../primitives/math_utils.dart';
import '../../../../primitives/utils.dart';
import '../../../../shared/theme.dart';
import '../../diagnostics_node.dart';
import '../../inspector_controller.dart';
import '../../inspector_data_models.dart';
import '../ui/free_space.dart';
import '../ui/layout_explorer_widget.dart';
import '../ui/theme.dart';
import '../ui/utils.dart';
import '../ui/widget_constraints.dart';
import '../ui/widgets_theme.dart';

class BoxLayoutExplorerWidget extends LayoutExplorerWidget {
  const BoxLayoutExplorerWidget(
    InspectorController inspectorController, {
    Key? key,
  }) : super(inspectorController, key: key);

  static bool shouldDisplay(RemoteDiagnosticsNode? node) {
    // Pretend this layout explorer is always available. This layout explorer
    // will gracefully fall back to an error message if the required properties
    // are not needed.
    // TODO(jacobr) pass a RemoteDiagnosticsNode to this method that contains
    // the layout explorer related supplemental properties so that we can
    // accurately determine whether the widget uses box layout.
    return node != null;
  }

  @override
  _BoxLayoutExplorerWidgetState createState() =>
      _BoxLayoutExplorerWidgetState();
}

class _BoxLayoutExplorerWidgetState extends LayoutExplorerWidgetState<
    BoxLayoutExplorerWidget, LayoutProperties> {
  @override
  RemoteDiagnosticsNode? getRoot(RemoteDiagnosticsNode? node) {
    if (!shouldDisplay(node)) return null;
    return node;
  }

  @override
  bool shouldDisplay(RemoteDiagnosticsNode? node) {
    return BoxLayoutExplorerWidget.shouldDisplay(selectedNode);
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
  LayoutProperties computeLayoutProperties(node) => LayoutProperties(node);

  @override
  void updateHighlighted(LayoutProperties? newProperties) {
    setState(() {
      // This implementation will need to change if we support showing more than
      // a single widget in the box visualization for the layout explorer.
      if (newProperties != null && selectedNode == newProperties.node) {
        highlighted = newProperties;
      } else {
        highlighted = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (properties == null) return const SizedBox();
    return Container(
      margin: const EdgeInsets.all(margin),
      padding: const EdgeInsets.only(bottom: margin, right: margin),
      child: AnimatedBuilder(
        animation: changeController,
        builder: (context, _) {
          return LayoutBuilder(builder: _buildLayout);
        },
      ),
    );
  }

  /// Simplistic layout algorithm to roughly match minFraction restrictions for
  /// each sizes attempting to render a stylized version of the original layout.
  /// TODO(jacobr): see if we can unify with the stylized version of the overall
  /// layout used for Flex. Our constraints are quite different as we can
  /// guarantee that the entire layout fits without scrolling while in the Flex
  /// case that would be difficult.
  ///
  /// The overall layout will expand to use the full availableSize treating null
  /// values in [sizes] as an indication that the items should have zero size.
  /// On the other hand, a non-null size indicates that the minFractions
  /// constraints should be obeyed. This is needed to ensure that negative sizes
  /// are visualized reasonably.
  /// The minFractions aren't exactly obeyed but they are approximated in a way
  /// that keeps this algorithm simple and has the nice property that an initial
  /// value much smaller than the minSize results in a slightly smaller value
  /// than a value that is almost minSize.
  /// In the most extreme case an item will get not minFraction but will instead
  /// get the slightly smaller value of minFraction / (1 + minFraction)
  /// which is close enough for the simple values we need this for.
  static List<double> minFractionLayout({
    required double availableSize,
    required List<double?> sizes,
    required List<double> minFractions,
  }) {
    assert(sizes.length == minFractions.length);
    final length = sizes.length;
    double total = 1.0; // This isn't set to zero to avoid divide by zero bugs.
    final fractions = minFractions.toList();
    for (var size in sizes) {
      if (size != null) {
        total += math.max(0, size);
      }
    }

    double totalFraction = 0.0;
    for (int i = 0; i < length; i++) {
      final size = sizes[i];
      if (size != null) {
        fractions[i] = math.max(size / total, minFractions[i]);
        totalFraction += fractions[i];
      } else {
        fractions[i] = 0.0;
      }
    }
    if (totalFraction != 1.0) {
      for (int i = 0; i < length; i++) {
        fractions[i] = fractions[i] / totalFraction;
      }
    }
    final output = <double>[];
    for (var fraction in fractions) {
      output.add(fraction * availableSize);
    }
    return output;
  }

  Widget _buildChild(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parentProperties = this.parentProperties ??
        properties!; // Fall back to this node's properties if there is no parent.

    final parentSize = parentProperties.size;
    final offset = properties!.node.parentData ??
        (BoxParentData()..offset = const Offset(0, 0));

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Subtract out one pixel border on each side.
        final availableHeight = constraints.maxHeight - 2;
        final availableWidth = constraints.maxWidth - 2;

        final minFractions = [0.2, 0.5, 0.2];
        double? nullOutZero(double value) => value != 0.0 ? value : null;
        final widths = [
          nullOutZero(offset.offset.dx),
          properties!.size.width,
          nullOutZero(
            parentSize.width - (properties!.size.width + offset.offset.dx),
          ),
        ];
        final heights = [
          nullOutZero(offset.offset.dy),
          properties!.size.height,
          nullOutZero(
            parentSize.height - (properties!.size.height + offset.offset.dy),
          ),
        ];
        // 3 element array with [left padding, widget width, right padding].
        final displayWidths = minFractionLayout(
          availableSize: availableWidth,
          sizes: widths,
          minFractions: minFractions,
        );
        // 3 element array with [top padding, widget height, bottom padding].
        final displayHeights = minFractionLayout(
          availableSize: availableHeight,
          sizes: heights,
          minFractions: minFractions,
        );
        final widgetWidth = displayWidths[1];
        final widgetHeight = displayHeights[1];
        final safeParentSize = parentSize;
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            border: Border.all(
              color: WidgetTheme.fromName(properties!.node.description).color,
            ),
          ),
          child: Stack(
            children: [
              LayoutExplorerBackground(colorScheme: colorScheme),
              // Left padding.
              if (widths[0] != null)
                PaddingVisualizerWidget(
                  RenderProperties(
                    axis: Axis.horizontal,
                    size: Size(displayWidths[0], widgetHeight),
                    offset: Offset(0, displayHeights[0]),
                    realSize: Size(widths[0]!, safeParentSize.height),
                    layoutProperties: properties,
                    isFreeSpace: true,
                  ),
                  horizontal: true,
                ),
              // Top padding.
              if (heights[0] != null)
                PaddingVisualizerWidget(
                  RenderProperties(
                    axis: Axis.horizontal,
                    size: Size(widgetWidth, displayHeights[0]),
                    offset: Offset(displayWidths[0], 0),
                    realSize: Size(safeParentSize.width, heights[0]!),
                    layoutProperties: properties,
                    isFreeSpace: true,
                  ),
                  horizontal: false,
                ),
              // Right padding.
              if (widths[2] != null)
                PaddingVisualizerWidget(
                  RenderProperties(
                    axis: Axis.horizontal,
                    size: Size(displayWidths[2], widgetHeight),
                    offset: Offset(
                        displayWidths[0] + displayWidths[1], displayHeights[0]),
                    realSize: Size(widths[2]!, safeParentSize.height),
                    layoutProperties: properties,
                    isFreeSpace: true,
                  ),
                  horizontal: true,
                ),
              // Bottom padding.
              if (heights[2] != null)
                PaddingVisualizerWidget(
                  RenderProperties(
                    axis: Axis.horizontal,
                    size: Size(widgetWidth, displayHeights[2]),
                    offset: Offset(displayWidths[0],
                        displayHeights[0] + displayHeights[1]),
                    realSize: Size(safeParentSize.width, heights[2]!),
                    layoutProperties: properties,
                    isFreeSpace: true,
                  ),
                  horizontal: false,
                ),
              BoxChildVisualizer(
                isSelected: true,
                state: this,
                layoutProperties: properties,
                renderProperties: RenderProperties(
                  axis: Axis.horizontal,
                  size: Size(widgetWidth, widgetHeight),
                  offset: Offset(displayWidths[0], displayHeights[0]),
                  realSize: properties!.size,
                  layoutProperties: properties,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  LayoutProperties? get parentProperties {
    final parentElement = properties?.node.parentRenderElement;
    if (parentElement == null) return null;
    final parentProperties = computeLayoutProperties(parentElement);
    return parentProperties;
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final maxHeight = constraints.maxHeight;
    final maxWidth = constraints.maxWidth;

    Widget widget = _buildChild(context);
    final parentProperties = this.parentProperties;
    if (parentProperties != null) {
      // Wrap with a widget visualizer for the parent if there is a valid parent.
      widget = WidgetVisualizer(
        // TODO(jacobr): this node's name can be misleading more often than
        // in the flex case the widget doesn't have its own RenderObject.
        // Consider showing the true ancestor for the summary tree that first
        // has a different render object.
        title: describeBoxName(parentProperties)!,
        largeTitle: true,
        layoutProperties: parentProperties,
        isSelected: false,
        child: VisualizeWidthAndHeightWithConstraints(
          properties: parentProperties,
          warnIfUnconstrained: false,
          child: Padding(
            padding: const EdgeInsets.all(denseSpacing),
            child: widget,
          ),
        ),
      );
    }
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: widget,
    );
  }
}

String? describeBoxName(LayoutProperties properties) {
  // Displaying a high quality name is more ambiguous for the Box case than the
  // Flex case because the RenderObject for each widget is often quite
  // different than the user expected as not all widgets have RenderObjects.
  // As a compromise we currently show 'WidgetName - RenderObjectName'.
  // This is clearer but risks more confusion

  // Widget name.
  var title = properties.node.description;
  final renderDescription = properties.node.renderObject?.description;
  // TODO(jacobr): consider de-emphasizing the render object name by putting it
  // in more transparent text or just calling the widget Parent instead of
  // surfacing a widget name.
  if (renderDescription != null) {
    // Name of the associated RenderObject if one is available.
    title += ' - $renderDescription';
  }
  return title;
}

/// Widget that represents and visualize a direct child of Flex widget.
class BoxChildVisualizer extends StatelessWidget {
  const BoxChildVisualizer({
    Key? key,
    required this.state,
    required this.layoutProperties,
    required this.renderProperties,
    required this.isSelected,
  }) : super(key: key);

  final _BoxLayoutExplorerWidgetState state;

  final bool isSelected;
  final LayoutProperties? layoutProperties;
  final RenderProperties renderProperties;

  LayoutProperties? get root => state.properties;

  LayoutProperties? get properties => renderProperties.layoutProperties;

  @override
  Widget build(BuildContext context) {
    final renderSize = renderProperties.size;
    final renderOffset = renderProperties.offset;

    Widget buildEntranceAnimation(BuildContext context, Widget? child) {
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

    return Positioned(
      top: renderOffset.dy,
      left: renderOffset.dx,
      child: InkWell(
        onTap: () => state.onTap(properties!),
        onDoubleTap: () => state.onDoubleTap(properties!),
        onLongPress: () => state.onDoubleTap(properties!),
        child: SizedBox(
          width: safePositiveDouble(renderSize.width),
          height: safePositiveDouble(renderSize.height),
          child: AnimatedBuilder(
            animation: state.entranceController,
            builder: buildEntranceAnimation,
            child: WidgetVisualizer(
              isSelected: isSelected,
              layoutProperties: layoutProperties!,
              title: describeBoxName(properties!)!,
              // TODO(jacobr): consider surfacing the overflow size information
              // if we determine
              // overflowSide: properties.overflowSide,

              // We only show one child at a time so a large title is safe.
              largeTitle: true,
              child: VisualizeWidthAndHeightWithConstraints(
                arrowHeadSize: arrowHeadSize,
                properties: properties!,
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
