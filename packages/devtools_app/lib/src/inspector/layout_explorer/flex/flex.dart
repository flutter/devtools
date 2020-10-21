// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../common_widgets.dart';
import '../../../theme.dart';
import '../../../ui/theme.dart';
import '../../../utils.dart';
import '../../diagnostics_node.dart';
import '../../inspector_controller.dart';
import '../../inspector_data_models.dart';
import '../../inspector_service.dart';
import '../../inspector_service_flutter_extension.dart';
import 'arrow.dart';
import 'free_space.dart';
import 'overflow_indicator_painter.dart';
import 'utils.dart';

const margin = 8.0;

const arrowHeadSize = 8.0;
const arrowMargin = 4.0;
const arrowStrokeWidth = 1.5;

/// Hardcoded sizes for scaling the flex children widget properly.
const minRenderWidth = 250.0;
const minRenderHeight = 250.0;

const minPadding = 2.0;
const overflowTextHorizontalPadding = 8.0;

/// The size to shrink a widget by when animating it in.
const entranceMargin = 50.0;

const defaultMaxRenderWidth = 400.0;
const defaultMaxRenderHeight = 400.0;

const widgetTitleMaxWidthPercentage = 0.75;

/// Hardcoded arrow size respective to its cross axis (because it's unconstrained).
const heightAndConstraintIndicatorSize = 48.0;
const widthAndConstraintIndicatorSize = 56.0;
const mainAxisArrowIndicatorSize = 48.0;
const crossAxisArrowIndicatorSize = 48.0;

const heightOnlyIndicatorSize = 72.0;
const widthOnlyIndicatorSize = 32.0;

/// Minimum size to display width/height inside the arrow
const minWidthToDisplayWidthInsideArrow = 200.0;
const minHeightToDisplayHeightInsideArrow = 200.0;

const largeTextScaleFactor = 1.2;
const smallTextScaleFactor = 0.8;

/// Height for limiting asset image (selected one in the drop down).
const axisAlignmentAssetImageHeight = 24.0;

/// Width for limiting asset image (when drop down menu is open for the vertical).
const axisAlignmentAssetImageWidth = 96.0;
const dropdownMaxSize = 220.0;

const minHeightToAllowTruncating = 375.0;
const minWidthToAllowTruncating = 375.0;

// Story of Layout colors
const mainAxisLightColor = Color(0xff2c5daa);
const mainAxisDarkColor = Color(0xff2c5daa);
const rowColor = Color(0xff2c5daa);
const columnColor = Color(0xff77974d);
const regularWidgetColor = Color(0xff88b1de);

const selectedWidgetColor = Color(0xff36c6f4);

const textColor = Color(0xff55767f);
const emphasizedTextColor = Color(0xff009aca);

const crossAxisLightColor = Color(0xff8ac652);
const crossAxisDarkColor = Color(0xff8ac652);

const mainAxisTextColorLight = Color(0xFF1375bc);
const mainAxisTextColorDark = Color(0xFF1375bc);

const crossAxisTextColorLight = Color(0xFF66672C);
const crossAxisTextColorsDark = Color(0xFFB3D25A);

const overflowBackgroundColorDark = Color(0xFFB00020);
const overflowBackgroundColorLight = Color(0xFFB00020);

const overflowTextColorDark = Color(0xfff5846b);
const overflowTextColorLight = Color(0xffdea089);

const backgroundColorSelectedDark = Color(
    0x4d474747); // TODO(jacobr): we would like Color(0x4dedeeef) but that makes the background show through.
const backgroundColorSelectedLight = Color(0x4dedeeef);

extension LayoutExplorerColorScheme on ColorScheme {
  Color get mainAxisColor => isLight ? mainAxisLightColor : mainAxisDarkColor;

  Color get widgetNameColor => isLight ? Colors.white : Colors.black;

  Color get crossAxisColor =>
      isLight ? crossAxisLightColor : crossAxisDarkColor;

  Color get mainAxisTextColor =>
      isLight ? mainAxisTextColorLight : mainAxisTextColorDark;

  Color get crossAxisTextColor =>
      isLight ? crossAxisTextColorLight : crossAxisTextColorsDark;

  Color get overflowBackgroundColor =>
      isLight ? overflowBackgroundColorLight : overflowBackgroundColorDark;

  Color get overflowTextColor =>
      isLight ? overflowTextColorLight : overflowTextColorDark;

