// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/diagnostics/diagnostics_node.dart';
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
    return ValueListenableBuilder<List<RemoteDiagnosticsNode>>(
      valueListenable: controller.selectedNodeProperties,
      builder: (context, properties, _) {
        return Container(
          margin: const EdgeInsets.all(denseSpacing),
          child: ListView.builder(
            itemCount: properties.length,
            itemBuilder: (context, index) {
              return PropertyItem(
                index: index,
                properties: properties,
              );
            },
          ),
        );
      },
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
        border: _calculateBorderForRow(
          rowIndex: index,
          theme: theme,
        ),
        color: alternatingColorForIndex(
          index,
          Theme.of(context).colorScheme,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: PropertyName(property: property)),
          Expanded(flex: 2, child: PropertyValue(property: property)),
        ],
      ),
    );
  }

  Border _calculateBorderForRow({
    required int rowIndex,
    required ThemeData theme,
  }) {
    final borderColor = theme.focusColor;
    return Border(
      // This prevents the top and bottom borders from being painted next to
      // to each other, making the border look thicker than it should be:
      top: rowIndex == 0
          ? BorderSide(
              color: borderColor,
            )
          : BorderSide.none,
      bottom: BorderSide(color: borderColor),
      right: BorderSide(color: borderColor),
      left: BorderSide(color: borderColor),
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(denseRowSpacing),
      child: Text(
        property.name ?? '',
        style: theme.subtleTextStyle,
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
