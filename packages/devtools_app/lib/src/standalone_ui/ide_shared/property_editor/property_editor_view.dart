// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../shared/primitives/utils.dart';
import '../../../shared/ui/common_widgets.dart';
import 'property_editor_controller.dart';
import 'property_editor_inputs.dart';
import 'property_editor_types.dart';

class PropertyEditorView extends StatelessWidget {
  const PropertyEditorView({required this.controller, super.key});

  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    return MultiValueListenableBuilder(
      listenables: [
        controller.editorClient.editArgumentMethodName,
        controller.editorClient.editableArgumentsMethodName,
        controller.editableArgs,
      ],
      builder: (_, values, _) {
        final editArgumentMethodName = values.first as String?;
        final editableArgumentsMethodName = values.second as String?;

        if (editArgumentMethodName == null ||
            editableArgumentsMethodName == null) {
          return const CenteredCircularProgressIndicator();
        }

        final editableWidgetData = values.third as EditableWidgetData?;
        if (editableWidgetData == null) {
          return const Center(
            child: Text(
              'No Flutter widget found at the current cursor location.',
            ),
          );
        }

        final (:args, :name, :documentation) = editableWidgetData;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name != null)
              _WidgetNameAndDocumentation(
                name: name,
                documentation: documentation,
              ),
            args.isEmpty
                ? _NoEditablePropertiesMessage(name: name)
                : _PropertiesList(
                  editableProperties: args.map(argToProperty).nonNulls.toList(),
                  editProperty: controller.editArgument,
                ),
          ],
        );
      },
    );
  }
}

class _PropertiesList extends StatelessWidget {
  const _PropertiesList({
    required this.editableProperties,
    required this.editProperty,
  });

  final List<EditableProperty> editableProperties;
  final EditArgumentFn editProperty;

  static const itemPadding = borderPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ...editableProperties.map(
          (property) => _EditablePropertyItem(
            property: property,
            editProperty: editProperty,
          ),
        ),
      ].joinWith(const PaddedDivider.noPadding()),
    );
  }
}

class _EditablePropertyItem extends StatelessWidget {
  const _EditablePropertyItem({
    required this.property,
    required this.editProperty,
  });

  final EditableProperty property;
  final EditArgumentFn editProperty;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(_PropertiesList.itemPadding),
            child: _PropertyInput(
              property: property,
              editProperty: editProperty,
            ),
          ),
        ),
        if (property.hasArgument || property.isDefault) ...[
          Flexible(child: _PropertyLabels(property: property)),
        ] else
          const Spacer(),
      ],
    );
  }
}

class _PropertyLabels extends StatelessWidget {
  const _PropertyLabels({required this.property});

  final EditableProperty property;

  static const _widthForFullLabels = 60;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSet = property.hasArgument;
    final isDefault = property.isDefault;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSet)
              Padding(
                padding: const EdgeInsets.all(_PropertiesList.itemPadding),
                child: RoundedLabel(
                  labelText: _maybeTruncateLabel('set', width: width),
                  backgroundColor: colorScheme.primary,
                  textColor: colorScheme.onPrimary,
                  tooltipText: 'Property argument is set.',
                ),
              ),
            if (isDefault)
              Padding(
                padding: const EdgeInsets.all(_PropertiesList.itemPadding),
                child: RoundedLabel(
                  labelText: _maybeTruncateLabel('default', width: width),
                  tooltipText: 'Property argument matches the default value.',
                ),
              ),
          ],
        );
      },
    );
  }

  String _maybeTruncateLabel(String labelText, {required double width}) =>
      width >= _widthForFullLabels ? labelText : labelText[0].toUpperCase();
}

class _PropertyInput extends StatelessWidget {
  const _PropertyInput({required this.property, required this.editProperty});

  final EditableProperty property;
  final EditArgumentFn editProperty;

  @override
  Widget build(BuildContext context) {
    final argType = property.type;
    switch (argType) {
      case boolType:
        return BooleanInput(
          property: property as FiniteValuesProperty,
          editProperty: editProperty,
        );
      case doubleType:
        return DoubleInput(
          property: property as NumericProperty,
          editProperty: editProperty,
        );
      case enumType:
        return EnumInput(
          property: property as FiniteValuesProperty,
          editProperty: editProperty,
        );
      case intType:
        return IntegerInput(
          property: property as NumericProperty,
          editProperty: editProperty,
        );
      case stringType:
        return StringInput(property: property, editProperty: editProperty);
      default:
        return Text(property.valueDisplay);
    }
  }
}

