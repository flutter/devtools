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
              child: Text(
                'No widget properties at the current cursor location.',
              ),
            )
            : Column(
              children: <Widget>[
                ...args.map(
                  (arg) => _EditablePropertyItem(
                    argument: arg,
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
    required this.argument,
    required this.controller,
  });

  final EditableArgument argument;
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
            child: _PropertyInput(argument: argument, controller: controller),
          ),
        ),
        if (argument.isRequired || argument.isDefault) ...[
          Flexible(child: _PropertyLabels(argument: argument)),
        ] else
          const Spacer(),
      ],
    );
  }
}

class _PropertyLabels extends StatelessWidget {
  const _PropertyLabels({required this.argument});

  final EditableArgument argument;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRequired = argument.isRequired;
    final isDefault = argument.isDefault;

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

class _PropertyInput extends StatefulWidget {
  const _PropertyInput({required this.argument, required this.controller});

  final EditableArgument argument;
  final PropertyEditorController controller;

  @override
  State<_PropertyInput> createState() => _PropertyInputState();
}

class _PropertyInputState extends State<_PropertyInput> {
  String get typeError => 'Please enter a ${widget.argument.type}.';

  String currentValue = '';

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      helperText: '',
      errorText: widget.argument.errorText,
      isDense: true,
      label: Text(widget.argument.name),
      border: const OutlineInputBorder(),
    );

    switch (widget.argument.type) {
      case 'enum':
      case 'bool':
        final options =
            widget.argument.type == 'bool'
                ? ['true', 'false']
                : (widget.argument.options ?? <String>[]);
        options.add(widget.argument.valueDisplay);
        if (widget.argument.isNullable) {
          options.add('null');
        }

        return DropdownButtonFormField(
          value: widget.argument.valueDisplay,
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
          onChanged: (newValue) async {
            await _editArgument(newValue);
          },
        );
      case 'double':
      case 'int':
      case 'string':
        return TextFormField(
          initialValue: widget.argument.valueDisplay,
          enabled: widget.argument.isEditable,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _inputValidator,
          inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
          decoration: decoration,
          style: Theme.of(context).fixedFontStyle,
          // TODO(https://github.com/flutter/devtools/issues/8531) Handle onChanged.
          onChanged: (newValue) {
            currentValue = newValue;
          },
          onEditingComplete: () async {
            await _editArgument(currentValue);
          },
          onTapOutside: (_) async {
            await _editArgument(currentValue);
          },
        );
      default:
        return Text(widget.argument.valueDisplay);
    }
  }

  Future<void> _editArgument(String? valueAsString) async {
    final argName = widget.argument.name;

    // Can edit values to null.
    if (widget.argument.isNullable && valueAsString == null ||
        (valueAsString == '' && widget.argument.type != 'string')) {
      await widget.controller.editArgument(name: argName, value: null);
      return;
    }

    switch (widget.argument.type) {
      case 'string':
      case 'enum':
        await widget.controller.editArgument(
          name: argName,
          value: valueAsString,
        );
        break;
      case 'bool':
        await widget.controller.editArgument(
          name: argName,
          value:
              valueAsString == 'true' || valueAsString == 'false'
                  ? valueAsString == 'true'
                  : valueAsString, // The boolean value might be an expression.
        );
        break;
      case 'double':
        final numValue = _toNumber(valueAsString);
        if (numValue != null) {
          await widget.controller.editArgument(
            name: argName,
            value: numValue as double,
          );
        }
        break;
      case 'int':
        final numValue = _toNumber(valueAsString);
        if (numValue != null) {
          await widget.controller.editArgument(
            name: argName,
            value: numValue as int,
          );
        }
        break;
    }
  }

  String? _inputValidator(String? inputValue) {
    final numValue = _toNumber(inputValue);
    if (numValue == null) {
      return typeError;
    }
    return null;
  }

  Object? _toNumber(String? valueAsString) {
    if (valueAsString == null || valueAsString == '') return null;

    final isDouble = widget.argument.type == 'double';
    final isInt = widget.argument.type == 'int';
    // Only try to convert numeric types.
    if (!isDouble && !isInt) {
      return null;
    }

    return isInt ? int.tryParse(valueAsString) : double.tryParse(valueAsString);
  }
}
