// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui/icons.dart';
import '../utils.dart';
import 'diagnostics_node.dart';
import 'inspector_controller.dart';
import 'inspector_text_styles.dart' as inspector_text_styles;
import 'inspector_tree.dart';

final ColorIconMaker _colorIconMaker = ColorIconMaker();
final CustomIconMaker _customIconMaker = CustomIconMaker();
final CustomIcon defaultIcon = _customIconMaker.fromInfo('Default');

const bool _showRenderObjectPropertiesAsLinks = false;

/// Presents the content of a single [RemoteDiagnosticsNode].
///
/// Use this class any time you want to display a single [RemoteDiagnosticsNode]
/// in debugging UI whether you are displaying the node in the [InspectorTree]
/// in console output, or a debugger.
/// See also:
/// * [InspectorTree], which uses this class to display each node in the in
///   inspector tree.
class DiagnosticsNodeDescription extends StatelessWidget {
  const DiagnosticsNodeDescription(this.diagnostic);

  final RemoteDiagnosticsNode diagnostic;

  Widget _paddedIcon(Widget icon) {
    return Padding(
      padding: const EdgeInsets.only(right: iconPadding),
      child: icon,
    );
  }

  void _addDescription(
    List<Widget> output,
    String description,
    TextStyle textStyle,
    ColorScheme colorScheme, {
    bool isProperty,
  }) {
    if (diagnostic.isDiagnosticableValue) {
      final match = treeNodePrimaryDescriptionPattern.firstMatch(description);
      if (match != null) {
        output.add(Text(match.group(1), style: textStyle));
        if (match.group(2).isNotEmpty) {
          output.add(Text(
            match.group(2),
            style: inspector_text_styles.unimportant(colorScheme),
          ));
        }
        return;
      }
    } else if (diagnostic.type == 'ErrorDescription') {
      final match = assertionThrownBuildingError.firstMatch(description);
      if (match != null) {
        output.add(Text(match.group(1), style: textStyle));
        output.add(Text(match.group(3), style: textStyle));
        return;
      }
    }
    if (description?.isNotEmpty == true) {
      output.add(Text(description, style: textStyle));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (diagnostic == null) {
      return const SizedBox();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final icon = diagnostic.icon;
    final children = <Widget>[];

    if (icon != null) {
      children.add(_paddedIcon(icon));
    }
    final String name = diagnostic.name;
    TextStyle textStyle = textStyleForLevel(diagnostic.level, colorScheme);
    if (diagnostic.isProperty) {
      // Display of inline properties.
      final String propertyType = diagnostic.propertyType;
      final Map<String, Object> properties = diagnostic.valuePropertiesJson;

      if (name?.isNotEmpty == true && diagnostic.showName) {
        children.add(Text('$name${diagnostic.separator} ', style: textStyle));
      }

      if (diagnostic.isCreatedByLocalProject) {
        textStyle =
            textStyle.merge(inspector_text_styles.regularBold(colorScheme));
      }

      String description = diagnostic.description;
      if (propertyType != null && properties != null) {
        switch (propertyType) {
          case 'Color':
            {
              final int alpha = JsonUtils.getIntMember(properties, 'alpha');
              final int red = JsonUtils.getIntMember(properties, 'red');
              final int green = JsonUtils.getIntMember(properties, 'green');
              final int blue = JsonUtils.getIntMember(properties, 'blue');
              String radix(int chan) => chan.toRadixString(16).padLeft(2, '0');
              if (alpha == 255) {
                description = '#${radix(red)}${radix(green)}${radix(blue)}';
              } else {
                description =
                    '#${radix(alpha)}${radix(red)}${radix(green)}${radix(blue)}';
              }

              final Color color = Color.fromARGB(alpha, red, green, blue);
              children.add(_paddedIcon(_colorIconMaker.getCustomIcon(color)));
              break;
            }

          case 'IconData':
            {
              final int codePoint =
                  JsonUtils.getIntMember(properties, 'codePoint');
              if (codePoint > 0) {
                final icon = FlutterMaterialIcons.getIconForCodePoint(
                  codePoint,
                  colorScheme,
                );
                if (icon != null) {
                  children.add(_paddedIcon(icon));
                }
              }
              break;
            }
        }
      }

      if (_showRenderObjectPropertiesAsLinks &&
          propertyType == 'RenderObject') {
        textStyle = textStyle..merge(inspector_text_styles.link(colorScheme));
      }

      // TODO(jacobr): custom display for units, iterables, and padding.
      _addDescription(
        children,
        description,
        textStyle,
        colorScheme,
        isProperty: true,
      );

      if (diagnostic.level == DiagnosticLevel.fine &&
          diagnostic.hasDefaultValue) {
        children.add(const Text(' '));
        children.add(_paddedIcon(defaultIcon));
      }
    } else {
      // Non property, regular node case.
      if (name?.isNotEmpty == true && diagnostic.showName && name != 'child') {
        if (name.startsWith('child ')) {
          children.add(Text(
            name,
            style: inspector_text_styles.unimportant(colorScheme),
          ));
        } else {
          children.add(Text(name, style: textStyle));
        }

        if (diagnostic.showSeparator) {
          children.add(Text(
            diagnostic.separator,
            style: inspector_text_styles.unimportant(colorScheme),
          ));
          if (diagnostic.separator != ' ' &&
              diagnostic.description.isNotEmpty) {
            children.add(Text(
              ' ',
              style: inspector_text_styles.unimportant(colorScheme),
            ));
          }
        }
      }

      if (!diagnostic.isSummaryTree && diagnostic.isCreatedByLocalProject) {
        textStyle =
            textStyle.merge(inspector_text_styles.regularBold(colorScheme));
      }

      _addDescription(
        children,
        diagnostic.description,
        textStyle,
        colorScheme,
        isProperty: false,
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
