// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/diagnostics/diagnostics_node.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/ui/tab.dart';
import '../inspector_controller.dart';
import '../inspector_data_models.dart';
import '../layout_explorer/box/box.dart';
import '../layout_explorer/flex/flex.dart';

/// Displays the widget's properties along with the properties on its render
/// object.
class DetailsTable extends StatefulWidget {
  const DetailsTable({
    super.key,
    required this.controller,
    required this.node,
    this.extraTabs,
  });

  static const gaPrefix = 'inspectorDetailsTable';

  final InspectorController controller;
  final RemoteDiagnosticsNode node;
  final List<TabAndView>? extraTabs;

  @override
  State<DetailsTable> createState() => _DetailsTableState();
}

class _DetailsTableState extends State<DetailsTable> {
  late ScrollController _widgetPropertiesScrollController;
  late ScrollController _renderPropertiesScrollController;

  RemoteDiagnosticsNode? get selectedNode =>
      widget.controller.selectedDiagnostic;

  LayoutProperties? get layoutProperties =>
      widget.controller.selectedNodeProperties.value.layoutProperties;

  @override
  void initState() {
    super.initState();
    _widgetPropertiesScrollController = ScrollController();
    _renderPropertiesScrollController = ScrollController();
  }

  @override
  void dispose() {
    super.dispose();
    _widgetPropertiesScrollController.dispose();
    _renderPropertiesScrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WidgetTreeNodeProperties>(
      valueListenable: widget.controller.selectedNodeProperties,
      builder: (context, properties, _) {
        final widgetProperties = properties.widgetProperties;
        final renderProperties = properties.renderProperties;
        final layoutProperties = properties.layoutProperties;
        return AnalyticsTabbedView(
          gaScreen: gac.inspector,
          tabs: [
            (
              tab: DevToolsTab.create(
                tabName: 'Widget properties',
                gaPrefix: DetailsTable.gaPrefix,
              ),
              tabView: PropertiesView(
                properties: widgetProperties,
                layoutProperties: layoutProperties,
                controller: widget.controller,
                scrollController: _widgetPropertiesScrollController,
              ),
            ),
            if (renderProperties.isNotEmpty)
              (
                tab: DevToolsTab.create(
                  tabName: 'Render object',
                  gaPrefix: DetailsTable.gaPrefix,
                ),
                tabView: PropertiesTable(
                  properties: renderProperties,
                  scrollController: _renderPropertiesScrollController,
                ),
              ),
            if (selectedNode?.isFlexLayout ?? false)
              (
                tab: DevToolsTab.create(
                  tabName: 'Flex explorer',
                  gaPrefix: DetailsTable.gaPrefix,
                ),
                tabView: FlexLayoutExplorerWidget(widget.controller),
              ),
          ],
        );
      },
    );
  }
}

class PropertiesView extends StatelessWidget {
  const PropertiesView({
    super.key,
    required this.properties,
    required this.layoutProperties,
    required this.controller,
    required this.scrollController,
  });

  static const layoutExplorerHeight = 150.0;
  static const layoutExplorerWidth = 200.0;
  static const scaleFactorForVerticalLayout = 1.75;

  final List<RemoteDiagnosticsNode> properties;
  final LayoutProperties? layoutProperties;
  final InspectorController controller;
  final ScrollController scrollController;

  RemoteDiagnosticsNode? get selectedNode =>
      controller.selectedNode.value?.diagnostic;

  bool get includeLayoutExplorer => selectedNode?.isBoxLayout ?? false;

  WidgetSizes? get widgetWidths => layoutProperties?.widgetWidths;

  WidgetSizes? get widgetHeights => layoutProperties?.widgetHeights;

  @override
  Widget build(BuildContext context) {
    final layoutExplorerOffset = includeLayoutExplorer ? 1 : 0;

    Widget? propertiesList;
    if (widgetWidths != null && widgetHeights != null) {
      propertiesList = Center(
        child: LayoutPropertiesList(
          widgetHeights: widgetHeights,
          widgetWidths: widgetWidths,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalLayout = constraints.maxWidth >
            (PropertiesView.layoutExplorerWidth *
                PropertiesView.scaleFactorForVerticalLayout);

        return Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: ListView.builder(
            controller: scrollController,
            itemCount: properties.length + layoutExplorerOffset,
            itemBuilder: (context, index) {
              if (index == 0 && includeLayoutExplorer) {
                return DecoratedPropertiesTableRow(
                  index: index + layoutExplorerOffset,
                  child: Flex(
                    direction:
                        horizontalLayout ? Axis.horizontal : Axis.vertical,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(largeSpacing),
                        child: SizedBox(
                          height: PropertiesView.layoutExplorerHeight,
                          width: PropertiesView.layoutExplorerWidth,
                          child: BoxLayoutExplorerWidget(
                            controller,
                            selectedNode: selectedNode,
                            layoutProperties: layoutProperties,
                          ),
                        ),
                      ),
                      if (propertiesList != null)
                        horizontalLayout
                            ? Expanded(child: propertiesList)
                            : Padding(
                                padding:
                                    const EdgeInsets.only(bottom: largeSpacing),
                                child: propertiesList,
                              ),
                    ],
                  ),
                );
              }

              return PropertyItem(
                index: index - layoutExplorerOffset,
                properties: properties,
              );
            },
          ),
        );
      },
    );
  }
}

