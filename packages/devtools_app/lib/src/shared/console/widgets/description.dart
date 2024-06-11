// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../diagnostics/dart_object_node.dart';
import '../../diagnostics/diagnostics_node.dart';
import '../../diagnostics/tree_builder.dart';
import '../../diagnostics_text_styles.dart';
import '../../feature_flags.dart';
import '../../globals.dart';
import '../../primitives/utils.dart';
import '../../ui/hover.dart';
import '../../ui/icons.dart';
import '../../ui/utils.dart';
import '../eval/inspector_tree.dart';
import 'expandable_variable.dart';

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
    super.key,
    this.isSelected = false,
    this.searchValue,
    this.errorText,
    this.multiline = false,
    this.style,
    this.nodeDescriptionHighlightStyle,
    this.emphasizeNodesFromLocalProject = false,
  });

  final RemoteDiagnosticsNode? diagnostic;
  final bool isSelected;
  final String? errorText;
  final String? searchValue;
  final bool multiline;
  final TextStyle? style;
  final TextStyle? nodeDescriptionHighlightStyle;
  final bool emphasizeNodesFromLocalProject;

  static Widget _paddedIcon(Widget icon) {
    return Padding(
      padding: const EdgeInsets.only(right: iconPadding),
      child: icon,
    );
  }

  /// Approximates the width of the elements inside a [RemoteDiagnosticsNode]
  /// widget.
  static double approximateNodeWidth(
    RemoteDiagnosticsNode? diagnostic,
  ) {
    // If we have rendered this node, then we know it's text style,
    // otherwise assume defaultFontSize for the TextStyle.
    final textStyle = diagnostic?.descriptionTextStyleFromBuild ??
        TextStyle(fontSize: defaultFontSize);

    final spans = DiagnosticsNodeDescription.buildDescriptionTextSpans(
      description: diagnostic?.description ?? '',
      textStyle: textStyle,
      colorScheme: const ColorScheme.dark(),
      diagnostic: diagnostic,
    );

    var spanWidth = spans.fold<double>(
      0,
      (sum, span) => sum + calculateTextSpanWidth(span),
    );
    String? name = diagnostic?.name;

    // An Icon is approximately the width of 1 character

    if (diagnostic?.showName == true && name != null) {
      // The diagnostic will show its name instead of an icon so add an
      // approximate name width.

      if (diagnostic?.description != null) {
        // If there is a description then a separator will show with the name.
        name += ': ';
      }
      spanWidth +=
          calculateTextSpanWidth(TextSpan(text: name, style: textStyle));
    } else {
      final approximateIconWidth = IconKind.info.icon.width + iconPadding;

      // When there is no name, an icon will be shown with the text spans.
      spanWidth += approximateIconWidth;
    }
    return spanWidth;
  }

  static Iterable<TextSpan> buildDescriptionTextSpans({
    required String description,
    required TextStyle textStyle,
    required ColorScheme colorScheme,
    RemoteDiagnosticsNode? diagnostic,
    String? searchValue,
    TextStyle? nodeDescriptionHighlightStyle,
  }) sync* {
    final diagnosticLocal = diagnostic!;
    if (diagnosticLocal.isDiagnosticableValue) {
      final match = treeNodePrimaryDescriptionPattern.firstMatch(description);
      if (match != null) {
        yield TextSpan(text: match.group(1), style: textStyle);
        if (match.group(2)?.isNotEmpty == true) {
          yield TextSpan(
            text: match.group(2),
            style:
                textStyle.merge(DiagnosticsTextStyles.unimportant(colorScheme)),
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

    if (description.isNotEmpty) {
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

  Widget buildDescription({
    required String description,
    required TextStyle textStyle,
    required ColorScheme colorScheme,
    RemoteDiagnosticsNode? diagnostic,
    String? searchValue,
    TextStyle? nodeDescriptionHighlightStyle,
  }) {
    // Store the textStyle of the built widget so that it can be used in
    // [approximateNodeWidth] later.
    diagnostic?.descriptionTextStyleFromBuild = textStyle;

    final textSpan = TextSpan(
      children: buildDescriptionTextSpans(
        description: description,
        textStyle: textStyle,
        colorScheme: colorScheme,
        diagnostic: diagnostic,
        searchValue: searchValue,
        nodeDescriptionHighlightStyle: nodeDescriptionHighlightStyle,
      ).toList(),
    );

    final diagnosticLocal = diagnostic!;
    final inspectorService = serviceConnection.inspectorService!;

    return HoverCardTooltip.async(
      enabled: () =>
          // TODO(https://github.com/flutter/devtools/issues/7860) Clean up
          // after Inspector V2 release.
          FeatureFlags.inspectorV2
              ? preferences.inspectorV2.hoverEvalModeEnabled.value &&
                  diagnosticLocal.objectGroupApi != null
              : preferences.inspector.hoverEvalModeEnabled.value &&
                  diagnosticLocal.objectGroupApi != null,
      asyncGenerateHoverCardData: ({
        required event,
        required isHoverStale,
      }) async {
        final group = inspectorService.createObjectGroup('hover');

        if (isHoverStale()) return Future.value();
        final value =
            await group.toObservatoryInstanceRef(diagnosticLocal.valueRef);

        final variable = DartObjectNode.fromValue(
          value: value,
          isolateRef: inspectorService.isolateRef,
          diagnostic: diagnosticLocal,
        );

        if (isHoverStale()) return Future.value();
        await buildVariablesTree(variable);
        final tasks = <Future<void>>[];
        for (final child in variable.children) {
          tasks.add(() async {
            if (!isHoverStale()) await buildVariablesTree(child);
          }());
        }
        await Future.wait(tasks);
        variable.expand();

        return HoverCardData(
          title: diagnosticLocal.toStringShort(),
          contents: Material(
            child: ExpandableVariable(
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
    TextStyle textStyle = baseStyle.merge(
      DiagnosticsTextStyles.textStyleForLevel(
        diagnosticLocal.level,
        colorScheme,
      ),
    );
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
        textStyle = textStyle.merge(theme.subtleTextStyle);
      }

      if (diagnosticLocal.isCreatedByLocalProject) {
        textStyle = textStyle.merge(DiagnosticsTextStyles.regularBold);
      }

      String description = diagnosticLocal.description ?? '';
      if (propertyType != null && properties != null) {
        switch (propertyType) {
          case 'Color':
            {
              final alpha = JsonUtils.getIntMember(properties, 'alpha');
              final red = JsonUtils.getIntMember(properties, 'red');
              final green = JsonUtils.getIntMember(properties, 'green');
              final blue = JsonUtils.getIntMember(properties, 'blue');
              String radix(int chan) => chan.toRadixString(16).padLeft(2, '0');
              description = alpha == 255
                  ? '#${radix(red)}${radix(green)}${radix(blue)}'
                  : '#${radix(alpha)}${radix(red)}${radix(green)}${radix(blue)}';

              final color = Color.fromARGB(alpha, red, green, blue);
              children.add(_paddedIcon(_colorIconMaker.getCustomIcon(color)));
              break;
            }

          case 'IconData':
            {
              final codePoint = JsonUtils.getIntMember(properties, 'codePoint');
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
        textStyle = textStyle..merge(DiagnosticsTextStyles.link(colorScheme));
      }

      // TODO(jacobr): custom display for units, iterables, and padding.
      children.add(
        Flexible(
          child: buildDescription(
            description: description,
            textStyle: textStyle,
            colorScheme: colorScheme,
            diagnostic: diagnostic,
            searchValue: searchValue,
            nodeDescriptionHighlightStyle: nodeDescriptionHighlightStyle,
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
              style: DiagnosticsTextStyles.unimportant(colorScheme),
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

      // Grey out nodes that were not created by the local project to emphasize
      // those that were:
      if (emphasizeNodesFromLocalProject &&
          !diagnosticLocal.isCreatedByLocalProject) {
        textStyle = textStyle.merge(theme.subtleTextStyle);
      }

      var diagnosticDescription = buildDescription(
        description: diagnosticLocal.description ?? '',
        textStyle: textStyle,
        colorScheme: colorScheme,
        diagnostic: diagnostic,
        searchValue: searchValue,
        nodeDescriptionHighlightStyle: nodeDescriptionHighlightStyle,
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
    final location = diagnostic!.creationLocation!;
    return Flexible(
      child: RichText(
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          text:
              '${location.getFile()!.split('/').last}:${location.getLine()}:${location.getColumn()}            ',
          style: DiagnosticsTextStyles.regular(Theme.of(context).colorScheme),
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
              ? DiagnosticsTextStyles.regular(colorScheme)
              : DiagnosticsTextStyles.error(colorScheme),
        ),
      ),
    );
  }

  static TextSpan _buildHighlightedSearchPreview(
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
