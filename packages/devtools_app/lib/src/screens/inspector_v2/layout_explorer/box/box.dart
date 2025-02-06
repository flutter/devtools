// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import '../../../../shared/diagnostics/diagnostics_node.dart';
import '../../../../shared/primitives/utils.dart';
import '../../inspector_controller.dart';
import '../../inspector_data_models.dart';
import '../ui/free_space.dart';
import '../ui/theme.dart';
import '../ui/utils.dart';
import '../ui/widget_constraints.dart';
import '../ui/widgets_theme.dart';

class BoxLayoutExplorerWidget extends StatelessWidget {
  const BoxLayoutExplorerWidget(
    this.inspectorController, {
    super.key,
    required this.layoutProperties,
    required this.selectedNode,
  });

  final InspectorController inspectorController;
  final LayoutProperties? layoutProperties;
  final RemoteDiagnosticsNode? selectedNode;

  @override
  Widget build(BuildContext context) {
    if (layoutProperties == null) {
      final selectedNodeLocal = selectedNode;
      return Center(
        child: Text(
          '${selectedNodeLocal?.description ?? 'Widget'} has no layout properties to display.',
          textAlign: TextAlign.center,
          overflow: TextOverflow.clip,
        ),
      );
    }
    return LayoutBuilder(builder: _buildLayout);
  }

