// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/editor/api_classes.dart';
import 'property_editor_controller.dart';
import 'property_editor_types.dart';

class BooleanInput extends StatelessWidget {
  const BooleanInput({
    super.key,
    required this.property,
    required this.editProperty,
  });

  final FiniteValuesProperty property;
  final EditArgumentFunction editProperty;

  @override
  Widget build(BuildContext context) {
    return _DropdownInput<Object>(
      property: property,
      editProperty: editProperty,
    );
  }
}

class DoubleInput extends StatelessWidget {
  const DoubleInput({
    super.key,
    required this.property,
    required this.editProperty,
  });

  final NumericProperty property;
  final EditArgumentFunction editProperty;

  @override
  Widget build(BuildContext context) {
    return _TextInput<double>(property: property, editProperty: editProperty);
  }
}

class EnumInput extends StatelessWidget {
  const EnumInput({
    super.key,
    required this.property,
    required this.editProperty,
  });

  final FiniteValuesProperty property;
  final EditArgumentFunction editProperty;

  @override
  Widget build(BuildContext context) {
    return _DropdownInput<String>(
      property: property,
      editProperty: editProperty,
    );
  }
}

class IntegerInput extends StatelessWidget {
  const IntegerInput({
    super.key,
    required this.property,
    required this.editProperty,
  });

  final NumericProperty property;
  final EditArgumentFunction editProperty;

  @override
  Widget build(BuildContext context) {
    return _TextInput<int>(property: property, editProperty: editProperty);
  }
}

class StringInput extends StatelessWidget {
  const StringInput({
    super.key,
    required this.property,
    required this.editProperty,
  });

  final EditableProperty property;
  final EditArgumentFunction editProperty;

  @override
  Widget build(BuildContext context) {
    return _TextInput<String>(property: property, editProperty: editProperty);
  }
}

class _DropdownInput<T> extends StatefulWidget {
  const _DropdownInput({
    super.key,
    required this.property,
    required this.editProperty,
  });

  final FiniteValuesProperty property;
  final EditArgumentFunction editProperty;

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
      selectedItemBuilder:
          (context) => _dropdownItems(withDefaultLabels: false),
      items: _dropdownItems(withDefaultLabels: true),
      onChanged: (newValue) async {
        if (newValue != widget.property.valueDisplay) {
          await editProperty(
            widget.property,
            valueAsString: newValue,
            editPropertyCallback: widget.editProperty,
          );
        }
      },
    );
  }

  List<DropdownMenuItem> _dropdownItems({required bool withDefaultLabels}) =>
      widget.property.propertyOptions.map((option) {
        return DropdownMenuItem(
          value: option.text,
          child: _DropdownContent(
            option: option,
            showDefaultLabel: withDefaultLabels,
          ),
        );
      }).toList();
}

class _DropdownContent extends StatelessWidget {
  const _DropdownContent({
    required this.option,
    required this.showDefaultLabel,
  });

  final PropertyOption option;
  final bool showDefaultLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            option.text,
            style: Theme.of(context).fixedFontStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showDefaultLabel && option.isDefault)
          const RoundedLabel(
            labelText: 'D',
            tooltipText: 'Matches the default value.',
          ),
      ],
    );
  }
}

class _TextInput<T> extends StatefulWidget {
  const _TextInput({
    super.key,
    required this.property,
    required this.editProperty,
  });

  final EditableProperty property;
  final EditArgumentFunction editProperty;

  @override
  State<_TextInput> createState() => _TextInputState<T>();
}

class _TextInputState<T> extends State<_TextInput<T>>
    with _PropertyInputMixin<_TextInput<T>, T>, AutoDisposeMixin {
  static const _paddingDiffComparedToDropdown = 1.0;

  late final FocusNode _focusNode;

  late String _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.property.valueDisplay;
    _focusNode = FocusNode(debugLabel: 'text-input-${widget.property.name}');

    addAutoDisposeListener(_focusNode, () async {
      if (_focusNode.hasFocus) return;
      // Edit property when clicking or tabbing away from input.
      await _editProperty();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      focusNode: _focusNode,
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
        padding: defaultSpacing - (_paddingDiffComparedToDropdown / 2),
      ),
      style: theme.fixedFontStyle,
      onChanged: (newValue) {
        clearServerError();
        setState(() {
          _currentValue = newValue;
        });
      },
      onEditingComplete: _editProperty,
    );
  }

  Future<void> _editProperty() async {
    await editProperty(
      widget.property,
      valueAsString: _currentValue,
      editPropertyCallback: widget.editProperty,
    );
  }
}

mixin _PropertyInputMixin<T extends StatefulWidget, U> on State<T> {
  String? _serverError;

  Future<void> editProperty(
    EditableProperty property, {
    required EditArgumentFunction editPropertyCallback,
    required String? valueAsString,
  }) async {
    // If no changes have been made to the property, don't send an edit request.
    if (property.valueDisplay == valueAsString) return;

    clearServerError();
    final argName = property.name;
    ga.select(
      gac.PropertyEditorSidebar.id,
      gac.PropertyEditorSidebar.applyEditRequest(
        argName: property.name,
        argType: property.type,
      ),
    );
    final editToNull = property.isNullable && property.isNully(valueAsString);
    final value =
        editToNull
            ? null
            : property.convertFromInputString(valueAsString) as U?;
    final response = await editPropertyCallback(name: argName, value: value);
    _handleServerResponse(response, property: property);
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

  void _handleServerResponse(
    EditArgumentResponse? errorResponse, {
    required EditableProperty property,
  }) {
    final succeeded = errorResponse == null || errorResponse.success;
    if (!succeeded) {
      setState(() {
        _serverError =
            '${errorResponse.errorType?.message ?? 'Encountered unknown error.'} (Property: ${property.name})';
      });
      ga.reportError('property-editor $_serverError');
    }
    ga.select(
      gac.PropertyEditorSidebar.id,
      gac.PropertyEditorSidebar.applyEditComplete(
        argName: property.name,
        argType: property.type,
        succeeded: succeeded,
      ),
    );
  }
}
