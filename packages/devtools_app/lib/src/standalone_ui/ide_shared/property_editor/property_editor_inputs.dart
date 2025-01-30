// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/editor/api_classes.dart';
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

class _DropdownInput<T> extends StatefulWidget {
  const _DropdownInput({
    super.key,
    required this.property,
    required this.controller,
  });

  final FiniteValuesProperty property;
  final PropertyEditorController controller;

  @override
  State<_DropdownInput<T>> createState() => _DropdownInputState<T>();
}

class _DropdownInputState<T> extends State<_DropdownInput<T>>
    with _PropertyInputMixin<_DropdownInput<T>, T> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField(
      value: widget.property.valueDisplay,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (text) => inputValidator(text, property: widget.property),
      decoration: decoration(
        widget.property,
        theme: theme,
        padding: denseSpacing,
      ),
      isExpanded: true,
      items:
          widget.property.propertyOptions.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option, style: theme.fixedFontStyle),
            );
          }).toList(),
      onChanged: (newValue) async {
        await editProperty(
          widget.property,
          valueAsString: newValue,
          controller: widget.controller,
        );
      },
    );
  }
}

class _TextInput<T> extends StatefulWidget {
  const _TextInput({
    super.key,
    required this.property,
    required this.controller,
  });

  final EditableProperty property;
  final PropertyEditorController controller;

  @override
  State<_TextInput> createState() => _TextInputState<T>();
}

class _TextInputState<T> extends State<_TextInput<T>>
    with _PropertyInputMixin<_TextInput<T>, T> {
  String currentValue = '';

  double paddingDiffComparedToDropdown = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      initialValue: widget.property.valueDisplay,
      enabled: widget.property.isEditable,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (text) => inputValidator(text, property: widget.property),
      inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
      decoration: decoration(
        widget.property,
        theme: theme,
        // Note: The text input has an extra pixel compared to the dropdown
        // input. Therefore, to have their sizes match, subtract a half pixel
        // from the padding.
        padding: defaultSpacing - (paddingDiffComparedToDropdown / 2),
      ),
      style: theme.fixedFontStyle,
      onChanged: (newValue) {
        clearServerError();
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
    await editProperty(
      widget.property,
      valueAsString: currentValue,
      controller: widget.controller,
    );
  }
}

mixin _PropertyInputMixin<T extends StatefulWidget, U> on State<T> {
  String? _serverError;

  Future<void> editProperty(
    EditableProperty property, {
    required PropertyEditorController controller,
    required String? valueAsString,
  }) async {
    clearServerError();
    final argName = property.name;

    // Can edit values to null.
    if (property.isNullable && property.isNully(valueAsString)) {
      await controller.editArgument(name: argName, value: null);
      return;
    }

    final value = property.convertFromInputString(valueAsString) as U?;
    final response = await controller.editArgument(name: argName, value: value);
    _maybeHandleServerError(response, property: property);
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
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
  }

  Widget inputLabel(EditableProperty property, {required ThemeData theme}) {
    // Flutter scales down the label font size by 75%, therefore we need to
    // increase the size to make it glegible.
    final fixedFontStyle = theme.fixedFontStyle.copyWith(
      fontSize: defaultFontSize + 1,
    );
    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        text: '${property.displayType} ',
        style: fixedFontStyle,
        children: [
          TextSpan(
            text: property.name,
            style: fixedFontStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            children: [
              TextSpan(
                text: property.isRequired ? '*' : '',
                style: fixedFontStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? inputValidator(String? input, {required EditableProperty property}) {
    if (_serverError != null) return _serverError;
    return property.inputValidator(input);
  }

  void clearServerError() {
    setState(() {
      _serverError = null;
    });
  }

  void _maybeHandleServerError(
    EditArgumentResponse? errorResponse, {
    required EditableProperty property,
  }) {
    if (errorResponse == null || errorResponse.success) return;
    setState(() {
      _serverError =
          '${errorResponse.errorType?.message ?? 'Encountered unknown error.'} (Property: ${property.name})';
    });
  }
}
