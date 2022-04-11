// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:flutter/material.dart';

import '../../primitives/utils.dart';
import '../../shared/globals.dart';
import '../../shared/theme.dart';
import '../../ui/hover.dart';
import '../../ui/icons.dart';
import '../debugger/debugger_controller.dart';
import '../debugger/debugger_model.dart';
import '../debugger/variables.dart';
import 'diagnostics_node.dart';
import 'inspector_controller.dart';
import 'inspector_text_styles.dart' as inspector_text_styles;
import 'inspector_tree.dart';

final _colorIconMaker = ColorIconMaker();
final _customIconMaker = CustomIconMaker();
final defaultIcon = _customIconMaker.fromInfo('Default');

const _showRenderObjectPropertiesAsLinks = false;

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
    this.isSelected = false,
    this.searchValue,
    this.errorText,
    this.multiline = false,
    this.style,
    required this.debuggerController,
    this.nodeDescriptionHighlightStyle,
  });

  final RemoteDiagnosticsNode? diagnostic;
  final bool isSelected;
  final String? errorText;
  final String? searchValue;
  final bool multiline;
  final TextStyle? style;
  final DebuggerController debuggerController;
  final TextStyle? nodeDescriptionHighlightStyle;

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
    final diagnosticLocal = diagnostic!;
    if (diagnosticLocal.isDiagnosticableValue) {
      final match = treeNodePrimaryDescriptionPattern.firstMatch(description);
      if (match != null) {
        yield TextSpan(text: match.group(1), style: textStyle);
        if (match.group(2)?.isNotEmpty == true) {
          yield TextSpan(
            text: match.group(2),
            style:
                textStyle.merge(inspector_text_styles.unimportant(colorScheme)),
          );
        }
        return;
      }
    } else if (diagnosticLocal.type == 'ErrorDescription') {
      final match = assertionThrownBuildingError.firstMatch(description);
      if (match != null) {
        yield TextSpan(text: match.group(1), style: textStyle);
        yield TextSpan(text: match.group(3), style: textStyle);
        return;
      }
    }

    if (description.isNotEmpty == true) {
      yield TextSpan(text: description, style: textStyle);
    }

    final textPreview = diagnosticLocal.json['textPreview'];
    if (textPreview is String) {
      final preview = textPreview.replaceAll('\n', ' ');
      yield TextSpan(
        children: [
          TextSpan(
            text: ': ',
            style: textStyle,
          ),
          _buildHighlightedSearchPreview(
            preview,
            searchValue,
            textStyle,
            textStyle.merge(nodeDescriptionHighlightStyle),
          ),
        ],
      );
    }
  }

  Widget buildDescription(
    String description,
    TextStyle textStyle,
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final textSpan = TextSpan(
      children: _buildDescriptionTextSpans(
        description,
        textStyle,
        colorScheme,
      ).toList(),
    );

    final diagnosticLocal = diagnostic!;
    final inspectorService = serviceManager.inspectorService!;

    return HoverCardTooltip(
      enabled: () => diagnosticLocal.inspectorService != null,
      onHover: (event) async {
        final group = inspectorService.createObjectGroup('hover');
        final value =
            await group.toObservatoryInstanceRef(diagnosticLocal.valueRef);
        final variable = DartObjectNode.fromValue(
          value: value,
          isolateRef: inspectorService.isolateRef,
          diagnostic: diagnosticLocal,
        );
        await buildVariablesTree(variable);
        for (var child in variable.children) {
          await buildVariablesTree(child);
        }
        variable.expand();
        // TODO(jacobr): should we ensure the hover has not yet been cancelled?

        return HoverCardData(
          title: diagnosticLocal.toStringShort(),
          contents: Material(
            child: ExpandableVariable(
              debuggerController: debuggerController,
              variable: variable,
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
    final diagnosticLocal = diagnostic;

    if (diagnosticLocal == null) {
      return const SizedBox();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = diagnosticLocal.icon;
    final children = <Widget>[];

    if (icon != null) {
      children.add(_paddedIcon(icon));
    }
    final name = diagnosticLocal.name;

    final defaultStyle = DefaultTextStyle.of(context).style;
    final baseStyle = style ?? defaultStyle;
    TextStyle textStyle =
        baseStyle.merge(textStyleForLevel(diagnosticLocal.level, colorScheme));
    var descriptionTextStyle = textStyle;
    // TODO(jacobr): use TextSpans and SelectableText instead of Text.
    if (diagnosticLocal.isProperty) {
      // Display of inline properties.
      final propertyType = diagnosticLocal.propertyType;
      final properties = diagnosticLocal.valuePropertiesJson;

      if (name?.isNotEmpty == true && diagnosticLocal.showName) {
        children.add(
          Text(
            '$name${diagnosticLocal.separator} ',
            style: textStyle,
          ),
        );
        // provide some contrast between the name and description if both are
        // present.
        descriptionTextStyle =
            descriptionTextStyle.merge(theme.subtleTextStyle);
      }

      if (diagnosticLocal.isCreatedByLocalProject) {
        textStyle = textStyle.merge(inspector_text_styles.regularBold);
      }

      String description = diagnosticLocal.description ?? '';
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
                children.add(_paddedIcon(icon));
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
      children.add(
        Flexible(
          child: buildDescription(
            description,
            descriptionTextStyle,
            context,
            colorScheme,
          ),
        ),
      );

      if (diagnosticLocal.level == DiagnosticLevel.fine &&
          diagnosticLocal.hasDefaultValue) {
        children.add(const Text(' '));
        children.add(_paddedIcon(defaultIcon));
      }
    } else {
      // Non property, regular node case.
      if (name != null &&
          name.isNotEmpty &&
          diagnosticLocal.showName &&
          name != 'child') {
        if (name.startsWith('child ')) {
          children.add(
            Text(
              name,
              style: inspector_text_styles.unimportant(colorScheme),
            ),
          );
        } else {
          children.add(Text(name, style: textStyle));
        }

        if (diagnosticLocal.showSeparator) {
          children.add(
            Text(
              diagnosticLocal.separator,
              style: textStyle,
            ),
          );
          if (diagnosticLocal.separator != ' ' &&
              (diagnosticLocal.description?.isNotEmpty ?? false)) {
            children.add(
              Text(
                ' ',
                style: textStyle,
              ),
            );
          }
        }
      }

      if (!diagnosticLocal.isSummaryTree &&
          diagnosticLocal.isCreatedByLocalProject) {
        textStyle = textStyle.merge(inspector_text_styles.regularBold);
      }

      var diagnosticDescription = buildDescription(
        diagnosticLocal.description ?? '',
        descriptionTextStyle,
        context,
        colorScheme,
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
          diagnosticLocal.hasCreationLocation &&
          !diagnosticLocal.isProperty) {
        diagnosticDescription = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            diagnosticDescription,
            _buildLocation(context),
          ],
        );
      }

      children.add(Expanded(child: diagnosticDescription));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildLocation(BuildContext context) {
    final theme = Theme.of(context);
    final location = diagnostic!.creationLocation!;
    return Flexible(
      child: RichText(
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          text:
              '${location.getFile()!.split('/').last}:${location.getLine()}:${location.getColumn()}            ',
          style: inspector_text_styles.regular
              .copyWith(color: theme.colorScheme.defaultForeground),
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

  TextSpan _buildHighlightedSearchPreview(
    String textPreview,
    String? searchValue,
    TextStyle textStyle,
    TextStyle highlightTextStyle,
  ) {
    if (searchValue == null || searchValue.isEmpty) {
      return TextSpan(
        text: '"$textPreview"',
        style: textStyle,
      );
    }

    if (textPreview.caseInsensitiveEquals(searchValue)) {
      return TextSpan(
        text: '"$textPreview"',
        style: highlightTextStyle,
      );
    }

    final matches = searchValue.caseInsensitiveAllMatches(textPreview);
    if (matches.isEmpty) {
      return TextSpan(
        text: '"$textPreview"',
        style: textStyle,
      );
    }

    final quoteSpan = TextSpan(text: '"', style: textStyle);
    final spans = <TextSpan>[quoteSpan];
    var previousItemEnd = 0;
    for (final match in matches) {
      if (match.start > previousItemEnd) {
        spans.add(
          TextSpan(
            text: textPreview.substring(previousItemEnd, match.start),
            style: textStyle,
          ),
        );
      }

      spans.add(
        TextSpan(
          text: textPreview.substring(match.start, match.end),
          style: highlightTextStyle,
        ),
      );

      previousItemEnd = match.end;
    }

    spans.add(
      TextSpan(
        text: textPreview.substring(previousItemEnd, textPreview.length),
        style: textStyle,
      ),
    );
    spans.add(quoteSpan);

    return TextSpan(children: spans);
  }
}
