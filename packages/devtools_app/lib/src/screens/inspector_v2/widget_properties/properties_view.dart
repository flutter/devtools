// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../shared/diagnostics/diagnostics_node.dart';
import '../../../shared/diagnostics_text_styles.dart';
import '../inspector_controller.dart';

final _log = Logger('properties_view');

class PropertiesView extends StatelessWidget {
  const PropertiesView({
    super.key,
    required this.controller,
    required this.node,
  });

  final InspectorController controller;
  final RemoteDiagnosticsNode node;

  Future<List<RemoteDiagnosticsNode>> loadProperties() async {
    final properties = <RemoteDiagnosticsNode>[];
    final objectGroupApi = node.objectGroupApi;
    if (objectGroupApi == null) return Future.value(properties);
    try {
      // Fetch widget properties:
      final widgetProperties = await node.getProperties(objectGroupApi);
      properties.addAll(widgetProperties);
      // Fetch RenderObject properties:
      for (final widgetProperty in widgetProperties) {
        if (widgetProperty.propertyType == 'RenderObject') {
          final renderProperties =
              await widgetProperty.getProperties(objectGroupApi);
          // Only display RenderObject properties that are not already set on
          // the widget:
          for (final renderProperty in renderProperties) {
            final propertyOnWidget = widgetProperties
                    .firstWhereOrNull((p) => p.name == renderProperty.name) !=
                null;
            if (!propertyOnWidget) {
              properties.add(renderProperty);
            }
          }
        }
      }
      return Future.value(properties);
    } catch (e, st) {
      _log.warning(e, st);
      return Future.value(properties);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RemoteDiagnosticsNode>>(
      // ignore: discarded_futures, FutureBuilder requires a future.
      future: loadProperties(),
      builder: (context, snapshot) {
        final properties = snapshot.data ?? <RemoteDiagnosticsNode>[];
        return Container(
          margin: const EdgeInsets.all(denseSpacing),
          child: Scrollbar(
            child: SingleChildScrollView(
              primary: true,
              child: Table(
                border: TableBorder.all(
                  color: Theme.of(context).focusColor,
                  borderRadius: defaultBorderRadius,
                ),
                children: [
                  for (int i = 0; i < properties.length; i++)
                    TableRow(
                      decoration: BoxDecoration(
                        borderRadius: _calculateBorderRadiusForRow(
                          rowIndex: i,
                          totalRows: properties.length,
                        ),
                        color: alternatingColorForIndex(
                          i,
                          Theme.of(context).colorScheme,
                        ),
                      ),
                      children: [
                        TableCell(
                          child: PropertyName(property: properties[i]),
                        ),
                        TableCell(
                          child: PropertyValue(
                            property: properties[i],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  BorderRadius _calculateBorderRadiusForRow({
    required int rowIndex,
    required int totalRows,
  }) {
    // Rounded top corners for the first row:
    if (rowIndex == 0) {
      return const BorderRadius.only(
        topLeft: defaultRadius,
        topRight: defaultRadius,
      );
    }
    // Rounded bottom corners for the last row:
    if (rowIndex == (totalRows - 1)) {
      return const BorderRadius.only(
        bottomLeft: defaultRadius,
        bottomRight: defaultRadius,
      );
    }
    return BorderRadius.zero;
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
        style: DiagnosticsTextStyles.regular(
          theme.colorScheme,
        ).merge(theme.subtleTextStyle),
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
        style: DiagnosticsTextStyles.regular(Theme.of(context).colorScheme),
      ),
    );
  }
}
