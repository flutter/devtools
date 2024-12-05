// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../service/editor/api_classes.dart';
import '../../../shared/primitives/utils.dart';
import 'property_editor_controller.dart';

class PropertyEditorView extends StatelessWidget {
  const PropertyEditorView({required this.controller, super.key});

  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Property Editor', style: Theme.of(context).textTheme.titleMedium),
        const PaddedDivider.noPadding(),
        _PropertiesList(controller: controller),
      ],
    );
  }
}

class _PropertiesList extends StatelessWidget {
  const _PropertiesList({required this.controller});

  final PropertyEditorController controller;

  static const itemPadding = densePadding;
  @override
  Widget build(BuildContext context) {
    // TODO(https://github.com/flutter/devtools/issues/8546) Switch to scrollable
    // ListView when this has been moved into its own panel.
    return ValueListenableBuilder<List<EditableArgument>>(
      valueListenable: controller.editableArgs,
      builder: (context, args, _) {
        return args.isEmpty
            ? const Center(
              child: Text('No widget properties at current cursor location.'),
            )
            : Column(
              children: [
                for (final property in args)
                  ...<Widget>[
                    _EditablePropertyItem(property: property),
                  ].joinWith(const PaddedDivider.noPadding()),
              ],
            );
      },
    );
  }
}

class _EditablePropertyItem extends StatelessWidget {
  const _EditablePropertyItem({required this.property});

  final EditableArgument property;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(_PropertiesList.itemPadding),
            child: _PropertyInput(property: property),
          ),
        ),
        if (property.isRequired || property.isDefault) ...[
          Flexible(child: _PropertyLabels(property: property)),
        ] else
          const Spacer(),
      ],
    );
  }
}

class _PropertyLabels extends StatelessWidget {
  const _PropertyLabels({required this.property});

  final EditableArgument property;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRequired = property.isRequired;
    final isDefault = property.isDefault;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRequired)
          Padding(
            padding: const EdgeInsets.all(_PropertiesList.itemPadding),
            child: RoundedLabel(
              labelText: 'required',
              backgroundColor: colorScheme.primary,
              textColor: colorScheme.onPrimary,
            ),
          ),
        if (isDefault)
          const Padding(
            padding: EdgeInsets.all(_PropertiesList.itemPadding),
            child: RoundedLabel(labelText: 'default'),
          ),
      ],
    );
  }
}

class _PropertyInput extends StatelessWidget {
  const _PropertyInput({required this.property});

  final EditableArgument property;

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      helperText: '',
      errorText: property.errorText,
      isDense: true,
      label: Text(property.name),
      border: const OutlineInputBorder(),
    );

    switch (property.type) {
      case 'enum':
      case 'bool':
        final options =
            property.type == 'bool'
                ? ['true', 'false']
                : (property.options ?? <String>[]);
        options.add(property.valueDisplay);
        if (property.isNullable) {
          options.add('null');
        }

        return DropdownButtonFormField(
          value: property.valueDisplay,
          decoration: decoration,
          items:
              options.toSet().toList().map((option) {
                return DropdownMenuItem(
                  value: option,
                  // TODO(https://github.com/flutter/devtools/issues/8531) Handle onTap.
                  onTap: () {},
                  child: Text(option),
                );
              }).toList(),
          onChanged: (_) {},
        );
      case 'double':
      case 'int':
      case 'string':
        return TextFormField(
          initialValue: property.valueDisplay,
          enabled: property.isEditable,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _inputValidator,
          inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
          decoration: decoration,
          style: Theme.of(context).fixedFontStyle,
          // TODO(https://github.com/flutter/devtools/issues/8531) Handle onChanged.
          onChanged: (_) {},
        );
      default:
        return Text(property.valueDisplay);
    }
  }

  String? _inputValidator(String? inputValue) {
    final isDouble = property.type == 'double';
    final isInt = property.type == 'int';

    // Only validate numeric types.
    if (!isDouble && !isInt) {
      return null;
    }

    final validationMessage =
        'Please enter ${isInt ? 'an integer' : 'a double'}.';
    if (inputValue == null || inputValue == '') {
      return validationMessage;
    }
    final numValue =
        isInt ? int.tryParse(inputValue) : double.tryParse(inputValue);
    if (numValue == null) {
      return validationMessage;
    }
    return null;
  }
}
