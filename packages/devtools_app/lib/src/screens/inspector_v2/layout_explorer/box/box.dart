// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:devtools_app_shared/ui.dart';
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
    return Container(
      margin: const EdgeInsets.all(denseSpacing),
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
    for (final size in sizes) {
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
    for (final fraction in fractions) {
      output.add(fraction * availableSize);
    }
    return output;
  }

  Widget _buildChild(BuildContext context) {
    final propertiesLocal = properties!;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parentProperties = this.parentProperties ??
        propertiesLocal; // Fall back to this node's properties if there is no parent.

    final parentSize = parentProperties.size;
    final offset = propertiesLocal.node.parentData;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Subtract out one pixel border on each side.
        final availableHeight = constraints.maxHeight - 2;
        final availableWidth = constraints.maxWidth - 2;

        final minFractions = [0.2, 0.5, 0.2];
        // TODO(polinach, jacobr): consider using zeros for zero values,
        // without replacing them with nulls.
        // See https://github.com/flutter/devtools/issues/3931.
        double? nullOutZero(double value) => value != 0.0 ? value : null;
        final widths = [
          nullOutZero(offset.offset.dx),
          propertiesLocal.size.width,
          nullOutZero(
            parentSize.width - (propertiesLocal.size.width + offset.offset.dx),
          ),
        ];
        final heights = [
          nullOutZero(offset.offset.dy),
          propertiesLocal.size.height,
          nullOutZero(
            parentSize.height -
                (propertiesLocal.size.height + offset.offset.dy),
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
        final width0 = widths[0];
        final width2 = widths[2];
        final height0 = heights[0];
        final height2 = heights[2];
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  WidgetTheme.fromName(propertiesLocal.node.description).color,
            ),
          ),
          child: Stack(
            children: [
              LayoutExplorerBackground(colorScheme: colorScheme),
              // Left padding.
              if (width0 != null)
                PaddingVisualizerWidget(
                  RenderProperties(
                    axis: Axis.horizontal,
                    size: Size(displayWidths[0], widgetHeight),
                    offset: Offset(0, displayHeights[0]),
                    realSize: Size(width0, safeParentSize.height),
                    layoutProperties: propertiesLocal,
                    isFreeSpace: true,
                  ),
                  horizontal: true,
                ),
              // Top padding.
              if (height0 != null)
                PaddingVisualizerWidget(
                  RenderProperties(
                    axis: Axis.horizontal,
                    size: Size(widgetWidth, displayHeights[0]),
                    offset: Offset(displayWidths[0], 0),
                    realSize: Size(safeParentSize.width, height0),
                    layoutProperties: propertiesLocal,
                    isFreeSpace: true,
                  ),
                  horizontal: false,
                ),
              // Right padding.
              if (width2 != null)
                PaddingVisualizerWidget(
                  RenderProperties(
                    axis: Axis.horizontal,
                    size: Size(displayWidths[2], widgetHeight),
                    offset: Offset(
                      displayWidths[0] + displayWidths[1],
                      displayHeights[0],
                    ),
                    realSize: Size(width2, safeParentSize.height),
                    layoutProperties: propertiesLocal,
                    isFreeSpace: true,
                  ),
                  horizontal: true,
                ),
              // Bottom padding.
              if (height2 != null)
                PaddingVisualizerWidget(
                  RenderProperties(
                    axis: Axis.horizontal,
                    size: Size(widgetWidth, displayHeights[2]),
                    offset: Offset(
                      displayWidths[0],
                      displayHeights[0] + displayHeights[1],
                    ),
                    realSize: Size(safeParentSize.width, height2),
                    layoutProperties: propertiesLocal,
                    isFreeSpace: true,
                  ),
                  horizontal: false,
                ),
              BoxChildVisualizer(
                isSelected: true,
                state: this,
                layoutProperties: propertiesLocal,
                renderProperties: RenderProperties(
                  axis: Axis.horizontal,
                  size: Size(widgetWidth, widgetHeight),
                  offset: Offset(displayWidths[0], displayHeights[0]),
                  realSize: propertiesLocal.size,
                  layoutProperties: propertiesLocal,
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
        title: describeBoxName(parentProperties),
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

String describeBoxName(LayoutProperties properties) {
  // Displaying a high quality name is more ambiguous for the Box case than the
  // Flex case because the RenderObject for each widget is often quite
  // different than the user expected as not all widgets have RenderObjects.
  // As a compromise we currently show 'WidgetName - RenderObjectName'.
  // This is clearer but risks more confusion

  // Widget name.
  var title = properties.node.description ?? '';
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
