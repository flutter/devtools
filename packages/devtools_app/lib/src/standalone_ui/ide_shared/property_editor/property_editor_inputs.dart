// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'property_editor_controller.dart';
import 'property_editor_types.dart';

class BooleanInput extends StatelessWidget {
  const BooleanInput({
    super.key,
    required this.property,
    required this.controller,
  });

  final FiniteValuesProperty property;
  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    return _DropdownInput<Object>(property: property, controller: controller);
  }
}

class DoubleInput extends StatelessWidget {
  const DoubleInput({
    super.key,
    required this.property,
    required this.controller,
  });

  final NumericProperty property;
  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    return _TextInput<double>(property: property, controller: controller);
  }
}

class EnumInput extends StatelessWidget {
  const EnumInput({
    super.key,
    required this.property,
    required this.controller,
  });

  final FiniteValuesProperty property;
  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    return _DropdownInput<String>(property: property, controller: controller);
  }
}

class IntegerInput extends StatelessWidget {
  const IntegerInput({
    super.key,
    required this.property,
    required this.controller,
  });

  final NumericProperty property;
  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    return _TextInput<int>(property: property, controller: controller);
  }
}

class StringInput extends StatelessWidget {
  const StringInput({
    super.key,
    required this.property,
    required this.controller,
  });

  final EditableProperty property;
  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    return _TextInput<String>(property: property, controller: controller);
  }
}

class _DropdownInput<T> extends StatelessWidget with _PropertyInputMixin<T> {
  _DropdownInput({super.key, required this.property, required this.controller});

  final FiniteValuesProperty property;
  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField(
      value: property.valueDisplay,
      decoration: decoration(property, theme: theme, padding: denseSpacing),
      isExpanded: true,
      items:
          property.propertyOptions.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option, style: theme.fixedFontStyle),
            );
          }).toList(),
      onChanged: (newValue) async {
        await editProperty(
          property,
          valueAsString: newValue,
          controller: controller,
        );
      },
    );
  }
}

class _TextInput<T> extends StatefulWidget with _PropertyInputMixin<T> {
  _TextInput({super.key, required this.property, required this.controller});

  final EditableProperty property;
  final PropertyEditorController controller;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  String currentValue = '';

  double paddingDiffComparedToDropdown = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      initialValue: widget.property.valueDisplay,
      enabled: widget.property.isEditable,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: widget.property.inputValidator,
      inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
      decoration: widget.decoration(
        widget.property,
        theme: theme,
        // Note: The text input has an extra pixel compared to the dropdown
        // input. Therefore, to have their sizes match, subtract a half pixel
        // from the padding.
        padding: defaultSpacing - (paddingDiffComparedToDropdown / 2),
      ),
      style: theme.fixedFontStyle,
      onChanged: (newValue) {
        setState(() {
          currentValue = newValue;
        });
      },
      onEditingComplete: _editProperty,
      onTapOutside: (_) async {
        await _editProperty();
      },
    );
  }

  Future<void> _editProperty() async {
    await widget.editProperty(
      widget.property,
      valueAsString: currentValue,
      controller: widget.controller,
    );
  }
}

mixin _PropertyInputMixin<T> {
  Future<void> editProperty(
    EditableProperty property, {
    required PropertyEditorController controller,
    required String? valueAsString,
  }) async {
    final argName = property.name;

    // Can edit values to null.
    if (property.isNullable && property.isNully(valueAsString)) {
      await controller.editArgument(name: argName, value: null);
      return;
    }

    final value = property.convertFromInputString(valueAsString) as T?;
    await controller.editArgument(name: argName, value: value);
  }

  InputDecoration decoration(
    EditableProperty property, {
    required ThemeData theme,
    required double padding,
  }) {
    return InputDecoration(
      contentPadding: EdgeInsets.all(padding),
      helperText: property.isRequired ? '*required' : '',
      errorText: property.errorText,
      isDense: true,
      label: inputLabel(property, theme: theme),
      border: const OutlineInputBorder(),
    );
  }

  Widget inputLabel(EditableProperty property, {required ThemeData theme}) {
    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        text: '${property.displayType} ',
        style: theme.fixedFontStyle,
        children: [
          TextSpan(
            text: property.name,
            style: theme.fixedFontStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            children: [
              TextSpan(
                text: property.isRequired ? '*' : '',
                style: theme.fixedFontStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
