// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/console/widgets/description.dart';
import '../../../shared/diagnostics/diagnostics_node.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/ui/tab.dart';
import '../inspector_controller.dart';
import '../inspector_data_models.dart';
import '../layout_explorer/box/box.dart';
import '../layout_explorer/flex/flex.dart';

/// Table for the widget's properties, along with its render object and a
/// flex layout explorer if the widget is part of a flex layout.
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

  final _widgetPropertiesTab = DevToolsTab.create(
    tabName: 'Widget properties',
    gaPrefix: DetailsTable.gaPrefix,
  );

  final _renderObjectTab = DevToolsTab.create(
    tabName: 'Render object',
    gaPrefix: DetailsTable.gaPrefix,
  );

  final _flexExplorerTab = DevToolsTab.create(
    tabName: 'Flex explorer',
    gaPrefix: DetailsTable.gaPrefix,
  );

  DevToolsTab? _lastSelectedTab;

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

        final renderTabExists = renderProperties.isNotEmpty;
        final flexExplorerTabExists = selectedNode?.isFlexLayout ?? false;

        return AnalyticsTabbedView(
          gaScreen: gac.inspector,
          onTabChanged: (int tabIndex) {
            _lastSelectedTab = _getTabForIndex(
              tabIndex,
              renderTabExists: renderTabExists,
              flexExplorerTabExists: flexExplorerTabExists,
            );
          },
          initialSelectedIndex: _getIndexForTab(
            _lastSelectedTab ?? _widgetPropertiesTab,
            renderTabExists: renderTabExists,
            flexExplorerTabExists: flexExplorerTabExists,
          ),
          tabs: [
            (
              tab: _widgetPropertiesTab,
              tabView: PropertiesView(
                properties: widgetProperties,
                layoutProperties: layoutProperties,
                controller: widget.controller,
                scrollController: _widgetPropertiesScrollController,
              ),
            ),
            if (renderTabExists)
              (
                tab: _renderObjectTab,
                tabView: PropertiesTable(
                  properties: renderProperties,
                  scrollController: _renderPropertiesScrollController,
                ),
              ),
            if (flexExplorerTabExists)
              (
                tab: _flexExplorerTab,
                tabView: FlexLayoutExplorerWidget(widget.controller),
              ),
          ],
        );
      },
    );
  }

  DevToolsTab _getTabForIndex(
    int index, {
    required bool renderTabExists,
    required bool flexExplorerTabExists,
  }) {
    final tabs = _getTabsInOrder(
      renderTabExists: renderTabExists,
      flexExplorerTabExists: flexExplorerTabExists,
    );

    return tabs.safeGet(index) ?? _widgetPropertiesTab;
  }

  int _getIndexForTab(
    DevToolsTab tab, {
    required bool renderTabExists,
    required bool flexExplorerTabExists,
  }) {
    final tabs = _getTabsInOrder(
      renderTabExists: renderTabExists,
      flexExplorerTabExists: flexExplorerTabExists,
    );

    // If tab is not found, return the first tab (at index 0):
    return max(tabs.indexOf(tab), 0);
  }

  List<DevToolsTab> _getTabsInOrder({
    required bool renderTabExists,
    required bool flexExplorerTabExists,
  }) => [
    _widgetPropertiesTab,
    if (renderTabExists) _renderObjectTab,
    if (flexExplorerTabExists) _flexExplorerTab,
  ];
}

/// Displays a widget's properties, including the layout properties and a
/// layout visualizer.
class PropertiesView extends StatefulWidget {
  const PropertiesView({
    super.key,
    required this.properties,
    required this.layoutProperties,
    required this.controller,
    required this.scrollController,
  });

  static const layoutExplorerHeight = 150.0;
  static const layoutExplorerWidth = 200.0;
  static const scaleFactorForVerticalLayout = 2.0;

  final List<RemoteDiagnosticsNode> properties;
  final LayoutProperties? layoutProperties;
  final InspectorController controller;
  final ScrollController scrollController;

  @override
  State<PropertiesView> createState() => _PropertiesViewState();
}

class _PropertiesViewState extends State<PropertiesView> {
  RemoteDiagnosticsNode? get selectedNode =>
      widget.controller.selectedNode.value?.diagnostic;

  bool get includeLayoutExplorer => widget.layoutProperties != null;

  WidgetSizes? get widgetWidths => widget.layoutProperties?.widgetWidths;

  WidgetSizes? get widgetHeights => widget.layoutProperties?.widgetHeights;

  List<RemoteDiagnosticsNode> _sortedProperties = <RemoteDiagnosticsNode>[];

  @override
  void initState() {
    super.initState();

    _sortedProperties = _filterAndSortPropertiesByLevel(widget.properties);
  }

