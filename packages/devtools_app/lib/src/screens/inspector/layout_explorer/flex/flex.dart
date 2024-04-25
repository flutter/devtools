// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/diagnostics/diagnostics_node.dart';
import '../../../../shared/diagnostics/inspector_service.dart';
import '../../../../shared/primitives/math_utils.dart';
import '../../inspector_data_models.dart';
import '../ui/arrow.dart';
import '../ui/free_space.dart';
import '../ui/layout_explorer_widget.dart';
import '../ui/theme.dart';
import '../ui/utils.dart';
import '../ui/widget_constraints.dart';
import 'utils.dart';

// TODO(kenz): clean up this file so that we use helper widgets instead of
// methods that pass around build context.

// TODO(kenz): densify the layout explorer visualization for flex widgets.

double get alignmentDropdownMaxSize => scaleByFontFactor(140.0);

class FlexLayoutExplorerWidget extends LayoutExplorerWidget {
  const FlexLayoutExplorerWidget(
    super.inspectorController, {
    super.key,
  });

  static bool shouldDisplay(RemoteDiagnosticsNode node) {
    return (node.isFlex) || (node.parent?.isFlex ?? false);
  }

  @override
  State<FlexLayoutExplorerWidget> createState() =>
      FlexLayoutExplorerWidgetState();
}