  List<Widget> _paddingWidgets({
    required LayoutProperties childProperties,
    required LayoutProperties parentProperties,
    required LayoutWidthsAndHeights widthsAndHeights,
    required LayoutWidthsAndHeights displayWidthsAndHeights,
    required ColorScheme colorScheme,
    required Color widgetColor,
  }) {
    if (!widthsAndHeights.hasAnyPadding) return <Widget>[];

    final LayoutWidthsAndHeights(
      :topPadding,
      :bottomPadding,
      :leftPadding,
      :rightPadding,
      :hasTopPadding,
      :hasBottomPadding,
      :hasLeftPadding,
      :hasRightPadding,
    ) = widthsAndHeights;

    final displayWidgetHeight = displayWidthsAndHeights.widgetHeight;
    final displayWidgetWidth = displayWidthsAndHeights.widgetWidth;
    final displayTopPadding = displayWidthsAndHeights.topPadding;
    final displayBottomPadding = displayWidthsAndHeights.bottomPadding;
    final displayLeftPadding = displayWidthsAndHeights.leftPadding;
    final displayRightPadding = displayWidthsAndHeights.rightPadding;

    final parentHeight = parentProperties.size.height;
    final parentWidth = parentProperties.size.width;

    return [
      LayoutExplorerBackground(colorScheme: colorScheme),
      PositionedBackgroundLabel(
        labelText: _describeBoxName(parentProperties),
        labelColor: widgetColor,
        hasTopPadding: hasTopPadding,
        hasBottomPadding: hasBottomPadding,
        hasLeftPadding: hasLeftPadding,
        hasRightPadding: hasRightPadding,
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

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final propertiesLocal = layoutProperties!;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parentProperties = propertiesLocal.parentLayoutProperties!;

    final child = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Subtract out one pixel border on each side.
        final availableHeight = constraints.maxHeight - 2;
        final availableWidth = constraints.maxWidth - 2;

        final widgetWidths = propertiesLocal.widgetWidths;
        final widgetHeights = propertiesLocal.widgetHeights;

        final widthsAndHeights = LayoutWidthsAndHeights(
          widths: widgetWidths!,
          heights: widgetHeights!,
        );

        final displayWidths = _simpleFractionalLayout(
          availableSize: availableWidth,
          sizes: widgetWidths,
        );
        final displayHeights = _simpleFractionalLayout(
          availableSize: availableHeight,
          sizes: widgetHeights,
        );
        final displayWidthsAndHeights = LayoutWidthsAndHeights(
          widths: displayWidths,
          heights: displayHeights,
        );

        final widgetColor =
            WidgetTheme.fromName(propertiesLocal.node.description).color;
        return Column(
          children: [
            Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              decoration: BoxDecoration(border: Border.all(color: widgetColor)),
              child: Stack(
                children: [
                  ..._paddingWidgets(
                    childProperties: propertiesLocal,
                    parentProperties: parentProperties,
                    widthsAndHeights: widthsAndHeights,
                    displayWidthsAndHeights: displayWidthsAndHeights,
                    colorScheme: colorScheme,
                    widgetColor: widgetColor,
                  ),
                  BoxChildVisualizer(
                    isSelected: true,
                    layoutProperties: propertiesLocal,
                    renderProperties: RenderProperties(
                      axis: Axis.horizontal,
                      size: Size(
                        displayWidthsAndHeights.widgetWidth,
                        displayWidthsAndHeights.widgetHeight,
                      ),
                      offset: Offset(
                        displayWidthsAndHeights.leftPadding,
                        displayWidthsAndHeights.topPadding,
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

String _describeBoxName(LayoutProperties properties) =>
    properties.node.description ?? '';

/// Represents a box widget and its surrounding padding.
class BoxChildAndPaddingVisualizer extends StatelessWidget {
  const BoxChildAndPaddingVisualizer({
    super.key,
    required this.layoutProperties,
    required this.renderProperties,
    required this.isSelected,
  });

  final bool isSelected;
  final LayoutProperties layoutProperties;
  final RenderProperties renderProperties;

  LayoutProperties? get properties => renderProperties.layoutProperties;

  @override
  Widget build(BuildContext context) {
    final renderSize = renderProperties.size;
    final renderOffset = renderProperties.offset;

    final propertiesLocal = properties!;

    return Positioned(
      top: renderOffset.dy,
      left: renderOffset.dx,
      child: SizedBox(
        width: safePositiveDouble(renderSize.width),
        height: safePositiveDouble(renderSize.height),
        child: WidgetVisualizer(
          isSelected: isSelected,
          layoutProperties: layoutProperties,
          title: _describeBoxName(propertiesLocal),
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
    );
  }
}

/// Widget that represents and visualize a direct child of Flex widget.
class BoxChildVisualizer extends StatelessWidget {
  const BoxChildVisualizer({
    super.key,
    required this.layoutProperties,
    required this.renderProperties,
    required this.isSelected,
  });

  final bool isSelected;
  final LayoutProperties layoutProperties;
  final RenderProperties renderProperties;

  LayoutProperties? get properties => renderProperties.layoutProperties;

  @override
  Widget build(BuildContext context) {
    final renderSize = renderProperties.size;
    final renderOffset = renderProperties.offset;

    final propertiesLocal = properties!;

    return Positioned(
      top: renderOffset.dy,
      left: renderOffset.dx,
      child: SizedBox(
        width: safePositiveDouble(renderSize.width),
        height: safePositiveDouble(renderSize.height),
        child: WidgetVisualizer(
          isSelected: isSelected,
          layoutProperties: layoutProperties,
          title: _describeBoxName(propertiesLocal),
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
    );
  }
}

/// The percent of the visualizer dedicating to a single padding block when
/// the box child has multiple padding blocks.
const _narrowPaddingVisualizerPercent = 0.3;

/// The percent of the visualizer dedicating to a single padding block when
/// the box child has only one padding block.
const _widePaddingVisualizerPercent = 0.35;

/// Simplistic layout algorithm that will return [WidgetSizes] for the widget
/// display based on the display's [availableSize] and the real widget's
/// [WidgetSizes].
///
/// Uses a constant `paddingFraction` for the display padding, regardless of
/// the actual size.
WidgetSizes _simpleFractionalLayout({
  required double availableSize,
  required WidgetSizes sizes,
}) {
  final paddingASize = sizes.paddingA;
  final paddingBSize = sizes.paddingB;

  final paddingFraction =
      paddingASize > 0 && paddingBSize > 0
          ? _narrowPaddingVisualizerPercent
          : _widePaddingVisualizerPercent;

  final paddingAFraction = paddingASize > 0 ? paddingFraction : 0.0;
  final paddingBFraction = paddingBSize > 0 ? paddingFraction : 0.0;
  final widgetFraction = 1 - paddingAFraction - paddingBFraction;

  return (
    type: sizes.type,
    paddingA: paddingAFraction * availableSize,
    widgetSize: widgetFraction * availableSize,
    paddingB: paddingBFraction * availableSize,
  );
}
