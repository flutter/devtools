// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/editor/api_classes.dart';
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
        // TODO(elliette): Include widget name and documentation.
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
    final property = _getEditableProperty(argument);
    if (property == null) return const SizedBox.shrink();

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
        if (argument.hasArgument || argument.isDefault) ...[
          Flexible(child: _PropertyLabels(argument: argument)),
        ] else
          const Spacer(),
      ],
    );
  }

  EditableProperty? _getEditableProperty(EditableArgument argument) {
    switch (argument.type) {
      case 'enum':
        return EditableEnum(argument);
      case 'bool':
        return EditableBool(argument);
      case 'double':
        return EditableDouble(argument);
      case 'int':
        return EditableInt(argument);
      case 'string':
        return EditableString(argument);
      default:
        return null;
    }
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

class _PropertyInput extends StatelessWidget {
  const _PropertyInput({required this.property, required this.controller});

  final EditableProperty property;
  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    final argType = property.type;
    switch (argType) {
      case 'enum':
        return EnumInput(property: property, controller: controller);
      case 'bool':
        return BooleanInput(property: property, controller: controller);
      case 'double':
        return DoubleInput(
          property: property as NumericProperty,
          controller: controller,
        );
      case 'int':
        return IntegerInput(
          property: property as NumericProperty,
          controller: controller,
        );
      case 'string':
        return StringInput(property: property, controller: controller);
      default:
        return Text(property.valueDisplay);
    }
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
    return TextInput<double>(
      property: property,
      controller: controller,
      convertValueFromString:
          (valueAsString) => property.toNumber(valueAsString) as double?,
    );
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
    return TextInput<int>(
      property: property,
      controller: controller,
      convertValueFromString:
          (valueAsString) => property.toNumber(valueAsString) as int?,
    );
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
    return TextInput<int>(
      property: property,
      controller: controller,
      convertValueFromString: (valueAsString) => valueAsString,
    );
  }
}

class EnumInput extends StatelessWidget {
  const EnumInput({
    super.key,
    required this.property,
    required this.controller,
  });

  final EditableProperty property;
  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    return DropdownInput<String>(
      property: property,
      controller: controller,
      convertValueFromString: (valueAsString) => valueAsString,
    );
  }
}

class BooleanInput extends StatelessWidget {
  const BooleanInput({
    super.key,
    required this.property,
    required this.controller,
  });

  final EditableProperty property;
  final PropertyEditorController controller;

  @override
  Widget build(BuildContext context) {
    return DropdownInput<dynamic>(
      property: property,
      controller: controller,
      convertValueFromString:
          (valueAsString) =>
              valueAsString == 'true' || valueAsString == 'false'
                  ? valueAsString == 'true'
                  : valueAsString, // The boolean value might be an expression.
    );
  }
}

class DropdownInput<T> extends StatelessWidget with PropertyInputMixin {
  DropdownInput({
    super.key,
    required this.property,
    required this.controller,
    required this.convertValueFromString,
  });

  final EditableProperty property;
  final PropertyEditorController controller;

  @override
  final ValueFromStringFn convertValueFromString;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final argType = property.type;

    // TODO: pull these out.
    final options =
        argType == 'bool'
            ? ['true', 'false']
            : (property.options ?? <String>[]);
    options.add(property.valueDisplay);
    if (property.isNullable) {
      options.add('null');
    }

    return DropdownButtonFormField(
      value: property.valueDisplay,
      decoration: decoration(property, theme: Theme.of(context)),
      isExpanded: true,
      items:
          options.toSet().toList().map((option) {
            return DropdownMenuItem(
              value: option,
              // TODO(https://github.com/flutter/devtools/issues/8531) Handle onTap.
              onTap: () {},
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

class TextInput<T> extends StatefulWidget with PropertyInputMixin {
  TextInput({
    super.key,
    required this.property,
    required this.controller,
    required this.convertValueFromString,
  });

  final EditableProperty property;
  final PropertyEditorController controller;

  @override
  final ValueFromStringFn convertValueFromString;

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  String currentValue = '';

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: widget.property.valueDisplay,
      enabled: widget.property.isEditable,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: widget.property.inputValidator,
      inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
      decoration: widget.decoration(widget.property, theme: Theme.of(context)),
      style: Theme.of(context).fixedFontStyle,
      onChanged: (newValue) {
        currentValue = newValue;
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

class EditableBool extends EditableProperty {
  EditableBool(super.argument);

  @override
  String get dartType => type;
}

class EditableDouble extends EditableProperty with NumericProperty {
  EditableDouble(super.argument);

  @override
  String get dartType => type;
}

class EditableInt extends EditableProperty {
  EditableInt(super.argument);

  @override
  String get dartType => type;
}

class EditableString extends EditableProperty {
  EditableString(super.argument);

  @override
  String get dartType => 'String';
}

class EditableEnum extends EditableProperty {
  EditableEnum(super.argument);

  @override
  String get dartType => options?.first.split('.').first ?? type;
}

class EditableProperty extends EditableArgument {
  EditableProperty(EditableArgument argument)
    : super(
        name: argument.name,
        type: argument.type,
        value: argument.value,
        hasArgument: argument.hasArgument,
        isDefault: argument.isDefault,
        isNullable: argument.isNullable,
        isRequired: argument.isRequired,
        isEditable: argument.isEditable,
        options: argument.options,
        displayValue: argument.displayValue,
        errorText: argument.errorText,
      );

  FormFieldValidator<String>? validator;

  String get dartType => type;

  String get displayType => isNullable ? '$dartType?' : dartType;

  String get typeError => 'Please enter ${addIndefiniteArticle(dartType)}.';

  String? inputValidator(String? inputValue) {
    return null;
  }
}

mixin NumericProperty on EditableProperty {
  @override
  String? inputValidator(String? inputValue) {
    // Permit sending null values with an empty input or with explicit "null".
    final isNull = (inputValue ?? '').isEmpty || inputValue == 'null';
    if (isNullable && isNull) {
      return null;
    }
    final numValue = toNumber(inputValue);
    if (numValue == null) {
      return typeError;
    }
    return null;
  }

  Object? toNumber(String? valueAsString) {
    if (valueAsString == null || valueAsString == '') return null;
    final isInt = type == 'int';
    return isInt ? int.tryParse(valueAsString) : double.tryParse(valueAsString);
  }
}

typedef ValueFromStringFn<T> = T? Function(String);

mixin PropertyInputMixin {
  ValueFromStringFn get convertValueFromString;

  Future<void> editProperty(
    EditableProperty property, {
    required PropertyEditorController controller,
    required String? valueAsString,
  }) async {
    final argName = property.name;

    // Can edit values to null.
    final valueIsNull = valueAsString == null || valueAsString == 'null';
    // TODO: consider pulling the following logic out of here.
    final valueIsEmpty = property.type != 'string' && valueAsString == '';
    if (property.isNullable && (valueIsNull || valueIsEmpty)) {
      await controller.editArgument(name: argName, value: null);
      return;
    }

    final value = convertValueFromString(valueAsString!);
    await controller.editArgument(name: argName, value: value);
  }

  InputDecoration decoration(
    EditableProperty property, {
    required ThemeData theme,
  }) {
    return InputDecoration(
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
