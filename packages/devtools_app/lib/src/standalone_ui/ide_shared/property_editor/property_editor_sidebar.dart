// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/primitives/utils.dart';

class PropertyEditorSidebar extends StatelessWidget {
  const PropertyEditorSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Property Editor', style: Theme.of(context).textTheme.titleMedium),
        const PaddedDivider.noPadding(),
        const _PropertiesList(),
      ],
    );
  }
}

class _PropertiesList extends StatelessWidget {
  const _PropertiesList();

  static const itemPadding = densePadding;

  @override
  Widget build(BuildContext context) {
    // TODO(https://github.com/flutter/devtools/issues/8546) Switch to scrollable
    // ListView when this has been moved into its own panel.
    return Column(
      children: [
        for (final property in _properties)
          ...<Widget>[
            _EditablePropertyItem(property: property),
          ].joinWith(const PaddedDivider.noPadding()),
      ],
    );
  }
}

class _EditablePropertyItem extends StatelessWidget {
  const _EditablePropertyItem({required this.property});

  final _WidgetProperty property;

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

  final _WidgetProperty property;

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

  final _WidgetProperty property;

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
            property.type == 'bool' ? ['true', 'false'] : property.options;
        return DropdownButtonFormField(
          value: property.valueDisplay,
          decoration: decoration,
          items:
              (options ?? []).map((option) {
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

class _WidgetProperty {
  const _WidgetProperty({
    required this.name,
    required this.type,
    required this.isNullable,
    this.value,
    this.displayValue,
    this.isEditable = true,
    this.isRequired = false,
    this.hasArgument = true,
    this.isDefault = false,
    this.errorText,
    this.options,
    // ignore: unused_element, TODO(https://github.com/flutter/devtools/issues/8532): Support colors.
    this.swatches,
    // ignore: unused_element, TODO(https://github.com/flutter/devtools/issues/8532): Support objects.
    this.properties,
  });

  final String name;
  final String type;
  final bool isNullable;
  final Object? value;
  final String? displayValue;
  final bool isEditable;
  final bool isRequired;
  final bool hasArgument;
  final bool isDefault;
  final String? errorText;
  final List<String>? options;
  final List<String>? swatches;
  final List<_WidgetProperty>? properties;

  String get valueDisplay => displayValue ?? value.toString();
}

// TODO(https://github.com/flutter/devtools/issues/8531): Connect to DTD and delete hard-coded properties.
const _titleProperty = _WidgetProperty(
  name: 'title',
  value: 'Hello world!',
  type: 'string',
  isNullable: false,
  isRequired: true,
  hasArgument: false,
);

const _widthProperty = _WidgetProperty(
  name: 'width',
  displayValue: '100.0',
  type: 'double',
  isEditable: false,
  errorText: 'Some reason for why this can\'t be edited.',
  isNullable: false,
  value: 20.0,
  isRequired: true,
  hasArgument: false,
);

const _heightProperty = _WidgetProperty(
  name: 'height',
  type: 'double',
  isNullable: false,
  value: 20.0,
  isDefault: true,
  isRequired: true,
);

const _softWrapProperty = _WidgetProperty(
  name: 'softWrap',
  type: 'bool',
  isNullable: false,
  value: true,
  isDefault: true,
);

const _alignProperty = _WidgetProperty(
  name: 'align',
  type: 'enum',
  isNullable: false,
  value: 'Alignment.center',
  options: [
    'Alignment.bottomCenter',
    'Alignment.bottomLeft',
    'Alignment.bottomRight',
    'Alignment.center',
    'Alignment.centerLeft',
    'Alignment.centerRight',
    'Alignment.topCenter',
    'Alignment.topLeft',
    'Alignment.topRight',
  ],
);

const _properties = [
  _titleProperty,
  _widthProperty,
  _heightProperty,
  _alignProperty,
  _softWrapProperty,
];
