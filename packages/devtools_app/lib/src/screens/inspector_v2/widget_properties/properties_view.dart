// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/diagnostics/diagnostics_node.dart';
import '../../../shared/ui/tab.dart';
import '../inspector_controller.dart';

/// Displays the widget's properties along with the properties on its render
/// object.
class PropertiesView extends StatefulWidget {
  const PropertiesView({
    super.key,
    required this.controller,
    required this.node,
  });

  static const _gaPrefix = 'inspectorNodeProperties';

  final InspectorController controller;
  final RemoteDiagnosticsNode node;

  @override
  State<PropertiesView> createState() => _PropertiesViewState();
}

class _PropertiesViewState extends State<PropertiesView> {
  late ScrollController _widgetPropertiesScrollController;
  late ScrollController _renderPropertiesScrollController;

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
        return AnalyticsTabbedView(
          gaScreen: gac.inspector,
          tabs: [
            (
              tab: DevToolsTab.create(
                tabName: 'Widget properties',
                gaPrefix: PropertiesView._gaPrefix,
              ),
              tabView: PropertiesTable(
                properties: widgetProperties,
                scrollController: _widgetPropertiesScrollController,
              ),
            ),
            if (renderProperties.isNotEmpty)
              (
                tab: DevToolsTab.create(
                  tabName: 'Render object',
                  gaPrefix: PropertiesView._gaPrefix,
                ),
                tabView: PropertiesTable(
                  properties: renderProperties,
                  scrollController: _renderPropertiesScrollController,
                ),
              ),
          ],
        );
      },
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
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: defaultBorderSide(theme)),
        color: alternatingColorForIndex(index, theme.colorScheme),
      ),
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
        style: Theme.of(context).regularTextStyle,
      ),
    );
  }
}
