// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Library with legacy inspector_tree functionality only required to keep the
/// dart:html version of the app running.
///
/// If you update any functionality in this file be sure to update the
/// corresponding code in the Flutter version of the application.
library inspector_tree_legacy;

import 'package:vm_service/vm_service.dart';

import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/icons.dart';
import '../ui/material_icons.dart';
import '../utils.dart';
import 'inspector_controller.dart';
import 'inspector_text_styles.dart' as inspector_text_styles;
import 'inspector_tree.dart';

final ColorIconMaker _colorIconMaker = ColorIconMaker();
final CustomIconMaker _customIconMaker = CustomIconMaker();

final DevToolsIcon defaultIcon = _customIconMaker.fromInfo('Default');

const bool _showRenderObjectPropertiesAsLinks = false;

abstract class InspectorTreeControllerLegacy extends InspectorTreeController {
  void onTapIcon(InspectorTreeRow row, DevToolsIcon icon) {
    if (icon == expandArrow) {
      onExpandRow(row);
      return;
    }
    if (icon == collapseArrow) {
      onCollapseRow(row);
      return;
    }
    // TODO(jacobr): add other interactive elements here.
    onSelectRow(row);
  }

  void onTap(Offset offset) {
    final row = getRow(offset);
    if (row == null) {
      return;
    }

    final InspectorTreeNodeLegacy node = row.node;
    onTapIcon(row, node.renderObject?.hitTest(offset)?.icon);
  }

  String get tooltip;
  set tooltip(String value);
  bool _computingHover = false;

  Future<void> onHover(InspectorTreeNode node, PaintEntry entry) async {
    if (config.onHover != null) {
      config.onHover(node, entry?.icon);
    }

    final diagnostic = node?.diagnostic;
    final lastHover = currentHoverDiagnostic;
    currentHoverDiagnostic = diagnostic;
    // Only show tooltips when we are hovering over specific content in a row
    // rather than over the entire row.
    // TODO(jacobr): consider showing the tooltip any time we are on a row with
    // a diagnostics node to make tooltips more discoverable.
    // To make this work well we would need to add custom tooltip rendering that
    // more clearly links tooltips to the exact content in a row they apply to.
    if (diagnostic == null || entry == null) {
      tooltip = '';
      _computingHover = false;
      return;
    }

    if (entry.icon == defaultIcon) {
      tooltip = 'Default value';
      _computingHover = false;
      return;
    }

    if (diagnostic.isEnumProperty()) {
      // We can display a better tooltip than the one provied with the
      // RemoteDiagnosticsNode as we have access to introspection
      // via the vm service.

      if (lastHover == diagnostic && _computingHover) {
        // No need to spam the VMService. We are already computing the hover
        // for this node.
        return;
      }
      _computingHover = true;
      Map<String, InstanceRef> properties;
      try {
        properties = await diagnostic.valueProperties;
      } finally {
        _computingHover = false;
      }
      if (lastHover != diagnostic) {
        // Skipping as the tooltip is no longer relevant for the currently
        // hovered over node.
        return;
      }
      if (properties == null) {
        // Something went wrong getting the enum value.
        // Fall back to the regular tooltip;
        tooltip = diagnostic.tooltip;
        return;
      }
      tooltip = 'Allowed values:\n${properties.keys.join('\n')}';
      return;
    }

    tooltip = diagnostic.tooltip;
    _computingHover = false;
  }
}

// Legacy tree node class for dart:html based app.
abstract class InspectorTreeNodeLegacy extends InspectorTreeNode {
  /// Override this method to define a tree node to build render objects
  /// appropriate for a specific platform.
  InspectorTreeNodeRenderBuilder createRenderBuilder();

