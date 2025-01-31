// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/utils.dart';
import 'package:meta/meta.dart';

import '../../../shared/editor/api_classes.dart';

class EditableString extends EditableProperty {
  EditableString(super.argument);

  @override
  String? convertFromInputString(String? valueAsString) => valueAsString;

  @override
  String get dartType => 'String';

  @override
  bool isNully(String? inputValue) {
    return inputValue == null || inputValue == 'null';
  }
}

class EditableBool extends EditableProperty with FiniteValuesProperty {
  EditableBool(super.argument);

  @override
  Object? convertFromInputString(String? valueAsString) =>
      valueAsString == 'true' || valueAsString == 'false'
          ? valueAsString == 'true'
          : valueAsString; // The boolean value might be an expression.

  @override
  Set<String> get propertyOptions {
    return {'true', 'false', valueDisplay, if (isNullable) 'null'};
  }
}

class EditableDouble extends EditableProperty with NumericProperty {
  EditableDouble(super.argument);

  @override
  double? convertFromInputString(String? valueAsString) =>
      toNumber(valueAsString) as double?;
}

class EditableInt extends EditableProperty with NumericProperty {
  EditableInt(super.argument);

  @override
  int? convertFromInputString(String? valueAsString) =>
      toNumber(valueAsString) as int?;
}

class EditableEnum extends EditableProperty with FiniteValuesProperty {
  EditableEnum(super.argument);

  @override
  String? convertFromInputString(String? valueAsString) =>
      valueAsString == null ? null : _enumLonghand(valueAsString);

  @override
  String get dartType => options?.first.split('.').first ?? type;

  @override
  String get valueDisplay => _enumShorthand(displayValue ?? value.toString());

  @override
  Set<String> get propertyOptions {
    final shorthandOptions = (options ?? <String>[]).map(_enumShorthand);
    return {...shorthandOptions, valueDisplay, if (isNullable) 'null'};
  }

  String _enumShorthand(String fullEnumValue) {
    if (fullEnumValue.startsWith(dartType)) {
      return fullEnumValue.split(dartType).last;
    }
    return fullEnumValue;
  }

  String _enumLonghand(String enumShorthandValue) {
    if (enumShorthandValue.startsWith('.')) {
      return '$dartType$enumShorthandValue';
    }
    return enumShorthandValue;
  }
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

  String get dartType => type;

  String get displayType => isNullable ? '$dartType?' : dartType;

  String get typeError => 'Please enter ${addIndefiniteArticle(dartType)}.';

  String? inputValidator(String? _) {
    return null;
  }

  bool isNully(String? inputValue) {
    final isNull = inputValue == null || inputValue == 'null';
    final isEmpty = inputValue == '';
    return isNull || isEmpty;
  }

  @mustBeOverridden
  Object? convertFromInputString(String? _) {
    throw UnimplementedError();
  }
}

mixin NumericProperty on EditableProperty {
  @override
  String? inputValidator(String? inputValue) {
    // Permit sending null values with an empty input or with explicit "null".
    if (isNullable && isNully(inputValue)) {
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

mixin FiniteValuesProperty on EditableProperty {
  Set<String> get propertyOptions;
}

EditableProperty? argToProperty(EditableArgument argument) {
  switch (argument.type) {
    case boolType:
      return EditableBool(argument);
    case doubleType:
      return EditableDouble(argument);
    case enumType:
      return EditableEnum(argument);
    case intType:
      return EditableInt(argument);
    case stringType:
      return EditableString(argument);
    default:
      return null;
  }
}

/// The following types should match those returned by the Analysis Server. See:
/// https://github.com/dart-lang/sdk/blob/154b473cdb65c2686bb44fedec03ba2deddb80fd/pkg/analysis_server/lib/src/lsp/handlers/custom/editable_arguments/handler_editable_arguments.dart#L182
const stringType = 'string';
const doubleType = 'double';
const intType = 'int';
const boolType = 'bool';
const enumType = 'enum';