class FlexLayoutExplorerWidgetState extends LayoutExplorerWidgetState<
    FlexLayoutExplorerWidget, FlexLayoutProperties> {
  final scrollController = ScrollController();

  Axis get direction => properties!.direction;

  ObjectGroup? get objectGroup =>
      properties!.node.objectGroupApi as ObjectGroup?;

  Color horizontalColor(ColorScheme colorScheme) =>
      properties!.isMainAxisHorizontal
          ? colorScheme.mainAxisColor
          : colorScheme.crossAxisColor;

  Color verticalColor(ColorScheme colorScheme) => properties!.isMainAxisVertical
      ? colorScheme.mainAxisColor
      : colorScheme.crossAxisColor;

  Color horizontalTextColor(ColorScheme colorScheme) =>
      properties!.isMainAxisHorizontal
          ? colorScheme.mainAxisTextColor
          : colorScheme.crossAxisTextColor;

  Color verticalTextColor(ColorScheme colorScheme) =>
      properties!.isMainAxisVertical
          ? colorScheme.mainAxisTextColor
          : colorScheme.crossAxisTextColor;

  String get flexType => properties!.type;

  @override
  RemoteDiagnosticsNode? getRoot(RemoteDiagnosticsNode? node) {
    if (node == null) return null;
    if (!shouldDisplay(node)) return null;
    if (node.isFlex) return node;
    return node.parent;
  }

  @override
  bool shouldDisplay(RemoteDiagnosticsNode node) {
    final selectedNodeLocal = selectedNode;
    if (selectedNodeLocal == null) return false;
    return FlexLayoutExplorerWidget.shouldDisplay(selectedNodeLocal);
  }

  @override
  AnimatedFlexLayoutProperties computeAnimatedProperties(
    FlexLayoutProperties nextProperties,
  ) {
    return AnimatedFlexLayoutProperties(
      // If an animation is in progress, freeze it and start animating from there, else start a fresh animation from widget.properties.
      animatedProperties?.copyWith() as FlexLayoutProperties? ?? properties!,
      nextProperties,
      changeAnimation,
    );
  }

  @override
  FlexLayoutProperties computeLayoutProperties(RemoteDiagnosticsNode node) =>
      FlexLayoutProperties.fromDiagnostics(node);

  @override
  void updateHighlighted(FlexLayoutProperties? newProperties) {
    setState(() {
      if (selectedNode!.isFlex) {
        highlighted = newProperties;
      } else {
        final idx =
            selectedNode?.parent?.childrenNow.indexOf(selectedNode!) ?? -1;
        if (newProperties == null) return;
        if (idx != -1) highlighted = newProperties.children[idx];
      }
    });
  }

  Widget _buildAxisAlignmentDropdown(Axis axis, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final color = axis == direction
        ? colorScheme.mainAxisTextColor
        : colorScheme.crossAxisTextColor;
    List<Enum> alignmentEnumEntries;
    Object? selected;
    final propertiesLocal = properties!;
    if (axis == direction) {
      alignmentEnumEntries = MainAxisAlignment.values;
      selected = propertiesLocal.mainAxisAlignment;
    } else {
      alignmentEnumEntries = CrossAxisAlignment.values.toList(growable: true);
      if (propertiesLocal.textBaseline == null) {
        // TODO(albertusangga): Look for ways to visualize baseline when it is null
        alignmentEnumEntries.remove(CrossAxisAlignment.baseline);
      }
      selected = propertiesLocal.crossAxisAlignment;
    }
    return RotatedBox(
      quarterTurns: axis == Axis.vertical ? 3 : 0,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: alignmentDropdownMaxSize,
          maxHeight: defaultButtonHeight,
        ),
        child: DropdownButton(
          value: selected,
          isDense: true,
          isExpanded: true,
          // Avoid showing an underline for the main axis and cross-axis drop downs.
          underline: const SizedBox(),
          iconEnabledColor: axis == propertiesLocal.direction
              ? colorScheme.mainAxisColor
              : colorScheme.crossAxisColor,
          selectedItemBuilder: (context) {
            return [
              for (var alignment in alignmentEnumEntries)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        alignment.name,
                        style: theme.regularTextStyleWithColor(color),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      height: actionsIconSize,
                      width: actionsIconSize,
                      child: Image.asset(
                        (axis == direction)
                            ? mainAxisAssetImageUrl(
                                direction,
                                alignment as MainAxisAlignment,
                              )
                            : crossAxisAssetImageUrl(
                                direction,
                                alignment as CrossAxisAlignment,
                              ),
                        height: axisAlignmentAssetImageHeight,
                        fit: BoxFit.fitHeight,
                        color: color,
                      ),
                    ),
                  ],
                ),
            ];
          },
          items: [
            for (var alignment in alignmentEnumEntries)
              DropdownMenuItem(
                value: alignment,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: margin),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          alignment.name,
                          style: theme.regularTextStyleWithColor(color),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        height: actionsIconSize,
                        width: actionsIconSize,
                        child: Image.asset(
                          (axis == direction)
                              ? mainAxisAssetImageUrl(
                                  direction,
                                  alignment as MainAxisAlignment,
                                )
                              : crossAxisAssetImageUrl(
                                  direction,
                                  alignment as CrossAxisAlignment,
                                ),
                          fit: BoxFit.fitHeight,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          onChanged: (Object? newSelection) async {
            // newSelection is an object instead of type here because
            // the type is dependent on the `axis` parameter
            // if the axis is the main axis the type should be [MainAxisAlignment]
            // if the axis is the cross axis the type should be [CrossAxisAlignment]
            FlexLayoutProperties changedProperties;
            changedProperties = axis == direction
                ? propertiesLocal.copyWith(
                    mainAxisAlignment: newSelection as MainAxisAlignment?,
                  )
                : propertiesLocal.copyWith(
                    crossAxisAlignment: newSelection as CrossAxisAlignment?,
                  );
            final valueRef = propertiesLocal.node.valueRef;
            markAsDirty();
            await objectGroup!.invokeSetFlexProperties(
              valueRef,
              changedProperties.mainAxisAlignment,
              changedProperties.crossAxisAlignment,
            );
          },
        ),
      ),
    );
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

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxHeight = constraints.maxHeight;
    final maxWidth = constraints.maxWidth;
    final propertiesLocal = properties!;
    final flexDescription = Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: mainAxisArrowIndicatorSize,
          left: crossAxisArrowIndicatorSize + margin,
        ),
        child: InkWell(
          onTap: () => unawaited(onTap(propertiesLocal)),
          child: WidgetVisualizer(
            title: flexType,
            layoutProperties: propertiesLocal,
            isSelected: highlighted == properties,
            overflowSide: propertiesLocal.overflowSide,
            hint: Container(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                'Total Flex Factor: ${propertiesLocal.totalFlex.toInt()}',
                style: theme.regularTextStyleWithColor(emphasizedTextColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            child: VisualizeFlexChildren(
              state: this,
              properties: propertiesLocal,
              children: children,
              highlighted: highlighted,
              scrollController: scrollController,
              direction: direction,
            ),
          ),
        ),
      ),
    );

    final verticalAxisDescription = Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        margin: EdgeInsets.only(top: mainAxisArrowIndicatorSize + margin),
        width: crossAxisArrowIndicatorSize,
        child: Column(
          children: [
            Expanded(
              child: ArrowWrapper.unidirectional(
                arrowColor: verticalColor(colorScheme),
                type: ArrowType.down,
                child: Truncateable(
                  truncate: maxHeight <= minHeightToAllowTruncating,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      propertiesLocal.verticalDirectionDescription,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.regularTextStyleWithColor(
                        verticalTextColor(colorScheme),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Truncateable(
              truncate: maxHeight <= minHeightToAllowTruncating,
              child: _buildAxisAlignmentDropdown(Axis.vertical, theme),
            ),
          ],
        ),
      ),
    );

    final horizontalAxisDescription = Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: EdgeInsets.only(left: crossAxisArrowIndicatorSize + margin),
        height: mainAxisArrowIndicatorSize,
        child: Row(
          children: [
            Expanded(
              child: ArrowWrapper.unidirectional(
                arrowColor: horizontalColor(colorScheme),
                type: ArrowType.right,
                child: Truncateable(
                  truncate: maxWidth <= minWidthToAllowTruncating,
                  child: Text(
                    propertiesLocal.horizontalDirectionDescription,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.regularTextStyleWithColor(
                      horizontalTextColor(colorScheme),
                    ),
                  ),
                ),
              ),
            ),
            Truncateable(
              truncate: maxWidth <= minWidthToAllowTruncating,
              child: _buildAxisAlignmentDropdown(Axis.horizontal, theme),
            ),
          ],
        ),
      ),
    );

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: Stack(
        children: [
          flexDescription,
          verticalAxisDescription,
          horizontalAxisDescription,
        ],
      ),
    );
  }
}