  /// This method defines the logic of how a RenderObject is converted to
  /// a list of styled text and icons. If you want to change how tree content
  /// is styled modify this message as it is the robust way for style changes
  /// to apply to all ways inspector trees are rendered (html, canvas, Flutter
  /// in the future).
  /// If you change this rendering also change the matching logic in
  /// src/io/flutter/view/DiagnosticsTreeCellRenderer.java
  InspectorTreeNodeRender get renderObject {
    if (_renderObject != null || diagnostic == null) {
      return _renderObject;
    }

    final builder = createRenderBuilder();
    final icon = diagnostic.icon;
    if (showExpandCollapse) {
      builder.addIcon(isExpanded ? collapseArrow : expandArrow);
    }
    if (icon != null) {
      builder.addIcon(icon);
    }
    final String name = diagnostic.name;
    TextStyle textStyle = textStyleForLevel(diagnostic.level);
    if (diagnostic.isProperty) {
      // Display of inline properties.
      final String propertyType = diagnostic.propertyType;
      final Map<String, Object> properties = diagnostic.valuePropertiesJson;

      if (name?.isNotEmpty == true && diagnostic.showName) {
        builder.appendText('$name${diagnostic.separator} ', textStyle);
      }

      if (isCreatedByLocalProject) {
        textStyle = textStyle.merge(inspector_text_styles.regularBold);
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
              builder.addIcon(_colorIconMaker.getCustomIcon(color));
              break;
            }

          case 'IconData':
            {
              final int codePoint =
                  JsonUtils.getIntMember(properties, 'codePoint');
              if (codePoint > 0) {
                final DevToolsIcon icon =
                    FlutterMaterialIcons.getIconForCodePoint(codePoint);
                if (icon != null) {
                  builder.addIcon(icon);
                }
              }
              break;
            }
        }
      }

      if (_showRenderObjectPropertiesAsLinks &&
          propertyType == 'RenderObject') {
        textStyle = textStyle..merge(inspector_text_styles.link);
      }

      // TODO(jacobr): custom display for units, iterables, and padding.
      _renderDescription(builder, description, textStyle, isProperty: true);

      if (diagnostic.level == DiagnosticLevel.fine &&
          diagnostic.hasDefaultValue) {
        builder.appendText(' ', textStyle);
        builder.addIcon(defaultIcon);
      }
    } else {
      // Non property, regular node case.
      if (name?.isNotEmpty == true && diagnostic.showName && name != 'child') {
        if (name.startsWith('child ')) {
          builder.appendText(name, inspector_text_styles.unimportant);
        } else {
          builder.appendText(name, textStyle);
        }

        if (diagnostic.showSeparator) {
          builder.appendText(
              diagnostic.separator, inspector_text_styles.unimportant);
          if (diagnostic.separator != ' ' &&
              diagnostic.description.isNotEmpty) {
            builder.appendText(' ', inspector_text_styles.unimportant);
          }
        }
      }

      if (!diagnostic.isSummaryTree && diagnostic.isCreatedByLocalProject) {
        textStyle = textStyle.merge(inspector_text_styles.regularBold);
      }

      _renderDescription(builder, diagnostic.description, textStyle,
          isProperty: false);
    }
    _renderObject = builder.build();
    return _renderObject;
  }

  void _renderDescription(
    InspectorTreeNodeRenderBuilder builder,
    String description,
    TextStyle textStyle, {
    bool isProperty,
  }) {
    if (diagnostic.isDiagnosticableValue) {
      final match = treeNodePrimaryDescriptionPattern.firstMatch(description);
      if (match != null) {
        builder.appendText(match.group(1), textStyle);
        if (match.group(2).isNotEmpty) {
          builder.appendText(match.group(2), inspector_text_styles.unimportant);
        }
        return;
      }
    } else if (diagnostic.type == 'ErrorDescription') {
      final match = assertionThrownBuildingError.firstMatch(description);
      if (match != null) {
        builder.appendText(match.group(1), textStyle);
        builder.appendText(match.group(3), textStyle);
        return;
      }
    }
    if (description?.isNotEmpty == true) {
      builder.appendText(description, textStyle);
    }
  }

  InspectorTreeNodeRender _renderObject;

  @override
  set isDirty(bool dirty) {
    if (dirty) {
      _renderObject = null;
    }
    super.isDirty = dirty;
  }
}