class _NoEditablePropertiesMessage extends StatelessWidget {
  const _NoEditablePropertiesMessage({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RichText(
      text: TextSpan(
        style: theme.regularTextStyle,
        children: [
          name == null
              ? const TextSpan(text: 'The selected widget ')
              : TextSpan(text: name, style: theme.fixedFontStyle),
          TextSpan(
            text:
                ' has no editable widget properties.\n\nThe Flutter Property Editor currently supports editing properties of type ',
            style: theme.regularTextStyle,
          ),
          TextSpan(text: 'string', style: theme.fixedFontStyle),
          const TextSpan(text: ', '),
          TextSpan(text: 'int', style: theme.fixedFontStyle),
          const TextSpan(text: ', '),
          TextSpan(text: 'double', style: theme.fixedFontStyle),
          const TextSpan(text: ', '),
          TextSpan(text: 'bool', style: theme.fixedFontStyle),
          const TextSpan(text: ', and '),
          TextSpan(text: 'enum', style: theme.fixedFontStyle),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

class _WidgetNameAndDocumentation extends StatelessWidget {
  const _WidgetNameAndDocumentation({required this.name, this.documentation});

  final String name;
  final String? documentation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: denseSpacing),
              child: Text(
                name,
                style: Theme.of(context).fixedFontStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: defaultFontSize + 1,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _ExpandableWidgetDocumentation(
                documentation:
                    documentation ?? 'Creates ${addIndefiniteArticle(name)}.',
              ),
            ),
          ],
        ),
        const PaddedDivider(),
      ],
    );
  }
}

class _ExpandableWidgetDocumentation extends StatefulWidget {
  const _ExpandableWidgetDocumentation({required this.documentation});

  final String documentation;

  @override
  State<_ExpandableWidgetDocumentation> createState() =>
      _ExpandableWidgetDocumentationState();
}

class _ExpandableWidgetDocumentationState
    extends State<_ExpandableWidgetDocumentation> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paragraphs = widget.documentation.split('\n');

    if (paragraphs.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            // Currently this will process the Dart doc each time a user expands
            // or collapses the text block. Because the Dart doc is never very
            // large, this is not an expensive operation. However, we could
            // consider caching the result if this needs to be optimized.
            text: _convertDartDoc(
              _isExpanded ? widget.documentation : paragraphs.first,
              regularFontStyle: theme.regularTextStyle,
              fixedFontStyle: theme.fixedFontStyle.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: densePadding),
              child: Text(
                _isExpanded ? 'Show less' : 'Show more',
                style: theme.boldTextStyle.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Text(widget.documentation);
    }
  }

  /// Converts a [dartDocText] String into a [TextSpan].
  ///
  /// Removes any brackets and backticks and displays the text inside them as
  /// fixed font.
  TextSpan _convertDartDoc(
    String dartDocText, {
    required TextStyle regularFontStyle,
    required TextStyle fixedFontStyle,
  }) {
    final children = <TextSpan>[];
    int currentIndex = 0;

    while (currentIndex < dartDocText.length) {
      final openBracketIndex = dartDocText.indexOf('[', currentIndex);
      final openBacktickIndex = dartDocText.indexOf('`', currentIndex);

      int nextSpecialCharIndex = -1;
      bool isLink = false;

      if (openBracketIndex != -1 &&
          (openBacktickIndex == -1 || openBracketIndex < openBacktickIndex)) {
        nextSpecialCharIndex = openBracketIndex;
        isLink = true;
      } else if (openBacktickIndex != -1 &&
          (openBracketIndex == -1 || openBacktickIndex < openBracketIndex)) {
        nextSpecialCharIndex = openBacktickIndex;
      }

      if (nextSpecialCharIndex == -1) {
        // No more special characters, add the remaining text.
        children.add(
          TextSpan(
            text: dartDocText.substring(currentIndex),
            style: regularFontStyle,
          ),
        );
        break;
      }

      // Add text before the special character.
      children.add(
        TextSpan(
          text: dartDocText.substring(currentIndex, nextSpecialCharIndex),
          style: regularFontStyle,
        ),
      );

      int closeIndex = -1;
      TextStyle currentStyle = regularFontStyle;
      if (isLink) {
        closeIndex = dartDocText.indexOf(']', nextSpecialCharIndex);
        currentStyle = fixedFontStyle;
      } else {
        closeIndex = dartDocText.indexOf('`', nextSpecialCharIndex + 1);
        currentStyle = fixedFontStyle;
      }

      if (closeIndex == -1) {
        // Treat unmatched brackets/backticks as regular text.
        children.add(
          TextSpan(
            text: dartDocText.substring(nextSpecialCharIndex),
            style: regularFontStyle,
          ),
        );
        currentIndex = dartDocText.length; // Effectively break the loop.
      } else {
        final content = dartDocText.substring(
          nextSpecialCharIndex + 1,
          closeIndex,
        );
        children.add(TextSpan(text: content, style: currentStyle));
        currentIndex = closeIndex + 1;
      }
    }

    return TextSpan(children: children);
  }
}
