// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../debugger/debugger_controller.dart';
import '../debugger/debugger_model.dart';
import '../debugger/hover.dart';
import '../debugger/variables.dart';
import '../globals.dart';
import '../theme.dart';
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
  const DiagnosticsNodeDescription(
    this.diagnostic, {
    this.isSelected,
    this.errorText,
    this.multiline = false,
    this.style,
    @required this.debuggerController,
  });

  final RemoteDiagnosticsNode diagnostic;
  final bool isSelected;
  final String errorText;
  final bool multiline;
  final TextStyle style;
  final DebuggerController debuggerController;

  Widget _paddedIcon(Widget icon) {
    return Padding(
      padding: const EdgeInsets.only(right: iconPadding),
      child: icon,
    );
  }

  Iterable<TextSpan> _buildDescriptionTextSpans(
    String description,
    TextStyle textStyle,
    ColorScheme colorScheme,
  ) sync* {
    if (diagnostic.isDiagnosticableValue) {
      final match = treeNodePrimaryDescriptionPattern.firstMatch(description);
      if (match != null) {
        yield TextSpan(text: match.group(1), style: textStyle);
        if (match.group(2).isNotEmpty) {
          yield TextSpan(
            text: match.group(2),
            style:
                textStyle.merge(inspector_text_styles.unimportant(colorScheme)),
          );
        }
        return;
      }
    } else if (diagnostic.type == 'ErrorDescription') {
      final match = assertionThrownBuildingError.firstMatch(description);
      if (match != null) {
        yield TextSpan(text: match.group(1), style: textStyle);
        yield TextSpan(text: match.group(3), style: textStyle);
        return;
      }
    }
    if (description?.isNotEmpty == true) {
      yield TextSpan(text: description, style: textStyle);
    }
  }

  Widget buildDescription(
    String description,
    TextStyle textStyle,
    BuildContext context,
    ColorScheme colorScheme, {
    bool isProperty,
  }) {
    final textSpan = TextSpan(
      children: _buildDescriptionTextSpans(
        description,
        textStyle,
        colorScheme,
      ).toList(),
    );

    return HoverCardTooltip(
      enabled: () =>
          diagnostic != null &&
          diagnostic.valueRef != null &&
          diagnostic.inspectorService != null,
      onHover: (event) async {
        final group =
            serviceManager.inspectorService.createObjectGroup('hover');
        final value = await group.toObservatoryInstanceRef(diagnostic.valueRef);
        final variable = Variable.fromValue(
          value: value,
          isolateRef: serviceManager.inspectorService.isolateRef,
          diagnostic: diagnostic,
        );
        await buildVariablesTree(variable);
        for (var child in variable.children) {
          await buildVariablesTree(child);
        }
        variable.expand();
        // TODO(jacobr): should we ensure the hover has not yet been cancelled?

        return HoverCardData(
          title: diagnostic.toStringShort(),
          contents: Material(
            child: ExpandableVariable(
              debuggerController: debuggerController,
              variable: ValueNotifier(variable),
            ),
          ),
        );
      },
      child: multiline
          ? SelectableText.rich(textSpan)
          : RichText(
              overflow: TextOverflow.ellipsis,
              text: textSpan,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (diagnostic == null) {
      return const SizedBox();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = diagnostic.icon;
    final children = <Widget>[];

    if (icon != null) {
      children.add(_paddedIcon(icon));
    }
    final String name = diagnostic.name;

    final defaultStyle = DefaultTextStyle.of(context).style;
    final baseStyle = style ?? defaultStyle;
    TextStyle textStyle =
        baseStyle.merge(textStyleForLevel(diagnostic.level, colorScheme));
    var descriptionTextStyle = textStyle;
    // TODO(jacobr): use TextSpans and SelectableText instead of Text.
    if (diagnostic.isProperty) {
      // Display of inline properties.
      final String propertyType = diagnostic.propertyType;
      final Map<String, Object> properties = diagnostic.valuePropertiesJson;

      if (name?.isNotEmpty == true && diagnostic.showName) {
        children.add(Text('$name${diagnostic.separator} ', style: textStyle));
        // provide some contrast between the name and description if both are
        // present.
        descriptionTextStyle =
            descriptionTextStyle.merge(theme.subtleTextStyle);
      }

      if (diagnostic.isCreatedByLocalProject) {
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
      children.add(Flexible(
        child: buildDescription(
          description,
          descriptionTextStyle,
          context,
          colorScheme,
          isProperty: true,
        ),
      ));

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
            style: textStyle,
          ));
          if (diagnostic.separator != ' ' &&
              (diagnostic.description?.isNotEmpty ?? false)) {
            children.add(Text(
              ' ',
              style: textStyle,
            ));
          }
        }
      }

      if (!diagnostic.isSummaryTree && diagnostic.isCreatedByLocalProject) {
        textStyle = textStyle.merge(inspector_text_styles.regularBold);
      }

      var diagnosticDescription = buildDescription(
        diagnostic.description,
        descriptionTextStyle,
        context,
        colorScheme,
        isProperty: false,
      );

      if (errorText != null) {
        // TODO(dantup): Find if there's a way to achieve this without
        //  the nested row.
        diagnosticDescription = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            diagnosticDescription,
            _buildErrorText(colorScheme),
          ],
        );
      } else if (multiline &&
          diagnostic.hasCreationLocation &&
          !diagnostic.isProperty) {
        diagnosticDescription = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            diagnosticDescription,
            _buildLocation(),
          ],
        );
      }

      children.add(Expanded(child: diagnosticDescription));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildLocation() {
    final location = diagnostic.creationLocation;
    return Flexible(
      child: RichText(
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          text:
              '${location.getFile().split('/').last}:${location.getLine()}:${location.getColumn()}            ',
          style: inspector_text_styles.regular,
        ),
      ),
    );
  }

  Flexible _buildErrorText(ColorScheme colorScheme) {
    return Flexible(
      child: RichText(
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          text: errorText,
          // When the node is selected, the background will be an error
          // color so don't render the text the same color.
          style: isSelected
              ? inspector_text_styles.regular
              : inspector_text_styles.error(colorScheme),
        ),
      ),
    );
  }
}
