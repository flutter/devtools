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
                      .map((arg) => _EditablePropertyItem(argument: arg))
                      .toList(),
            );
      },
    );
  }
}

class _EditablePropertyItem extends StatelessWidget {
  const _EditablePropertyItem({required this.argument});

  final EditableArgument argument;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color:
            argument.hasArgument
                ? theme.colorScheme.emphasizedRowBackgroundColor
                : theme.colorScheme.deemphasizedRowBackgroundColor,
        border: Border(bottom: defaultBorderSide(Theme.of(context))),
      ),
      child: _ListItemPadding(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(_PropertiesList.itemPadding),
                child: _PropertyInput(argument: argument),
              ),
            ),
            if (argument.isRequired || argument.isDefault) ...[
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

class _PropertyInput extends StatelessWidget {
  const _PropertyInput({required this.argument});

  final EditableArgument argument;

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      helperText: '',
      errorText: argument.errorText,
      isDense: true,
      label: Text(argument.name),
      border: const OutlineInputBorder(),
    );

    switch (argument.type) {
      case 'enum':
      case 'bool':
        final options =
            argument.type == 'bool'
                ? ['true', 'false']
                : (argument.options ?? <String>[]);
        options.add(argument.valueDisplay);
        if (argument.isNullable) {
          options.add('null');
        }

        return DropdownButtonFormField(
          value: argument.valueDisplay,
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
          onChanged: (_) {},
        );
      case 'double':
      case 'int':
      case 'string':
        return TextFormField(
          initialValue: argument.valueDisplay,
          enabled: argument.isEditable,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _inputValidator,
          inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
          decoration: decoration,
          style: Theme.of(context).fixedFontStyle,
          // TODO(https://github.com/flutter/devtools/issues/8531) Handle onChanged.
          onChanged: (_) {},
        );
      default:
        return Text(argument.valueDisplay);
    }
  }

  String? _inputValidator(String? inputValue) {
    final isDouble = argument.type == 'double';
    final isInt = argument.type == 'int';

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

class _ListItemPadding extends StatelessWidget {
  const _ListItemPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        denseSpacing,
        denseSpacing,
        defaultSpacing, // Additional right padding for scroll bar.
        noPadding,
      ),
      child: child,
    );
  }
}