class VisualizeFlexChildren extends StatefulWidget {
  const VisualizeFlexChildren({
    super.key,
    required this.state,
    required this.properties,
    required this.children,
    required this.highlighted,
    required this.scrollController,
    required this.direction,
  });

  final FlexLayoutProperties properties;
  final List<LayoutProperties> children;
  final LayoutProperties? highlighted;
  final ScrollController scrollController;
  final Axis direction;
  final FlexLayoutExplorerWidgetState state;

  @override
  State<VisualizeFlexChildren> createState() => _VisualizeFlexChildrenState();
}

class _VisualizeFlexChildrenState extends State<VisualizeFlexChildren> {
  LayoutProperties? lastHighlighted;
  static final selectedChildKey = GlobalKey(debugLabel: 'selectedChild');

  @override
  Widget build(BuildContext context) {
    if (lastHighlighted != widget.highlighted) {
      lastHighlighted = widget.highlighted;
      if (widget.highlighted != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final selectedRenderObject =
              selectedChildKey.currentContext?.findRenderObject();
          if (selectedRenderObject != null &&
              widget.scrollController.hasClients) {
            unawaited(
              widget.scrollController.position.ensureVisible(
                selectedRenderObject,
                alignment: 0.5,
                duration: defaultDuration,
              ),
            );
          }
        });
      }
    }

    if (!widget.properties.hasChildren) {
      return const CenteredMessage('No Children');
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final contents = Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.primaryColorLight,
        ),
      ),
      margin: const EdgeInsets.only(top: margin, left: margin),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;

          double maxSizeAvailable(Axis axis) {
            return axis == Axis.horizontal ? maxWidth : maxHeight;
          }

          final childrenAndMainAxisSpacesRenderProps =
              widget.properties.childrenRenderProperties(
            smallestRenderWidth: minRenderWidth,
            largestRenderWidth: defaultMaxRenderWidth,
            smallestRenderHeight: minRenderHeight,
            largestRenderHeight: defaultMaxRenderHeight,
            maxSizeAvailable: maxSizeAvailable,
          );

          final renderProperties = childrenAndMainAxisSpacesRenderProps
              .where((renderProps) => !renderProps.isFreeSpace)
              .toList();
          final mainAxisSpaces = childrenAndMainAxisSpacesRenderProps
              .where((renderProps) => renderProps.isFreeSpace)
              .toList();
          final crossAxisSpaces = widget.properties.crossAxisSpaces(
            childrenRenderProperties: renderProperties,
            maxSizeAvailable: maxSizeAvailable,
          );

          final childrenRenderWidgets = <Widget>[];
          Widget? selectedWidget;
          for (var i = 0; i < widget.children.length; i++) {
            final child = widget.children[i];
            final isSelected = widget.highlighted == child;

            final visualizer = FlexChildVisualizer(
              key: isSelected ? selectedChildKey : null,
              state: widget.state,
              layoutProperties: child,
              isSelected: isSelected,
              renderProperties: renderProperties[i],
            );

            if (isSelected) {
              selectedWidget = visualizer;
            } else {
              childrenRenderWidgets.add(visualizer);
            }
          }

          // Selected widget needs to be last to draw its border over other children
          if (selectedWidget != null) {
            childrenRenderWidgets.add(selectedWidget);
          }

          final freeSpacesWidgets = [
            for (var renderProperties in [
              ...mainAxisSpaces,
              ...crossAxisSpaces,
            ])
              FreeSpaceVisualizerWidget(renderProperties),
          ];
          return Scrollbar(
            thumbVisibility: true,
            controller: widget.scrollController,
            child: SingleChildScrollView(
              scrollDirection: widget.properties.direction,
              controller: widget.scrollController,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: maxWidth,
                  minHeight: maxHeight,
                  maxWidth: widget.direction == Axis.horizontal
                      ? sum(
                          childrenAndMainAxisSpacesRenderProps
                              .map((renderSize) => renderSize.width),
                        )
                      : maxWidth,
                  maxHeight: widget.direction == Axis.vertical
                      ? sum(
                          childrenAndMainAxisSpacesRenderProps
                              .map((renderSize) => renderSize.height),
                        )
                      : maxHeight,
                ).normalize(),
                child: Stack(
                  children: [
                    LayoutExplorerBackground(colorScheme: colorScheme),
                    ...freeSpacesWidgets,
                    ...childrenRenderWidgets,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    return VisualizeWidthAndHeightWithConstraints(
      properties: widget.properties,
      child: contents,
    );
  }
}

/// Widget that represents and visualize a direct child of Flex widget.
class FlexChildVisualizer extends StatelessWidget {
  const FlexChildVisualizer({
    super.key,
    required this.state,
    required this.layoutProperties,
    required this.renderProperties,
    required this.isSelected,
  });

  final FlexLayoutExplorerWidgetState state;

  final bool isSelected;

  final LayoutProperties layoutProperties;

  final RenderProperties renderProperties;

  // TODO(polina-c, jacob314): consider refactoring to remove `!`.
  FlexLayoutProperties get root => state.properties!;

  // TODO(polina-c, jacob314): consider refactoring to remove `!`.
  LayoutProperties get properties => renderProperties.layoutProperties!;

  ObjectGroup? get objectGroup =>
      properties.node.objectGroupApi as ObjectGroup?;

  void onChangeFlexFactor(int? newFlexFactor) async {
    state.markAsDirty();
    await objectGroup!.invokeSetFlexFactor(
      properties.node.valueRef,
      newFlexFactor,
    );
  }

  void onChangeFlexFit(FlexFit? newFlexFit) async {
    state.markAsDirty();
    await objectGroup!.invokeSetFlexFit(
      properties.node.valueRef,
      newFlexFit!,
    );
  }

  Widget _buildFlexFactorChangerDropdown(
    int maximumFlexFactor,
    ThemeData theme,
  ) {
    final propertiesLocal = properties;

    Widget buildMenuitemChild(int? flexFactor) {
      return Text(
        'flex: $flexFactor',
        style: flexFactor == propertiesLocal.flexFactor
            ? theme.boldTextStyle.copyWith(color: emphasizedTextColor)
            : theme.regularTextStyleWithColor(emphasizedTextColor),
      );
    }

    DropdownMenuItem<int> buildMenuItem(int? flexFactor) {
      return DropdownMenuItem(
        value: flexFactor,
        child: buildMenuitemChild(flexFactor),
      );
    }

    return DropdownButton<int>(
      value: propertiesLocal.flexFactor?.toInt().clamp(0, maximumFlexFactor),
      onChanged: onChangeFlexFactor,
      iconEnabledColor: textColor,
      underline: buildUnderline(),
      items: <DropdownMenuItem<int>>[
        buildMenuItem(null),
        for (var i = 0; i <= maximumFlexFactor; ++i) buildMenuItem(i),
      ],
    );
  }

  Widget _buildFlexFitChangerDropdown(ThemeData theme) {
    Widget flexFitDescription(FlexFit flexFit) => Text(
          'fit: ${flexFit.name}',
          style: theme.regularTextStyleWithColor(emphasizedTextColor),
        );

    final propertiesLocal = properties;

    // Disable FlexFit changer if widget is Expanded.
    if (propertiesLocal.description == 'Expanded') {
      return flexFitDescription(FlexFit.tight);
    }

    DropdownMenuItem<FlexFit> buildMenuItem(FlexFit flexFit) {
      return DropdownMenuItem(
        value: flexFit,
        child: flexFitDescription(flexFit),
      );
    }

    return DropdownButton<FlexFit>(
      value: propertiesLocal.flexFit,
      onChanged: onChangeFlexFit,
      underline: buildUnderline(),
      iconEnabledColor: emphasizedTextColor,
      items: <DropdownMenuItem<FlexFit>>[
        buildMenuItem(FlexFit.loose),
        if (propertiesLocal.description != 'Expanded')
          buildMenuItem(FlexFit.tight),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    // TODO(https://github.com/flutter/devtools/issues/4058) allow more dynamic
    // flex factor input
    final currentFlexFactor = properties.flexFactor?.toInt() ?? 0;
    final currentMaxFlexFactor =
        math.max(currentFlexFactor, maximumFlexFactorOptions);

    return Container(
      margin: const EdgeInsets.only(
        top: margin,
        left: margin,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: _buildFlexFactorChangerDropdown(currentMaxFlexFactor, theme),
          ),
          if (!properties.hasFlexFactor)
            Text(
              'unconstrained ${root.isMainAxisHorizontal ? 'horizontal' : 'vertical'}',
              style: theme.regularTextStyle.copyWith(
                color: theme.colorScheme.unconstrainedColor,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              textScaler: const TextScaler.linear(smallTextScaleFactor),
              textAlign: TextAlign.center,
            ),
          _buildFlexFitChangerDropdown(theme),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renderSize = renderProperties.size;
    final renderOffset = renderProperties.offset;
    final propertiesLocal = properties;
    final rootLocal = root;

    Widget buildEntranceAnimation(BuildContext _, Widget? child) {
      final vertical = rootLocal.isMainAxisVertical;
      final horizontal = rootLocal.isMainAxisHorizontal;

      late Size size;
      size = propertiesLocal.hasFlexFactor
          ? SizeTween(
              begin: Size(
                horizontal ? minRenderWidth - entranceMargin : renderSize.width,
                vertical ? minRenderHeight - entranceMargin : renderSize.height,
              ),
              end: renderSize,
            ).evaluate(state.entranceCurve)!
          : renderSize;
      // Not-expanded widgets enter much faster.
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
      child: GestureDetector(
        onTap: () => unawaited(state.onTap(propertiesLocal)),
        onDoubleTap: () => state.onDoubleTap(propertiesLocal),
        onLongPress: () => state.onDoubleTap(propertiesLocal),
        child: SizedBox(
          width: renderSize.width,
          height: renderSize.height,
          child: AnimatedBuilder(
            animation: state.entranceController,
            builder: buildEntranceAnimation,
            child: WidgetVisualizer(
              isSelected: isSelected,
              layoutProperties: layoutProperties,
              title: propertiesLocal.description ?? '',
              overflowSide: propertiesLocal.overflowSide,
              child: VisualizeWidthAndHeightWithConstraints(
                arrowHeadSize: arrowHeadSize,
                properties: propertiesLocal,
                child: Align(
                  alignment: Alignment.topRight,
                  child: _buildContent(Theme.of(context)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// define the number of flex factor to be shown in the flex dropdown button
  /// for example if it's set to 5 the dropdown will consist of 6 items (null and 0..5)
  static const maximumFlexFactorOptions = 5;
}
