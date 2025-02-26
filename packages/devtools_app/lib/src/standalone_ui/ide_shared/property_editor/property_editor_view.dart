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
import 'utils/utils.dart';

class PropertyEditorView extends StatelessWidget {
  const PropertyEditorView({required this.controller, super.key});

  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    return MultiValueListenableBuilder(
      listenables: [
        controller.editorClient.editArgumentMethodName,
        controller.editorClient.editableArgumentsMethodName,
        controller.editableWidgetData,
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
          return const CenteredMessage(
            message: 'No Flutter widget found at the current cursor location.',
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

class _PropertiesList extends StatefulWidget {
  const _PropertiesList({
    required this.editableProperties,
    required this.editProperty,
  });

  final List<EditableProperty> editableProperties;
  final EditArgumentFunction editProperty;

  static const defaultItemPadding = borderPadding;
  static const denseItemPadding = defaultItemPadding / 2;

  @override
  State<_PropertiesList> createState() => _PropertiesListState();
}

class _PropertiesListState extends State<_PropertiesList> {
  @override
  void initState() {
    super.initState();
    // Workaround for https://github.com/flutter/devtools/issues/8929.
    setUpTextFieldFocusFixHandler();
  }

  @override
  void dispose() {
    super.dispose();
    // Workaround for https://github.com/flutter/devtools/issues/8929.
    removeTextFieldFocusFixHandler();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final property in widget.editableProperties)
          _EditablePropertyItem(
            property: property,
            editProperty: widget.editProperty,
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
  final EditArgumentFunction editProperty;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(_PropertiesList.defaultItemPadding),
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
                padding: _labelPadding(isTopLabel: true),
                child: RoundedLabel(
                  labelText: _maybeTruncateLabel('set', width: width),
                  tooltipText: 'Property argument is set.',
                  fontSize: smallFontSize,
                  backgroundColor: colorScheme.primary,
                  textColor: colorScheme.onPrimary,
                ),
              ),
            if (isDefault)
              Padding(
                padding: _labelPadding(isTopLabel: !isSet),
                child: RoundedLabel(
                  labelText: _maybeTruncateLabel('default', width: width),
                  tooltipText: 'Property argument matches the default value.',
                  fontSize: smallFontSize,
                ),
              ),
          ],
        );
      },
    );
  }

  EdgeInsets _labelPadding({required bool isTopLabel}) => EdgeInsets.fromLTRB(
    _PropertiesList.defaultItemPadding,
    isTopLabel
        ? _PropertiesList.defaultItemPadding
        : _PropertiesList.denseItemPadding,
    _PropertiesList.defaultItemPadding,
    isTopLabel
        ? _PropertiesList.denseItemPadding
        : _PropertiesList.defaultItemPadding,
  );

  String _maybeTruncateLabel(String labelText, {required double width}) =>
      width >= _widthForFullLabels ? labelText : labelText[0].toUpperCase();
}

class _PropertyInput extends StatelessWidget {
  const _PropertyInput({required this.property, required this.editProperty});

  final EditableProperty property;
  final EditArgumentFunction editProperty;

  @override
  Widget build(BuildContext context) {
    final argType = property.type;
    final propertyKey = Key(property.hashCode.toString());
    switch (argType) {
      case boolType:
        return BooleanInput(
          key: propertyKey,
          property: property as FiniteValuesProperty,
          editProperty: editProperty,
        );
      case doubleType:
        return DoubleInput(
          key: propertyKey,
          property: property as NumericProperty,
          editProperty: editProperty,
        );
      case enumType:
        return EnumInput(
          key: propertyKey,
          property: property as FiniteValuesProperty,
          editProperty: editProperty,
        );
      case intType:
        return IntegerInput(
          key: propertyKey,
          property: property as NumericProperty,
          editProperty: editProperty,
        );
      case stringType:
        return StringInput(
          key: propertyKey,
          property: property,
          editProperty: editProperty,
        );
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
    final fixedFontStyle = theme.fixedFontStyle.copyWith(
      color: theme.colorScheme.primary,
    );

    return RichText(
      text: TextSpan(
        style: theme.regularTextStyle,
        children: [
          name == null
              ? const TextSpan(text: 'The selected widget ')
              : TextSpan(text: name, style: fixedFontStyle),
          TextSpan(
            text:
                ' has no editable widget properties.\n\nThe Flutter Property Editor currently supports editing properties of type ',
            style: theme.regularTextStyle,
          ),
          TextSpan(text: 'string', style: fixedFontStyle),
          const TextSpan(text: ', '),
          TextSpan(text: 'int', style: fixedFontStyle),
          const TextSpan(text: ', '),
          TextSpan(text: 'double', style: fixedFontStyle),
          const TextSpan(text: ', '),
          TextSpan(text: 'bool', style: fixedFontStyle),
          const TextSpan(text: ', and '),
          TextSpan(text: 'enum', style: fixedFontStyle),
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
      mainAxisSize: MainAxisSize.min,
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
    extends State<_ExpandableWidgetDocumentation>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandAnimationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandAnimationController = defaultAnimationController(this);
    _expandAnimation = defaultCurvedAnimation(_expandAnimationController);
  }

  @override
  void dispose() {
    _expandAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final regularFontStyle = theme.regularTextStyle;
    final fixedFontStyle = theme.fixedFontStyle.copyWith(
      color: theme.colorScheme.primary,
    );
    final paragraphs = widget.documentation.split('\n');

    if (paragraphs.length == 1) {
      return convertDartDocToRichText(
        widget.documentation,
        regularFontStyle: regularFontStyle,
        fixedFontStyle: fixedFontStyle,
      );
    }

    final [firstParagraph, ...otherParagraphs] = paragraphs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Currently this will process the Dart doc each time a user expands
        // or collapses the text block. Because the Dart doc is never very
        // large, this is not an expensive operation. However, we could
        // consider caching the result if this needs to be optimized.
        convertDartDocToRichText(
          firstParagraph,
          regularFontStyle: regularFontStyle,
          fixedFontStyle: fixedFontStyle,
        ),
        if (_isExpanded)
          FadeTransition(
            opacity: _expandAnimation,
            child: convertDartDocToRichText(
              otherParagraphs.join('\n'),
              regularFontStyle: regularFontStyle,
              fixedFontStyle: fixedFontStyle,
            ),
          ),
        const SizedBox(height: denseSpacing),
        InkWell(
          onTap: _toggleExpansion,
          child: Text(
            _isExpanded ? 'Show less' : 'Show more',
            style: theme.boldTextStyle.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandAnimationController.forward();
      } else {
        _expandAnimationController.reverse();
      }
    });
  }
}
