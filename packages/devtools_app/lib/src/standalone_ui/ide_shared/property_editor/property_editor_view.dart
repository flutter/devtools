// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/editor/api_classes.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/ui/common_widgets.dart';
import 'property_editor_controller.dart';

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
        if (argument.hasArgument || argument.isDefault) ...[
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
    final isSet = argument.hasArgument;
    final isDefault = argument.isDefault;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSet)
          Padding(
            padding: const EdgeInsets.all(_PropertiesList.itemPadding),
            child: RoundedLabel(
              labelText: 'set',
              backgroundColor: colorScheme.primary,
              textColor: colorScheme.onPrimary,
              tooltipText: 'Property argument is set.',
            ),
          ),
        if (isDefault)
          const Padding(
            padding: EdgeInsets.all(_PropertiesList.itemPadding),
            child: RoundedLabel(
              labelText: 'default',
              tooltipText: 'Property argument matches the default value.',
            ),
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
  String get typeError =>
      'Please enter ${addIndefiniteArticle(widget.argument.type)}.';

  String currentValue = '';

  @override
  Widget build(BuildContext context) {
    final argument = widget.argument;
    final decoration = InputDecoration(
      helperText: argument.isRequired ? '*required' : '',
      errorText: argument.errorText,
      isDense: true,
      label: Text('${argument.name}${argument.isRequired ? '*' : ''}'),
      border: const OutlineInputBorder(),
    );
    final argType = widget.argument.type;
    switch (argType) {
      case 'enum':
      case 'bool':
        final options =
            argType == 'bool'
                ? ['true', 'false']
                : (widget.argument.options ?? <String>[]);
        options.add(widget.argument.valueDisplay);
        if (widget.argument.isNullable) {
          options.add('null');
        }

        return DropdownButtonFormField(
          value: widget.argument.valueDisplay,
          decoration: decoration,
          isExpanded: true,
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
        final isNumeric = argType == 'double' || argType == 'int';
        return TextFormField(
          initialValue: widget.argument.valueDisplay,
          enabled: widget.argument.isEditable,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: isNumeric ? _numericInputValidator : null,
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
    final valueIsNull = valueAsString == null || valueAsString == 'null';
    final valueIsEmpty =
        widget.argument.type != 'string' && valueAsString == '';
    if (widget.argument.isNullable && (valueIsNull || valueIsEmpty)) {
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

  String? _numericInputValidator(String? inputValue) {
    // Permit sending null values with an empty input or with explicit "null".
    final isNull = (inputValue ?? '').isEmpty || inputValue == 'null';
    if (widget.argument.isNullable && isNull) {
      return null;
    }
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