  @override
  void didUpdateWidget(PropertiesView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.properties != oldWidget.properties) {
      _sortedProperties = _filterAndSortPropertiesByLevel(widget.properties);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layoutExplorerOffset = includeLayoutExplorer ? 1 : 0;
    // If there are no properties to display, include a single row that says as
    // much.
    final propertyRowsCount =
        _sortedProperties.isEmpty ? 1 : _sortedProperties.length;
    // If the layout explorer is available, it is the first row.
    final totalRowsCount = propertyRowsCount + layoutExplorerOffset;

    Widget? layoutPropertiesList;
    if (widgetWidths != null && widgetHeights != null) {
      layoutPropertiesList = LayoutPropertiesList(
        widgetHeights: widgetHeights,
        widgetWidths: widgetWidths,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalLayout =
            constraints.maxWidth >
            (PropertiesView.layoutExplorerWidth *
                PropertiesView.scaleFactorForVerticalLayout);

        return Scrollbar(
          controller: widget.scrollController,
          thumbVisibility: true,
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: totalRowsCount,
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
                            widget.controller,
                            selectedNode: selectedNode,
                            layoutProperties: widget.layoutProperties,
                          ),
                        ),
                      ),
                      if (layoutPropertiesList != null)
                        Padding(
                          padding:
                              horizontalLayout
                                  ? const EdgeInsets.only(left: largeSpacing)
                                  : const EdgeInsets.only(bottom: largeSpacing),
                          child: layoutPropertiesList,
                        ),
                    ],
                  ),
                );
              }

              if (_sortedProperties.isEmpty && index == layoutExplorerOffset) {
                return DecoratedPropertiesTableRow(
                  index: index - layoutExplorerOffset,
                  child: PaddedText(
                    child: Text(
                      'No widget properties to display.',
                      style: Theme.of(context).regularTextStyle,
                    ),
                  ),
                );
              }

              return PropertyItem(
                index: index - layoutExplorerOffset,
                properties: _sortedProperties,
              );
            },
          ),
        );
      },
    );
  }

  /// Filters out properties with [DiagnosticLevel.hidden] and sorts properties
  /// with [DiagnosticLevel.fine] behind all others.
  List<RemoteDiagnosticsNode> _filterAndSortPropertiesByLevel(
    List<RemoteDiagnosticsNode> properties,
  ) {
    final propertiesWithFineLevel = <RemoteDiagnosticsNode>[];
    final propertiesWithOtherLevels = <RemoteDiagnosticsNode>[];

    for (final property in properties) {
      // Don't include properties that should be hidden:
      if (property.level == DiagnosticLevel.hidden) continue;

      if (property.level == DiagnosticLevel.fine) {
        propertiesWithFineLevel.add(property);
      } else {
        propertiesWithOtherLevels.add(property);
      }
    }

    return [...propertiesWithOtherLevels, ...propertiesWithFineLevel];
  }
}

/// List of the widget's layout properties.
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutPropertyItem(name: 'height', value: widgetHeight),
        LayoutPropertyItem(name: 'width', value: widgetWidth),
        if (hasTopPadding)
          LayoutPropertyItem(name: 'top padding', value: topPadding),
        if (hasBottomPadding)
          LayoutPropertyItem(name: 'bottom padding', value: bottomPadding),
        if (hasLeftPadding)
          LayoutPropertyItem(name: 'left padding', value: leftPadding),
        if (hasRightPadding)
          LayoutPropertyItem(name: 'right padding', value: rightPadding),
      ],
    );
  }
}

/// A layout property's name and value displayed in the [LayoutPropertiesList].
class LayoutPropertyItem extends StatelessWidget {
  const LayoutPropertyItem({
    super.key,
    required this.name,
    required this.value,
  });

  final String name;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PaddedText(
      child: RichText(
        text: TextSpan(
          text: '$name: ',
          style: theme.subtleTextStyle,
          children: [
            TextSpan(text: toStringAsFixed(value), style: theme.fixedFontStyle),
          ],
        ),
      ),
    );
  }
}

/// Table of widget's properties with property name and value.
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
          return PropertyItem(index: index, properties: properties);
        },
      ),
    );
  }
}

/// A row in the [PropertiesTable] with the correct decoration for the [index].
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

/// A widget property's name and value displayed in the [PropertiesTable].
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

/// A widget property's name.
class PropertyName extends StatelessWidget {
  const PropertyName({super.key, required this.property});

  final RemoteDiagnosticsNode property;

  @override
  Widget build(BuildContext context) {
    return PaddedText(
      child: Text(
        property.name ?? '',
        style: Theme.of(context).subtleTextStyle,
      ),
    );
  }
}

/// A widget property's value.
class PropertyValue extends StatelessWidget {
  const PropertyValue({super.key, required this.property});

  final RemoteDiagnosticsNode property;

  @override
  Widget build(BuildContext context) {
    return PaddedText(
      child: DiagnosticsNodeDescription(
        property,
        includeName: false,
        overflow: TextOverflow.visible,
        style: Theme.of(context).fixedFontStyle,
      ),
    );
  }
}

/// Wraps a text widget with the correct amount of padding for the table.
class PaddedText extends StatelessWidget {
  const PaddedText({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(denseRowSpacing),
      child: child,
    );
  }
}
