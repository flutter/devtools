// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/common_widgets.dart';
import '../../../shared/diagnostics/diagnostics_node.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/ui/tab.dart';
import '../inspector_controller.dart';

class PropertiesView extends StatelessWidget {
  const PropertiesView({
    super.key,
    required this.controller,
    required this.node,
  });

  final InspectorController controller;
  final RemoteDiagnosticsNode node;

  @override
  Widget build(BuildContext context) {
    return MultiValueListenableBuilder(
      listenables: [
        controller.selectedNodeWidgetProperties,
        controller.selectedNodeRenderProperties,
      ],
      builder: (context, values, _) {
        final widgetProperties = values.first as List<RemoteDiagnosticsNode>;
        final renderProperties = values.second as List<RemoteDiagnosticsNode>;
        return Padding(
          padding: const EdgeInsets.all(denseSpacing),
          child: AnalyticsTabbedView(
            gaScreen: gac.inspector,
            tabs: [
              (
                tab: DevToolsTab.create(
                  tabName: 'Widget properties',
                  gaPrefix: 'widgetPropertiesTab',
                ),
                tabView: PropertiesTable(properties: widgetProperties),
              ),
              if (renderProperties.isNotEmpty)
                (
                  tab: DevToolsTab.create(
                    tabName: 'Render object',
                    gaPrefix: 'renderObjectTab',
                  ),
                  tabView: PropertiesTable(properties: renderProperties),
                ),
            ],
          ),
        );
      },
    );
  }
}

class PropertiesTable extends StatelessWidget {
  const PropertiesTable({
    super.key,
    required this.properties,
  });

  final List<RemoteDiagnosticsNode> properties;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        primary: true,
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
        border: Border(bottom: BorderSide(color: theme.focusColor)),
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
