// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../service/editor/api_classes.dart';
import 'property_editor_controller.dart';

class PropertyEditorView extends StatelessWidget {
  const PropertyEditorView({required this.controller, super.key});

  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_PropertiesList(controller: controller)],
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
            ? const _ListItemPadding(
              child: Center(
                child: Text(
                  'No widget properties at the current cursor location.',
                ),
              ),
            )
            : Column(
              children:
                  args
                      .map(
                        (arg) => _EditablePropertyItem(
                          argument: arg,
                          controller: controller,
                        ),
                      )
                      .toList(),
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

  static const _hasArgIndicatorWidth = denseSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left:
              argument.hasArgument
                  ? BorderSide(
                    color: theme.colorScheme.primary,
                    width: _hasArgIndicatorWidth,
                  )
                  : BorderSide.none,
          bottom: defaultBorderSide(Theme.of(context)),
        ),
      ),
      child: _ListItemPadding(
        additionalPadding: EdgeInsets.only(
          left: argument.hasArgument ? noPadding : _hasArgIndicatorWidth,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(_PropertiesList.itemPadding),
                child: _PropertyInput(
                  argument: argument,
                  controller: controller,
                ),
              ),
            ),
            if (argument.hasArgument || argument.isDefault) ...[
              Flexible(child: _PropertyLabels(argument: argument)),
            ] else
              const Spacer(),
          ],
        ),
      ),
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
    final argument = widget.argument;
    final decoration = InputDecoration(
      helperText: '',
      errorText: argument.errorText,
      isDense: true,
      label: Text('${argument.name}${argument.isRequired ? '* ' : ''}'),
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

class _ListItemPadding extends StatelessWidget {
  const _ListItemPadding({
    required this.child,
    this.additionalPadding = const EdgeInsets.all(noPadding),
  });

  final Widget child;
  final EdgeInsets additionalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        additionalPadding.left + denseSpacing,
        additionalPadding.top + denseSpacing,
        additionalPadding.right +
            defaultSpacing, // Additional right padding for scroll bar.
        additionalPadding.bottom + noPadding,
      ),
      child: child,
    );
  }
}
