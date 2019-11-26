// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../ui/colors.dart';
import '../../../ui/theme.dart';
import '../../../utils.dart';
import '../../diagnostics_node.dart';
import '../../inspector_controller.dart';
import '../../inspector_service.dart';
import '../inspector_data_models.dart';
import '../inspector_service_flutter_extension.dart';
import 'arrow.dart';
import 'utils.dart';

const widthIndicatorColor = mainUiColor;
const heightIndicatorColor = mainGpuColor;
const margin = 8.0;

const arrowHeadSize = 8.0;
const distanceToArrow = 1.0;
const arrowStrokeWidth = 1.5;

/// Hardcoded sizes for scaling the flex children widget properly.
const minRenderWidth = 250.0;
const minRenderHeight = 300.0;

/// The size to shrink a widget by when animating it in.
const entranceMargin = 50.0;

const defaultMaxRenderWidth = 400.0;
const defaultMaxRenderHeight = 400.0;

const widgetTitleMaxWidthPercentage = 0.75;

/// Hardcoded arrow size respective to its cross axis (because it's unconstrained).
const heightAndConstraintIndicatorSize = 48.0;
const widthAndConstraintIndicatorSize = 42.0;
const mainAxisArrowIndicatorSize = 48.0;
const crossAxisArrowIndicatorSize = 48.0;

const heightOnlyIndicatorSize = 24.0;
const widthOnlyIndicatorSize = 24.0;

const largeTextScaleFactor = 1.2;
const smallTextScaleFactor = 0.8;

/// height for limiting asset image (selected one in the drop down).
const axisAlignmentAssetImageHeight = 24.0;

/// width for limiting asset image (when drop down menu is open for the vertical).
const axisAlignmentAssetImageWidth = 96.0;
const dropdownMaxSize = 300.0;

Color activeBackgroundColor(ThemeData theme) => theme.backgroundColor;

Color inActiveBackgroundColor(ThemeData theme) => theme.cardColor;

// Story of Layout colors
const mainAxisLightColor = Color(0xFFF597A8);
const mainAxisDarkColor = Color(0xFFEA637C);
const mainAxisColor = ThemedColor(mainAxisLightColor, mainAxisDarkColor);

const crossAxisLightColor = Color(0xFFB3D25A);
const crossAxisDarkColor = Color(0xFFB3D25A);
const crossAxisColor = ThemedColor(crossAxisLightColor, crossAxisDarkColor);

const mainAxisLightTextColor = Color(0xFF913549);
const mainAxisDarkTextColor = Color(0xFFEA637C);
const mainAxisTextColor =
    ThemedColor(mainAxisLightTextColor, mainAxisDarkTextColor);

const crossAxisLightTextColor = Color(0xFF66672C);
const crossAxisDarkTextColor = Color(0xFFB3D25A);
const crossAxisTextColor =
    ThemedColor(crossAxisLightTextColor, crossAxisDarkTextColor);

const freeSpaceAssetName = 'assets/img/story_of_layout/empty_space.png';

const entranceAnimationDuration = Duration(milliseconds: 500);

Widget _visualizeWidthAndHeightWithConstraints({
  @required Widget widget,
  @required LayoutProperties properties,
  double arrowHeadSize = defaultArrowHeadSize,
}) {
  return BorderLayout(
    center: widget,
    right: Container(
      child: ArrowWrapper.bidirectional(
        arrowColor: heightIndicatorColor,
        arrowStrokeWidth: arrowStrokeWidth,
        arrowHeadSize: arrowHeadSize,
        child: RotatedBox(
          quarterTurns: 1,
          child: Text(
            '${properties.describeHeight()}\n'
            '(${properties.describeHeightConstraints()})',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.0),
          ),
        ),
        direction: Axis.vertical,
        distanceToArrow: distanceToArrow,
      ),
      margin: const EdgeInsets.only(
        top: margin,
        left: margin,
        bottom: widthAndConstraintIndicatorSize,
      ),
    ),
    rightWidth: heightAndConstraintIndicatorSize,
    bottom: Container(
      child: ArrowWrapper.bidirectional(
        arrowColor: widthIndicatorColor,
        arrowHeadSize: arrowHeadSize,
        arrowStrokeWidth: arrowStrokeWidth,
        child: Text(
          '${properties.describeWidth()}\n'
          '(${properties.describeWidthConstraints()})',
          textAlign: TextAlign.center,
          style: const TextStyle(
            height: 1.0,
          ),
        ),
        direction: Axis.horizontal,
        distanceToArrow: distanceToArrow,
      ),
      margin: const EdgeInsets.only(
        top: margin,
        right: heightAndConstraintIndicatorSize,
        // so that the arrow does not overlap with each other
        bottom: margin,
        left: margin,
      ),
    ),
    bottomHeight: widthAndConstraintIndicatorSize,
  );
}