  Color get backgroundColorSelected =>
      isLight ? backgroundColorSelectedLight : backgroundColorSelectedDark;

  Color get backgroundColor =>
      isLight ? backgroundColorLight : backgroundColorDark;

  Color get unconstrainedColor =>
      isLight ? unconstrainedLightColor : unconstrainedDarkColor;
}

const backgroundColorDark = Color(0xff30302f);
const backgroundColorLight = Color(0xffffffff);

const unconstrainedDarkColor = Color(0xffdea089);
const unconstrainedLightColor = Color(0xfff5846b);

const widthIndicatorColor = textColor;
const heightIndicatorColor = textColor;

extension LayoutThemeDataExtension on ThemeData {}

const negativeSpaceDarkAssetName =
    'assets/img/layout_explorer/negative_space_dark.png';
const negativeSpaceLightAssetName =
    'assets/img/layout_explorer/negative_space_light.png';

const dimensionIndicatorTextStyle = TextStyle(
  height: 1.0,
  letterSpacing: 1.1,
  color: emphasizedTextColor,
);

TextStyle overflowingDimensionIndicatorTextStyle(ColorScheme colorScheme) =>
    dimensionIndicatorTextStyle.merge(
      TextStyle(
        fontWeight: FontWeight.bold,
        color: colorScheme.overflowTextColor,
      ),
    );

Widget buildUnderline() {
  return Container(
    height: 1.0,
    decoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: textColor,
          width: 0.0,
        ),
      ),
    ),
  );
}

const maxRequestsPerSecond = 3.0;

/// Text widget for displaying width / height.
Widget dimensionDescription(
  TextSpan description,
  bool overflow,
  ColorScheme colorScheme,
) {
  final text = Text.rich(
    description,
    textAlign: TextAlign.center,
    style: overflow
        ? overflowingDimensionIndicatorTextStyle(colorScheme)
        : dimensionIndicatorTextStyle,
    overflow: TextOverflow.ellipsis,
  );
  if (overflow)
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: minPadding,
        horizontal: overflowTextHorizontalPadding,
      ),
      decoration: BoxDecoration(
        color: colorScheme.overflowBackgroundColor,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Center(child: text),
    );
  return text;
}

Widget _visualizeWidthAndHeightWithConstraints(
  BuildContext context, {
  @required Widget widget,
  @required LayoutProperties properties,
  double arrowHeadSize = defaultIconSize,
}) {
  final showChildrenWidthsSum =
      properties is FlexLayoutProperties && properties.isOverflowWidth;
  const bottomHeight = widthAndConstraintIndicatorSize;
  const rightWidth = heightAndConstraintIndicatorSize;
  final colorScheme = Theme.of(context).colorScheme;

  final heightDescription = RotatedBox(
    quarterTurns: 1,
    child: dimensionDescription(
        TextSpan(
          children: [
            TextSpan(
              text: '${properties.describeHeight()}',
            ),
            if (properties is! FlexLayoutProperties ||
                !properties.isOverflowHeight)
              const TextSpan(text: '\n'),
            TextSpan(
              text: ' (${properties.describeHeightConstraints()})',
              style: properties.constraints.hasBoundedHeight
                  ? null
                  : TextStyle(color: colorScheme.unconstrainedColor),
            ),
            if (properties is FlexLayoutProperties &&
                properties.isOverflowHeight)
              TextSpan(
                text: '\nchildren take: '
                    '${toStringAsFixed(sum(properties.childrenHeights))}',
              ),
          ],
        ),
        properties.isOverflowHeight,
        colorScheme),
  );
  final right = Container(
    margin: const EdgeInsets.only(
      top: margin,
      left: margin,
      bottom: bottomHeight,
      right: minPadding, // custom margin for not sticking to the corner
    ),
    child: LayoutBuilder(builder: (context, constraints) {
      final displayHeightOutsideArrow =
          constraints.maxHeight < minHeightToDisplayHeightInsideArrow;
      return Row(
        children: [
          Truncateable(
            truncate: !displayHeightOutsideArrow,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: arrowMargin),
              child: ArrowWrapper.bidirectional(
                arrowColor: heightIndicatorColor,
                arrowStrokeWidth: arrowStrokeWidth,
                arrowHeadSize: arrowHeadSize,
                direction: Axis.vertical,
                child: displayHeightOutsideArrow ? null : heightDescription,
              ),
            ),
          ),
          if (displayHeightOutsideArrow)
            Flexible(
              child: heightDescription,
            ),
        ],
      );
    }),
  );

  final widthDescription = dimensionDescription(
    TextSpan(
      children: [
        TextSpan(text: '${properties.describeWidth()}; '),
        if (!showChildrenWidthsSum) const TextSpan(text: '\n'),
        TextSpan(
          text: '(${properties.describeWidthConstraints()})',
          style: properties.constraints.hasBoundedWidth
              ? null
              : TextStyle(color: colorScheme.unconstrainedColor),
        ),
        if (showChildrenWidthsSum)
          TextSpan(
            text: '\nchildren take '
                '${toStringAsFixed(sum(properties.childrenWidths))}',
          )
      ],
    ),
    properties.isOverflowWidth,
    colorScheme,
  );
  final bottom = Container(
    margin: const EdgeInsets.only(
      top: margin,
      left: margin,
      right: rightWidth,
      bottom: minPadding,
    ),
    child: LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      final displayWidthOutsideArrow =
          maxWidth < minWidthToDisplayWidthInsideArrow;
      return Column(
        children: [
          Truncateable(
            truncate: !displayWidthOutsideArrow,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: arrowMargin),
              child: ArrowWrapper.bidirectional(
                arrowColor: widthIndicatorColor,
                arrowHeadSize: arrowHeadSize,
                arrowStrokeWidth: arrowStrokeWidth,
                direction: Axis.horizontal,
                child: displayWidthOutsideArrow ? null : widthDescription,
              ),
            ),
          ),
          if (displayWidthOutsideArrow)
            Flexible(
              child: Container(
                padding: const EdgeInsets.only(top: minPadding),
                child: widthDescription,
              ),
            ),
        ],
      );
    }),
  );
  return BorderLayout(
    center: widget,
    right: right,
    rightWidth: rightWidth,
    bottom: bottom,
    bottomHeight: bottomHeight,
  );
}

