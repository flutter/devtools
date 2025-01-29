// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/editor/api_classes.dart';
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
      ],
      builder: (_, values, _) {
        final editArgumentMethodName = values.first as String?;
        final editableArgumentsMethodName = values.second as String?;

        if (editArgumentMethodName == null ||
            editableArgumentsMethodName == null) {
          return const CenteredCircularProgressIndicator();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TODO(elliette): Include widget name and documentation.
            _PropertiesList(controller: controller),
          ],
        );
      },
    );
  }
}

class _PropertiesList extends StatelessWidget {
  const _PropertiesList({required this.controller});

  final PropertyEditorController controller;

  static const itemPadding = borderPadding;

  @override
  Widget build(BuildContext context) {
    // TODO(https://github.com/flutter/devtools/issues/8546) Switch to scrollable
    // ListView when this has been moved into its own panel.
    return ValueListenableBuilder<List<EditableArgument>>(
      valueListenable: controller.editableArgs,
      builder: (context, args, _) {
        return args.isEmpty
            ? const Center(
              child: Text(
                'No widget properties at the current cursor location.',
              ),
            )
            : Column(
              children: <Widget>[
                ...args
                    .map((arg) => argToProperty(arg))
                    .nonNulls
                    .map(
                      (property) => _EditablePropertyItem(
                        property: property,
                        controller: controller,
                      ),
                    ),
              ].joinWith(const PaddedDivider.noPadding()),
            );
      },
    );
  }
}

class _EditablePropertyItem extends StatelessWidget {
  const _EditablePropertyItem({
    required this.property,
    required this.controller,
  });

  final EditableProperty property;
  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(_PropertiesList.itemPadding),
            child: _PropertyInput(property: property, controller: controller),
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
  const _PropertyInput({required this.property, required this.controller});

  final EditableProperty property;
  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    final argType = property.type;
    switch (argType) {
      case boolType:
        return BooleanInput(
          property: property as FiniteValuesProperty,
          controller: controller,
        );
      case doubleType:
        return DoubleInput(
          property: property as NumericProperty,
          controller: controller,
        );
      case enumType:
        return EnumInput(
          property: property as FiniteValuesProperty,
          controller: controller,
        );
      case intType:
        return IntegerInput(
          property: property as NumericProperty,
          controller: controller,
        );
      case stringType:
        return StringInput(property: property, controller: controller);
      default:
        return Text(property.valueDisplay);
    }
  }
}