class LayoutPropertiesList extends StatelessWidget {
  const LayoutPropertiesList({
    super.key,
    required this.widgetHeights,
    required this.widgetWidths,
  });

  final WidgetSizes? widgetHeights;
  final WidgetSizes? widgetWidths;

  LayoutWidthsAndHeights? get widthsAndHeights =>
      widgetHeights != null && widgetWidths != null
          ? LayoutWidthsAndHeights(
              widths: widgetWidths!,
              heights: widgetHeights!,
            )
          : null;

  @override
  Widget build(BuildContext context) {
    if (widthsAndHeights == null) return const SizedBox.shrink();

    final LayoutWidthsAndHeights(
      :widgetHeight,
      :widgetWidth,
      :topPadding,
      :bottomPadding,
      :leftPadding,
      :rightPadding,
      :hasTopPadding,
      :hasBottomPadding,
      :hasLeftPadding,
      :hasRightPadding,
    ) = widthsAndHeights!;

    return Column(
      children: [
        PropertyText(
          name: 'height',
          value: widgetHeight,
        ),
        PropertyText(
          name: 'width',
          value: widgetWidth,
        ),
        if (hasTopPadding)
          PropertyText(
            name: 'top padding',
            value: topPadding,
          ),
        if (hasBottomPadding)
          PropertyText(
            name: 'bottom padding',
            value: bottomPadding,
          ),
        if (hasLeftPadding)
          PropertyText(
            name: 'left padding',
            value: leftPadding,
          ),
        if (hasRightPadding)
          PropertyText(
            name: 'right padding',
            value: rightPadding,
          ),
      ],
    );
  }
}

class PropertiesTable extends StatelessWidget {
  const PropertiesTable({
    super.key,
    required this.properties,
    required this.scrollController,
  });

  final List<RemoteDiagnosticsNode> properties;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: scrollController,
        itemCount: properties.length,
        itemBuilder: (context, index) {
          return PropertyItem(
            index: index,
            properties: properties,
          );
        },
      ),
    );
  }
}

class DecoratedPropertiesTableRow extends StatelessWidget {
  const DecoratedPropertiesTableRow({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: defaultBorderSide(theme)),
        color: alternatingColorForIndex(index, theme.colorScheme),
      ),
      child: child,
    );
  }
}

class PropertyItem extends StatelessWidget {
  const PropertyItem({
    super.key,
    required this.properties,
    required this.index,
  });

  final List<RemoteDiagnosticsNode> properties;
  final int index;

  @override
  Widget build(BuildContext context) {
    final property = properties[index];

    return DecoratedPropertiesTableRow(
      index: index,
      child: Row(
        children: [
          Expanded(child: PropertyName(property: property)),
          Expanded(flex: 2, child: PropertyValue(property: property)),
        ],
      ),
    );
  }
}

class PropertyName extends StatelessWidget {
  const PropertyName({
    super.key,
    required this.property,
  });

  final RemoteDiagnosticsNode property;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(denseRowSpacing),
      child: Text(
        property.name ?? '',
        style: Theme.of(context).subtleTextStyle,
      ),
    );
  }
}

class PropertyValue extends StatelessWidget {
  const PropertyValue({
    super.key,
    required this.property,
  });

  final RemoteDiagnosticsNode property;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(denseRowSpacing),
      child: Text(
        property.description ?? 'null',
        style: Theme.of(context).fixedFontStyle,
      ),
    );
  }
}

class PropertyText extends StatelessWidget {
  const PropertyText({
    super.key,
    required this.name,
    required this.value,
  });

  final String name;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(densePadding),
      child: RichText(
        text: TextSpan(
          text: '$name: ',
          style: Theme.of(context).subtleTextStyle,
          children: [
            TextSpan(
              text: toStringAsFixed(value),
              style: Theme.of(context).fixedFontStyle,
            ),
          ],
        ),
      ),
    );
  }
}