class FlexLayoutExplorerWidget extends StatefulWidget {
  const FlexLayoutExplorerWidget(
    this.inspectorController, {
    Key key,
  }) : super(key: key);

  final InspectorController inspectorController;

  static bool shouldDisplay(RemoteDiagnosticsNode node) {
    return (node?.isFlex ?? false) || (node?.parent?.isFlex ?? false);
  }

  @override
  _FlexLayoutExplorerWidgetState createState() =>
      _FlexLayoutExplorerWidgetState();
}

class _FlexLayoutExplorerWidgetState extends State<FlexLayoutExplorerWidget>
    with TickerProviderStateMixin
    implements InspectorServiceClient {
  _FlexLayoutExplorerWidgetState() {
    _onSelectionChangedCallback = onSelectionChanged;
  }

  AnimationController entranceController;
  CurvedAnimation entranceCurve;
  AnimationController changeController;

  CurvedAnimation changeAnimation;
  AnimatedFlexLayoutProperties _animatedProperties;
  FlexLayoutProperties _previousProperties;

  FlexLayoutProperties _properties;

  FlexLayoutProperties get properties =>
      _previousProperties ?? _animatedProperties ?? _properties;

  InspectorObjectGroupManager objectGroupManager;

  LayoutProperties highlighted;

  RemoteDiagnosticsNode get selectedNode =>
      inspectorController?.selectedNode?.diagnostic;

  Size get size => properties.size;

  List<LayoutProperties> get children => properties.displayChildren;

  Axis get direction => properties.direction;

  Color horizontalColor(ColorScheme colorScheme) =>
      properties.isMainAxisHorizontal
          ? colorScheme.mainAxisColor
          : colorScheme.crossAxisColor;

  Color verticalColor(ColorScheme colorScheme) => properties.isMainAxisVertical
      ? colorScheme.mainAxisColor
      : colorScheme.crossAxisColor;

  Color horizontalTextColor(ColorScheme colorScheme) =>
      properties.isMainAxisHorizontal
          ? colorScheme.mainAxisTextColor
          : colorScheme.crossAxisTextColor;

  Color verticalTextColor(ColorScheme colorScheme) =>
      properties.isMainAxisVertical
          ? colorScheme.mainAxisTextColor
          : colorScheme.crossAxisTextColor;

  String get flexType => properties.type;

  InspectorController get inspectorController => widget.inspectorController;

  InspectorService get inspectorService =>
      inspectorController?.inspectorService;

  RateLimiter rateLimiter;

  RemoteDiagnosticsNode getRoot(RemoteDiagnosticsNode node) {
    if (!FlexLayoutExplorerWidget.shouldDisplay(node)) return null;
    if (node.isFlex) return node;
    return node.parent;
  }

  Future<void> Function() _onSelectionChangedCallback;

  Future<void> onSelectionChanged() async {
    if (!mounted) return;
    if (!FlexLayoutExplorerWidget.shouldDisplay(selectedNode)) {
      return;
    }
    final prevRootId = id(_properties?.node);
    final newRootId = id(getRoot(selectedNode));
    final shouldFetch = prevRootId != newRootId;
    if (shouldFetch) {
      _dirty = false;
      final newSelection = await fetchFlexLayoutProperties();
      _setProperties(newSelection);
    } else {
      _updateHighlighted(_properties);
    }
  }

  void _registerInspectorControllerService() {
    inspectorController?.addSelectionListener(_onSelectionChangedCallback);
    inspectorService?.addClient(this);
  }

  void _unregisterInspectorControllerService() {
    inspectorController?.removeSelectionListener(_onSelectionChangedCallback);
    inspectorService?.removeClient(this);
  }

  @override
  void initState() {
    super.initState();
    rateLimiter = RateLimiter(maxRequestsPerSecond, refresh);
    _registerInspectorControllerService();
    _initAnimationStates();
    _updateObjectGroupManager();
    // TODO(djshuckerow): put inspector controller in Controllers and
    // update on didChangeDependencies.
    _animateProperties();
  }

  @override
  void didUpdateWidget(FlexLayoutExplorerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateObjectGroupManager();
    _animateProperties();
    if (oldWidget.inspectorController != inspectorController) {
      _unregisterInspectorControllerService();
      _registerInspectorControllerService();
    }
  }

  @override
  void dispose() {
    entranceController.dispose();
    changeController.dispose();
    _unregisterInspectorControllerService();
    super.dispose();
  }

  void _animateProperties() {
    if (_animatedProperties != null) {
      changeController.forward();
    }
    if (_previousProperties != null) {
      entranceController.reverse();
    } else {
      entranceController.forward();
    }
  }

  void _changeProperties(FlexLayoutProperties nextProperties) {
    if (!mounted || nextProperties == null) return;
    _updateHighlighted(nextProperties);
    setState(() {
      _animatedProperties = AnimatedFlexLayoutProperties(
        // If an animation is in progress, freeze it and start animating from there, else start a fresh animation from widget.properties.
        _animatedProperties?.copyWith() ?? _properties,
        nextProperties,
        changeAnimation,
      );
      changeController.forward(from: 0.0);
    });
  }

  /// Required for getting all information required to visualize the Flex layout.
  Future<FlexLayoutProperties> fetchFlexLayoutProperties() async {
    objectGroupManager?.cancelNext();
    final nextObjectGroup = objectGroupManager.next;
    final node = await nextObjectGroup.getLayoutExplorerNode(
      getRoot(selectedNode),
    );
    if (!nextObjectGroup.disposed) {
      assert(objectGroupManager.next == nextObjectGroup);
      objectGroupManager.promoteNext();
    }
    return FlexLayoutProperties.fromDiagnostics(node);
  }

  String id(RemoteDiagnosticsNode node) => node?.dartDiagnosticRef?.id;

  void _updateHighlighted(FlexLayoutProperties newProperties) {
    setState(() {
      if (selectedNode.isFlex) {
        highlighted = newProperties;
      } else {
        final idx = selectedNode.parent.childrenNow.indexOf(selectedNode);
        if (newProperties == null || newProperties.children == null) return;
        if (idx != -1) highlighted = newProperties.children[idx];
      }
    });
  }

  void _setProperties(FlexLayoutProperties newProperties) {
    if (!mounted) return;
    _updateHighlighted(newProperties);
    if (_properties == newProperties) {
      return;
    }
    setState(() {
      _previousProperties ??= _properties;
      _properties = newProperties;
    });
    _animateProperties();
  }

  void _initAnimationStates() {
    entranceController = longAnimationController(
      this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          setState(() {
            _previousProperties = null;
            entranceController.forward();
          });
        }
      });
    entranceCurve = defaultCurvedAnimation(entranceController);
    changeController = longAnimationController(this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _properties = _animatedProperties.end;
            _animatedProperties = null;
            changeController.value = 0.0;
          });
        }
      });
    changeAnimation = defaultCurvedAnimation(changeController);
  }

  void _updateObjectGroupManager() {
    final service = inspectorController.inspectorService;
    if (service != objectGroupManager?.inspectorService) {
      objectGroupManager = InspectorObjectGroupManager(
        service,
        'flex-layout',
      );
    }
    onSelectionChanged();
  }

  // update selected widget in the device without triggering selection listener event.
  // this is required so that we don't change focus
  //   when tapping on a child is also Flex-based widget.
  Future<void> setSelectionInspector(RemoteDiagnosticsNode node) async {
    final service = await node.inspectorService;
    await service.setSelectionInspector(node.valueRef, false);
  }

  // update selected widget and trigger selection listener event to change focus.
  void refreshSelection(RemoteDiagnosticsNode node) {
    inspectorController.refreshSelection(node, node, true);
  }

  Future<void> onTap(LayoutProperties properties) async {
    setState(() => highlighted = properties);
    await setSelectionInspector(properties.node);
  }

  void onDoubleTap(LayoutProperties properties) {
    refreshSelection(properties.node);
  }

  Future<void> refresh() async {
    if (!_dirty) return;
    _dirty = false;
    final updatedProperties = await fetchFlexLayoutProperties();
    if (updatedProperties != null) _changeProperties(updatedProperties);
  }

  Widget _visualizeFlex(BuildContext context) {
    if (!properties.hasChildren)
      return const Center(child: Text('No Children'));

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final widget = Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.primaryColorLight,
        ),
      ),
      margin: const EdgeInsets.only(top: margin, left: margin),
      child: LayoutBuilder(builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        double maxSizeAvailable(Axis axis) {
          return axis == Axis.horizontal ? maxWidth : maxHeight;
        }

        final childrenAndMainAxisSpacesRenderProps =
            properties.childrenRenderProperties(
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
        final crossAxisSpaces = properties.crossAxisSpaces(
          childrenRenderProperties: renderProperties,
          maxSizeAvailable: maxSizeAvailable,
        );

        final childrenRenderWidgets = <Widget>[];
        for (var i = 0; i < children.length; i++) {
          final child = children[i];
          final isSelected = highlighted == child;

          childrenRenderWidgets.add(FlexChildVisualizer(
            state: this,
            layoutProperties: child,
            isSelected: isSelected,
            renderProperties: renderProperties[i],
          ));
        }

        final freeSpacesWidgets = [
          for (var renderProperties in [...mainAxisSpaces, ...crossAxisSpaces])
            FreeSpaceVisualizerWidget(renderProperties),
        ];
        return SingleChildScrollView(
          scrollDirection: properties.direction,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: maxWidth,
              minHeight: maxHeight,
              maxWidth: direction == Axis.horizontal
                  ? sum(childrenAndMainAxisSpacesRenderProps
                      .map((renderSize) => renderSize.width))
                  : maxWidth,
              maxHeight: direction == Axis.vertical
                  ? sum(childrenAndMainAxisSpacesRenderProps
                      .map((renderSize) => renderSize.height))
                  : maxHeight,
            ).normalize(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: colorScheme.isLight ? 0.3 : 0.2,
                    child: Image.asset(
                      colorScheme.isLight
                          ? negativeSpaceLightAssetName
                          : negativeSpaceDarkAssetName,
                      fit: BoxFit.none,
                      repeat: ImageRepeat.repeat,
                      alignment: Alignment.topLeft,
                    ),
                  ),
                ),
                ...freeSpacesWidgets,
                ...childrenRenderWidgets,
              ],
            ),
          ),
        );
      }),
    );
    return _visualizeWidthAndHeightWithConstraints(
      context,
      widget: widget,
      properties: properties,
    );
  }

  Widget _buildAxisAlignmentDropdown(Axis axis, ColorScheme colorScheme) {
    final color = axis == direction
        ? colorScheme.mainAxisTextColor
        : colorScheme.crossAxisTextColor;
    List<Object> alignmentEnumEntries;
    Object selected;
    if (axis == direction) {
      alignmentEnumEntries = MainAxisAlignment.values;
      selected = properties.mainAxisAlignment;
    } else {
      alignmentEnumEntries = CrossAxisAlignment.values.toList(growable: true);
      if (properties.textBaseline == null) {
        // TODO(albertusangga): Look for ways to visualize baseline when it is null
        alignmentEnumEntries.remove(CrossAxisAlignment.baseline);
      }
      selected = properties.crossAxisAlignment;
    }
    return RotatedBox(
      quarterTurns: axis == Axis.vertical ? 3 : 0,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: dropdownMaxSize,
          maxHeight: dropdownMaxSize,
        ),
        child: DropdownButton(
          value: selected,
          isExpanded: true,
          // Avoid showing an underline for the main axis and cross-axis drop downs.
          underline: const SizedBox(),
          iconEnabledColor: axis == properties.direction
              ? colorScheme.mainAxisColor
              : colorScheme.crossAxisColor,
          selectedItemBuilder: (context) {
            return [
              for (var alignment in alignmentEnumEntries)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        describeEnum(alignment),
                        style: TextStyle(color: color),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Image.asset(
                        (axis == direction)
                            ? mainAxisAssetImageUrl(direction, alignment)
                            : crossAxisAssetImageUrl(direction, alignment),
                        height: axisAlignmentAssetImageHeight,
                        fit: BoxFit.fitHeight,
                        color: color,
                      ),
                    ),
                  ],
                )
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
                          describeEnum(alignment),
                          style: TextStyle(color: color),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Flexible(
                        child: Image.asset(
                          (axis == direction)
                              ? mainAxisAssetImageUrl(direction, alignment)
                              : crossAxisAssetImageUrl(direction, alignment),
                          fit: BoxFit.fitHeight,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              )
          ],
          onChanged: (Object newSelection) async {
            // newSelection is an object instead of type here because
            // the type is dependent on the `axis` parameter
            // if the axis is the main axis the type should be [MainAxisAlignment]
            // if the axis is the cross axis the type should be [CrossAxisAlignment]
            FlexLayoutProperties changedProperties;
            if (axis == direction) {
              changedProperties =
                  properties.copyWith(mainAxisAlignment: newSelection);
            } else {
              changedProperties =
                  properties.copyWith(crossAxisAlignment: newSelection);
            }
            final service = await properties.node.inspectorService;
            final valueRef = properties.node.valueRef;
            markAsDirty();
            await service.invokeSetFlexProperties(
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
    if (_properties == null) return const SizedBox();
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
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = constraints.maxHeight;
    final maxWidth = constraints.maxWidth;
    final flexDescription = Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          top: mainAxisArrowIndicatorSize,
          left: crossAxisArrowIndicatorSize + margin,
        ),
        child: InkWell(
          onTap: () => onTap(properties),
          child: WidgetVisualizer(
            title: flexType,
            layoutProperties: properties,
            isSelected: highlighted == properties,
            overflowSide: properties.overflowSide,
            hint: Container(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                'Total Flex Factor: ${properties?.totalFlex?.toInt()}',
                textScaleFactor: largeTextScaleFactor,
                style: const TextStyle(
                  color: emphasizedTextColor,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            child: _visualizeFlex(context),
          ),
        ),
      ),
    );

    final verticalAxisDescription = Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        margin: const EdgeInsets.only(top: mainAxisArrowIndicatorSize + margin),
        width: crossAxisArrowIndicatorSize,
        child: Column(
          children: [
            Expanded(
              child: ArrowWrapper.unidirectional(
                arrowColor: verticalColor(colorScheme),
                child: Truncateable(
                  truncate: maxHeight <= minHeightToAllowTruncating,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      properties.verticalDirectionDescription,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      textScaleFactor: largeTextScaleFactor,
                      style: TextStyle(
                        color: verticalTextColor(colorScheme),
                      ),
                    ),
                  ),
                ),
                type: ArrowType.down,
              ),
            ),
            Truncateable(
              truncate: maxHeight <= minHeightToAllowTruncating,
              child: _buildAxisAlignmentDropdown(Axis.vertical, colorScheme),
            ),
          ],
        ),
      ),
    );

    final horizontalAxisDescription = Align(
      alignment: Alignment.topRight,
      child: Container(
        margin:
            const EdgeInsets.only(left: crossAxisArrowIndicatorSize + margin),
        height: mainAxisArrowIndicatorSize,
        child: Row(
          children: [
            Expanded(
              child: ArrowWrapper.unidirectional(
                arrowColor: horizontalColor(colorScheme),
                child: Truncateable(
                  truncate: maxWidth <= minWidthToAllowTruncating,
                  child: Text(
                    properties.horizontalDirectionDescription,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    textScaleFactor: largeTextScaleFactor,
                    style: TextStyle(color: horizontalTextColor(colorScheme)),
                  ),
                ),
                type: ArrowType.right,
              ),
            ),
            Truncateable(
              truncate: maxWidth <= minWidthToAllowTruncating,
              child: _buildAxisAlignmentDropdown(Axis.horizontal, colorScheme),
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

  bool _dirty = false;

  @override
  void onFlutterFrame() {
    if (!mounted) return;
    if (_dirty) {
      rateLimiter.scheduleRequest();
    }
  }

  // TODO(albertusangga): Investigate why onForceRefresh is not getting called.
  @override
  Future<Object> onForceRefresh() async {
    _setProperties(await fetchFlexLayoutProperties());
    return null;
  }

  /// Currently this is not working so we should listen to controller selection event instead.
  @override
  Future<void> onInspectorSelectionChanged() {
    return null;
  }

  /// Register callback to be executed once Flutter frame is ready.
  void markAsDirty() {
    _dirty = true;
  }
}

/// Widget that represents and visualize a direct child of Flex widget.
class FlexChildVisualizer extends StatelessWidget {
  const FlexChildVisualizer({
    Key key,
    @required this.state,
    @required this.layoutProperties,
    @required this.renderProperties,
    @required this.isSelected,
  }) : super(key: key);

  final _FlexLayoutExplorerWidgetState state;

  final bool isSelected;

  final LayoutProperties layoutProperties;

  final RenderProperties renderProperties;

  FlexLayoutProperties get root => state.properties;

  LayoutProperties get properties => renderProperties.layoutProperties;

  void onChangeFlexFactor(int newFlexFactor) async {
    final node = properties.node;
    final inspectorService = await node.inspectorService;
    state.markAsDirty();
    await inspectorService.invokeSetFlexFactor(
      node.valueRef,
      newFlexFactor,
    );
  }

  void onChangeFlexFit(FlexFit newFlexFit) async {
    final node = properties.node;
    final inspectorService = await node.inspectorService;
    state.markAsDirty();
    await inspectorService.invokeSetFlexFit(
      node.valueRef,
      newFlexFit,
    );
  }

  Widget _buildFlexFactorChangerDropdown(int maximumFlexFactor) {
    Widget buildMenuitemChild(int flexFactor) {
      return Text(
        'flex: $flexFactor',
        style: flexFactor == properties.flexFactor
            ? const TextStyle(
                fontWeight: FontWeight.bold,
                color: emphasizedTextColor,
              )
            : const TextStyle(color: emphasizedTextColor),
      );
    }

    DropdownMenuItem<int> buildMenuItem(int flexFactor) {
      return DropdownMenuItem(
        value: flexFactor,
        child: buildMenuitemChild(flexFactor),
      );
    }

    return DropdownButton<int>(
      value: properties.flexFactor?.toInt()?.clamp(0, maximumFlexFactor),
      onChanged: onChangeFlexFactor,
      iconEnabledColor: textColor,
      underline: buildUnderline(),
      items: <DropdownMenuItem<int>>[
        buildMenuItem(null),
        for (var i = 0; i <= maximumFlexFactor; ++i) buildMenuItem(i),
      ],
    );
  }

  Widget _buildFlexFitChangerDropdown() {
    Widget flexFitDescription(FlexFit flexFit) => Text(
          'fit: ${describeEnum(flexFit)}',
          style: const TextStyle(color: emphasizedTextColor),
        );

    // Disable FlexFit changer if widget is Expanded.
    if (properties.description == 'Expanded') {
      return flexFitDescription(FlexFit.tight);
    }

    DropdownMenuItem<FlexFit> buildMenuItem(FlexFit flexFit) {
      return DropdownMenuItem(
        value: flexFit,
        child: flexFitDescription(flexFit),
      );
    }

    return DropdownButton<FlexFit>(
      value: properties.flexFit,
      onChanged: onChangeFlexFit,
      underline: buildUnderline(),
      iconEnabledColor: emphasizedTextColor,
      items: <DropdownMenuItem<FlexFit>>[
        buildMenuItem(FlexFit.loose),
        if (properties.description != 'Expanded') buildMenuItem(FlexFit.tight)
      ],
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(
        top: margin,
        left: margin,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: _buildFlexFactorChangerDropdown(maximumFlexFactorOptions),
          ),
          if (!properties.hasFlexFactor)
            Text(
              'unconstrained ${root.isMainAxisHorizontal ? 'horizontal' : 'vertical'}',
              style: TextStyle(
                color: colorScheme.unconstrainedColor,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              textScaleFactor: smallTextScaleFactor,
              textAlign: TextAlign.center,
            ),
          _buildFlexFitChangerDropdown(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renderSize = renderProperties.size;
    final renderOffset = renderProperties.offset;

    Widget buildEntranceAnimation(BuildContext context, Widget child) {
      final vertical = root.isMainAxisVertical;
      final horizontal = root.isMainAxisHorizontal;
      Size size = renderSize;
      if (properties.hasFlexFactor) {
        size = SizeTween(
          begin: Size(
            horizontal ? minRenderWidth - entranceMargin : renderSize.width,
            vertical ? minRenderHeight - entranceMargin : renderSize.height,
          ),
          end: renderSize,
        ).evaluate(state.entranceCurve);
      }
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

    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      top: renderOffset.dy,
      left: renderOffset.dx,
      child: InkWell(
        onTap: () => state.onTap(properties),
        onDoubleTap: () => state.onDoubleTap(properties),
        onLongPress: () => state.onDoubleTap(properties),
        child: SizedBox(
          width: renderSize.width,
          height: renderSize.height,
          child: AnimatedBuilder(
            animation: state.entranceController,
            builder: buildEntranceAnimation,
            child: WidgetVisualizer(
              isSelected: isSelected,
              layoutProperties: layoutProperties,
              title: properties.description,
              overflowSide: properties.overflowSide,
              child: _visualizeWidthAndHeightWithConstraints(
                context,
                arrowHeadSize: arrowHeadSize,
                widget: Align(
                  alignment: Alignment.topRight,
                  child: _buildContent(colorScheme),
                ),
                properties: properties,
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

/// Widget that draws bounding box with the title (usually widget name) in its top left
///
/// [hint] is an optional widget to be placed in the top right of the box
/// [child] is an optional widget to be placed in the center of the box
/// [borderColor] outer box border color and background color for the title
/// [textColor] color for title text
class WidgetVisualizer extends StatelessWidget {
  const WidgetVisualizer({
    Key key,
    @required this.title,
    this.hint,
    @required this.isSelected,
    @required this.layoutProperties,
    this.child,
    this.overflowSide,
  })  : assert(title != null),
        super(key: key);

  final LayoutProperties layoutProperties;
  final String title;
  final Widget child;
  final Widget hint;
  final bool isSelected;

  final OverflowSide overflowSide;

  static const overflowIndicatorSize = 20.0;

  bool get drawOverflow => overflowSide != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final properties = layoutProperties;
    Color borderColor = regularWidgetColor;
    if (properties is FlexLayoutProperties) {
      borderColor =
          properties.direction == Axis.horizontal ? rowColor : columnColor;
    }
    if (isSelected) {
      borderColor = selectedWidgetColor;
    }
    return Container(
      child: Stack(
        children: [
          if (drawOverflow)
            Positioned.fill(
              child: CustomPaint(
                painter: OverflowIndicatorPainter(
                  overflowSide,
                  overflowIndicatorSize,
                ),
              ),
            ),
          Container(
            margin: EdgeInsets.only(
              right: overflowSide == OverflowSide.right
                  ? overflowIndicatorSize
                  : 0.0,
              bottom: overflowSide == OverflowSide.bottom
                  ? overflowIndicatorSize
                  : 0.0,
            ),
            color: isSelected ? colorScheme.backgroundColorSelected : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(
                              maxWidth: minRenderWidth *
                                  widgetTitleMaxWidthPercentage),
                          child: Center(
                            child: Text(
                              title,
                              style:
                                  TextStyle(color: colorScheme.widgetNameColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          decoration: BoxDecoration(color: borderColor),
                          padding: const EdgeInsets.all(4.0),
                        ),
                      ),
                      if (hint != null) Flexible(child: hint),
                    ],
                  ),
                ),
                if (child != null) Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
        ),
        color: theme.canvasColor.darken(),
      ),
    );
  }
}