class StoryOfYourFlexWidget extends StatefulWidget {
  const StoryOfYourFlexWidget(
    this.inspectorController, {
    Key key,
  }) : super(key: key);

  final InspectorController inspectorController;

  static bool shouldDisplay(RemoteDiagnosticsNode node) {
    return (node?.isFlex ?? false) || (node?.parent?.isFlex ?? false);
  }

  @override
  _StoryOfYourFlexWidgetState createState() => _StoryOfYourFlexWidgetState();
}

class _StoryOfYourFlexWidgetState extends State<StoryOfYourFlexWidget>
    with TickerProviderStateMixin {
  /// custom getters
  RemoteDiagnosticsNode get selectedNode =>
      inspectorController?.selectedNode?.diagnostic;

  Size get size => properties.size;

  List<LayoutProperties> get children => properties.children;

  Axis get direction => properties.direction;

  Color get horizontalColor =>
      properties.isMainAxisHorizontal ? mainAxisColor : crossAxisColor;

  Color get verticalColor =>
      properties.isMainAxisVertical ? mainAxisColor : crossAxisColor;

  Color get horizontalTextColor =>
      properties.isMainAxisHorizontal ? mainAxisTextColor : crossAxisTextColor;

  Color get verticalTextColor =>
      properties.isMainAxisVertical ? mainAxisTextColor : crossAxisTextColor;

  String get flexType => properties.type;

  InspectorController get inspectorController => widget.inspectorController;

  RemoteDiagnosticsNode getRoot(RemoteDiagnosticsNode node) {
    if (!StoryOfYourFlexWidget.shouldDisplay(node)) return null;
    if (node.isFlex) return node;
    return node.parent;
  }

  double crossAxisDimension(LayoutProperties properties) =>
      direction == Axis.horizontal ? properties.height : properties.width;

  double mainAxisDimension(LayoutProperties properties) =>
      direction == Axis.vertical ? properties.height : properties.width;

  /// state variables
  InspectorObjectGroupManager objectGroupManager;
  AnimationController entranceController;
  CurvedAnimation expandedEntrance;
  CurvedAnimation allEntrance;

  FlexLayoutProperties get properties => _previousProperties ?? _properties;
  FlexLayoutProperties _previousProperties;
  FlexLayoutProperties _properties;

  LayoutProperties highlighted;

  @override
  void initState() {
    super.initState();
    inspectorController.addSelectionListener(_onInspectorSelectionChanged);
    _initAnimationStates();
    _updateObjectGroupManager();
    _updateProperties();
  }

  @override
  void didUpdateWidget(StoryOfYourFlexWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateObjectGroupManager();
    _updateProperties();
  }

  @override
  void dispose() {
    print('disposed');
    entranceController.dispose();
    inspectorController.removeSelectionListener(_onInspectorSelectionChanged);
    super.dispose();
  }

  /// required for getting all information required for visualizing Flex layout
  Future<FlexLayoutProperties> fetchFlexLayoutProperties() async {
    objectGroupManager?.cancelNext();
    final nextObjectGroup = objectGroupManager.next;
    final node = await nextObjectGroup.getDetailsSubtreeWithRenderObject(
      getRoot(selectedNode),
      subtreeDepth: 1,
    );
    if (!nextObjectGroup.disposed) {
      assert(objectGroupManager.next == nextObjectGroup);
      objectGroupManager.promoteNext();
    }
    return FlexLayoutProperties.fromDiagnostics(node);
  }

  String id(RemoteDiagnosticsNode node) => node?.dartDiagnosticRef?.id;

  void _onInspectorSelectionChanged() async {
    if (!StoryOfYourFlexWidget.shouldDisplay(selectedNode)) {
      return;
    }
    final prevRootId = id(_properties?.node);
    final newRootId = id(getRoot(selectedNode));
    final shouldFetch = prevRootId != newRootId;
    FlexLayoutProperties newSelection = _properties;
    if (shouldFetch) {
      newSelection = await fetchFlexLayoutProperties();
    }
    setProperties(newSelection);
  }

  void updateHighlighted(FlexLayoutProperties newProperties) {
    if (selectedNode.isFlex) {
      highlighted = newProperties;
    } else {
      final idx = selectedNode.parent.childrenNow.indexOf(selectedNode);
      if (idx != -1) highlighted = newProperties.children[idx];
    }
  }

  void setProperties(FlexLayoutProperties newProperties) {
    updateHighlighted(newProperties);
    if (_properties == newProperties) {
      // update highlighted child
      setState(() {});
      return;
    }
    if (_properties == null) {
      _properties = newProperties;
      setState(() {});
    }
    _previousProperties = _properties;
    _properties = newProperties;
    _updateProperties();
  }

  void _initAnimationStates() {
    entranceController = AnimationController(
      vsync: this,
      duration: entranceAnimationDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          setState(() {
            _previousProperties = null;
            entranceController.forward();
          });
        }
      });
    expandedEntrance =
        CurvedAnimation(parent: entranceController, curve: Curves.easeIn);
    allEntrance =
        CurvedAnimation(parent: entranceController, curve: Curves.easeIn);
  }

  void _updateObjectGroupManager() {
    final service = inspectorController.inspectorService;
    if (service != objectGroupManager?.inspectorService) {
      objectGroupManager = InspectorObjectGroupManager(
        service,
        'flex-layout',
      );
    }
    _onInspectorSelectionChanged();
  }

  void _updateProperties() async {
    if (_previousProperties != null) {
      entranceController.reverse();
    } else {
      entranceController.forward();
    }
  }

  Future<void> _onTap(LayoutProperties properties) async {
    highlighted = properties;
    final node = properties.node;
    inspectorController.refreshSelection(node, node, false);
  }

  Future<void> refresh() async {
    setProperties(await fetchFlexLayoutProperties());
    setState(() {});
  }

  Widget _visualizeFlex(BuildContext context) {
    if (!properties.hasChildren)
      return const Center(child: Text('No Children'));

    final theme = Theme.of(context);
    return _visualizeWidthAndHeightWithConstraints(
      widget: Container(
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

          final childrenRenderWidgets = <Widget>[
            for (var i = 0; i < children.length; i++)
              FlexChildVisualizer(
                state: this,
                notifyParent: refresh,
                backgroundColor: highlighted == children[i]
                    ? activeBackgroundColor(theme)
                    : inActiveBackgroundColor(theme),
                borderColor: i.isOdd ? mainAxisColor : crossAxisColor,
                textColor: i.isOdd ? null : const Color(0xFF303030),
                renderProperties: renderProperties[i],
              )
          ];

          final freeSpacesWidgets = <Widget>[
            for (var renderProperties in [
              ...mainAxisSpaces,
              ...crossAxisSpaces
            ])
              EmptySpaceVisualizerWidget(renderProperties),
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
                    child: Image.asset(
                      freeSpaceAssetName,
                      width: maxWidth,
                      height: maxHeight,
                      fit: BoxFit.fill,
                    ),
                  ),
                  ...childrenRenderWidgets,
                  ...freeSpacesWidgets
                ],
              ),
            ),
          );
        }),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.primaryColorLight,
            width: 1.0,
          ),
        ),
      ),
      properties: properties,
    );
  }

  Widget _buildAxisAlignmentDropdown(Axis axis) {
    final color = axis == direction ? mainAxisTextColor : crossAxisTextColor;
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
            maxWidth: dropdownMaxSize, maxHeight: dropdownMaxSize),
        child: DropdownButton(
          value: selected,
          isExpanded: true,
          itemHeight: axis == Axis.vertical ? 100.0 : null,
          selectedItemBuilder: (context) {
            return [
              for (var alignment in alignmentEnumEntries)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        child: Text(
                          describeEnum(alignment),
                          style: TextStyle(color: color),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: axis == Axis.vertical ? 2 : 0,
                        child: Image.asset(
                          (axis == direction)
                              ? mainAxisAssetImageUrl(alignment)
                              : crossAxisAssetImageUrl(alignment),
                          height: axisAlignmentAssetImageHeight,
                          fit: BoxFit.contain,
                        ),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          child: Text(
                            describeEnum(alignment),
                            style: TextStyle(color: color),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: axis == Axis.vertical ? 1 : 0,
                          child: Image.asset(
                            (axis == direction)
                                ? mainAxisAssetImageUrl(alignment)
                                : crossAxisAssetImageUrl(alignment),
                            width: axisAlignmentAssetImageWidth,
                            fit: BoxFit.contain,
                          ),
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
            if (axis == direction) {
              properties.mainAxisAlignment = newSelection;
            } else {
              properties.crossAxisAlignment = newSelection;
            }
            final service = await properties.node.inspectorService;
            final arg = properties.node.valueRef;
            await service.invokeTweakFlexProperties(
              arg,
              properties.mainAxisAlignment,
              properties.crossAxisAlignment,
            );
            setProperties(await fetchFlexLayoutProperties());
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_properties == null) return const SizedBox();
    final theme = Theme.of(context);
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            child: Text(
              'Story of the flex layout of your $flexType widget',
              style: theme.textTheme.headline,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(margin),
              padding: const EdgeInsets.only(bottom: margin, right: margin),
              child: LayoutBuilder(builder: (context, constraints) {
                final maxHeight = constraints.maxHeight;
                final maxWidth = constraints.maxWidth;
                return Container(
                  constraints:
                      BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
                  child: Stack(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(
                            top: mainAxisArrowIndicatorSize,
                            left: crossAxisArrowIndicatorSize + margin,
                          ),
                          child: InkWell(
                            onTap: () => _onTap(properties),
                            child: WidgetVisualizer(
                              title: flexType,
                              backgroundColor: highlighted == properties
                                  ? activeBackgroundColor(theme)
                                  : null,
                              hint: Container(
                                padding: const EdgeInsets.all(4.0),
                                child: Text(
                                  'Total Flex Factor: ${properties?.totalFlex}',
                                  textScaleFactor: largeTextScaleFactor,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              borderColor: mainAxisColor,
                              child: Container(
                                margin: const EdgeInsets.only(
                                  /// margin for the outer width/height
                                  ///  so that they don't stick to the corner
                                  right: margin,
                                  bottom: margin,
                                ),
                                child: _visualizeFlex(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          height: maxHeight - mainAxisArrowIndicatorSize,
                          width: crossAxisArrowIndicatorSize,
                          child: Column(
                            children: <Widget>[
                              Expanded(
                                child: ArrowWrapper.unidirectional(
                                  arrowColor: verticalColor,
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Text(
                                      properties.verticalDirectionDescription,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      textScaleFactor: largeTextScaleFactor,
                                      style:
                                          TextStyle(color: verticalTextColor),
                                    ),
                                  ),
                                  type: ArrowType.down,
                                ),
                              ),
                              _buildAxisAlignmentDropdown(Axis.vertical),
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          height: mainAxisArrowIndicatorSize,
                          width:
                              maxWidth - crossAxisArrowIndicatorSize - margin,
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: ArrowWrapper.unidirectional(
                                  arrowColor: horizontalColor,
                                  child: FittedBox(
                                    child: Text(
                                      properties.horizontalDirectionDescription,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      textScaleFactor: largeTextScaleFactor,
                                      style:
                                          TextStyle(color: horizontalTextColor),
                                    ),
                                  ),
                                  type: ArrowType.right,
                                ),
                              ),
                              _buildAxisAlignmentDropdown(Axis.horizontal),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget that represents and visualize a direct child of Flex widget.
class FlexChildVisualizer extends StatelessWidget {
  const FlexChildVisualizer({
    Key key,
    @required this.state,
    @required this.renderProperties,
    @required this.backgroundColor,
    @required this.borderColor,
    @required this.textColor,
    @required this.notifyParent,
  }) : super(key: key);

  final _StoryOfYourFlexWidgetState state;

  /// callback to notify parent when child value changes
  final Function notifyParent;

  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  final RenderProperties renderProperties;

  FlexLayoutProperties get root => state.properties;

  LayoutProperties get properties => renderProperties.actualProperties;

  void onChangeFlexFactor(int newFlexFactor) async {
    final node = properties.node;
    final inspectorService = await node.inspectorService;
    await inspectorService.invokeTweakFlexFactor(
      node.valueRef,
      newFlexFactor,
    );
    properties.flexFactor = newFlexFactor;
    notifyParent();
  }

  Widget _buildFlexFactorChangerDropdown(int maximumFlexFactor) {
    Widget buildMenuitemChild(int flexFactor) {
      return Text(
        'flex: $flexFactor',
        style: flexFactor == properties.flexFactor
            ? TextStyle(
                fontWeight: FontWeight.bold,
              )
            : null,
      );
    }

    DropdownMenuItem<int> buildMenuItem(int flexFactor) {
      return DropdownMenuItem(
        value: flexFactor,
        child: buildMenuitemChild(flexFactor),
      );
    }

    return DropdownButton<int>(
      value: properties.flexFactor,
      items: <DropdownMenuItem<int>>[
        buildMenuItem(null),
        for (var i = 0; i <= maximumFlexFactor; ++i) buildMenuItem(i),
      ],
      onChanged: onChangeFlexFactor,
    );
  }

  Widget _buildContent() {
    return Container(
      margin: const EdgeInsets.only(
        top: margin,
        left: margin,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _buildFlexFactorChangerDropdown(maximumFlexFactor),
          if (!properties.hasFlexFactor)
            Text(
              'unconstrained ${root.isMainAxisHorizontal ? 'horizontal' : 'vertical'}',
              style: TextStyle(
                color: ThemedColor(
                  const Color(0xFFD08A29),
                  Colors.orange.shade700,
                ),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              textScaleFactor: smallTextScaleFactor,
              textAlign: TextAlign.right,
            ),
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
        ).evaluate(state.expandedEntrance);
      }
      return Opacity(
        opacity: min([state.allEntrance.value * 5, 1.0]),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: (renderSize.width - size.width) / 2,
            vertical: (renderSize.height - size.height) / 2,
          ),
          child: child,
        ),
      );
    }

    return Positioned(
      top: renderOffset.dy,
      left: renderOffset.dx,
      child: InkWell(
        onTap: () => state._onTap(properties),
        child: SizedBox(
          width: renderSize.width,
          height: renderSize.height,
          child: AnimatedBuilder(
            animation: state.entranceController,
            builder: buildEntranceAnimation,
            child: WidgetVisualizer(
              backgroundColor: backgroundColor,
              title: properties.description,
              borderColor: borderColor,
              textColor: textColor,
              child: _visualizeWidthAndHeightWithConstraints(
                arrowHeadSize: arrowHeadSize,
                widget: Align(
                  alignment: Alignment.topRight,
                  child: _buildContent(),
                ),
                properties: properties,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const maximumFlexFactor = 5;
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
    this.backgroundColor,
    @required this.borderColor,
    this.textColor,
    this.child,
  })  : assert(title != null),
        assert(borderColor != null),
        super(key: key);

  final String title;
  final Widget child;
  final Widget hint;

  final Color borderColor;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  constraints: const BoxConstraints(
                      maxWidth: minRenderWidth * widgetTitleMaxWidthPercentage),
                  child: Center(
                    child: Text(
                      title,
                      style: textColor != null
                          ? TextStyle(
                              color: textColor,
                            )
                          : null,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: borderColor,
                  ),
                  padding: const EdgeInsets.all(4.0),
                ),
                if (hint != null)
                  Flexible(
                    child: hint,
                  ),
              ],
            ),
          ),
          if (child != null)
            Expanded(
              child: child,
            ),
        ],
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
        ),
        color: backgroundColor,
      ),
    );
  }
}

class EmptySpaceVisualizerWidget extends StatelessWidget {
  const EmptySpaceVisualizerWidget(
    this.renderProperties, {
    Key key,
  }) : super(key: key);

  final RenderProperties renderProperties;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: renderProperties.offset.dy,
      left: renderProperties.offset.dx,
      child: Container(
        width: renderProperties.width,
        height: renderProperties.height,
        child: Stack(
          children: <Widget>[
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: widthOnlyIndicatorSize,
                margin: const EdgeInsets.only(
                  left: margin,
                  right: heightOnlyIndicatorSize,
                ),
                child: ArrowWrapper.bidirectional(
                  child: Text(
                    'w=${toStringAsFixed(renderProperties.realWidth)}',
                  ),
                  arrowColor: widthIndicatorColor,
                  direction: Axis.horizontal,
                  arrowHeadSize: arrowHeadSize,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: heightOnlyIndicatorSize,
                margin: const EdgeInsets.symmetric(vertical: margin),
                child: ArrowWrapper.bidirectional(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      'h=${toStringAsFixed(renderProperties.realHeight)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  arrowColor: heightIndicatorColor,
                  direction: Axis.vertical,
                  arrowHeadSize: arrowHeadSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
