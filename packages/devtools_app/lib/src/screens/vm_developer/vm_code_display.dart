// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';
import '../../shared/theme.dart';
import 'vm_object_model.dart';
import 'vm_service_private_extensions.dart';

// TODO(bkonyi): remove once profile ticks are populated for instructions.
const profilerTicksEnabled = false;

abstract class _CodeColumnData extends ColumnData<Instruction> {
  _CodeColumnData(super.title, {required super.fixedWidthPx});
  _CodeColumnData.wide(super.title) : super.wide();

  @override
  bool get supportsSorting => false;
}

class _AddressColumn extends _CodeColumnData {
  _AddressColumn()
      : super(
          'Address',
          fixedWidthPx: 160,
        );

  @override
  int getValue(Instruction dataObject) {
    return int.parse(dataObject.address, radix: 16);
  }

  @override
  String getDisplayValue(Instruction dataObject) {
    final value = getValue(dataObject);
    return '0x${value.toRadixString(16).toUpperCase().padLeft(8)}';
  }
}

class _ProfileTicksColumn extends _CodeColumnData {
  _ProfileTicksColumn(super.title) : super(fixedWidthPx: 80);

  @override
  Object? getValue(Instruction dataObject) {
    return '';
  }
}

class _InstructionColumn extends _CodeColumnData
    implements ColumnRenderer<Instruction> {
  _InstructionColumn()
      : super(
          'Disassembly',
          fixedWidthPx: 240,
        );

  @override
  Object? getValue(Instruction dataObject) {
    return dataObject.instruction;
  }

  @override
  Widget build(
    BuildContext context,
    Instruction data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return Text.rich(
      style: theme.fixedFontStyle,
      _highlightAssemblyCode(
        context,
        data.instruction,
      ),
    );
  }

  String _getLastMatch(StringScanner scanner) {
    final match = scanner.lastMatch!;
    return scanner.substring(match.start, match.end);
  }

  TextSpan _buildInstructionSpanRegExp(
    ColorScheme colorScheme,
    StringScanner scanner,
  ) {
    return TextSpan(
      text: _getLastMatch(scanner),
      style: TextStyle(
        color: colorScheme.controlFlowSyntaxColor,
      ),
    );
  }

  TextSpan _buildRegisterSpan(ColorScheme colorScheme, StringScanner scanner) {
    return TextSpan(
      text: _getLastMatch(scanner),
      style: TextStyle(
        color: colorScheme.variableSyntaxColor,
      ),
    );
  }

  TextSpan _buildNumericSpan(
    ColorScheme colorScheme,
    StringScanner scanner, {
    required bool isHex,
  }) {
    final match = _getLastMatch(scanner);
    return TextSpan(
      text: isHex ? '0x${match.substring(2).toUpperCase()}' : match,
      style: TextStyle(
        color: colorScheme.numericConstantSyntaxColor,
      ),
    );
  }

  TextSpan _highlightAssemblyCode(BuildContext context, String instruction) {
    final instructionSpan = RegExp(r'[a-zA-Z]+');
    final registerRegExp = RegExp(r'[a-zA-Z0-9]{2,3}');
    final addressRegExp = RegExp(r'0x[a-fA-F0-9]+');
    final numericRegExp = RegExp(r'\d+');
    final spans = <TextSpan>[];

    final scanner = StringScanner(instruction);
    final colorScheme = Theme.of(context).colorScheme;

    // The instruction (e.g., push, movq, jl, etc) will always be first, if
    // it's present.
    if (scanner.scan(instructionSpan)) {
      spans.add(_buildInstructionSpanRegExp(colorScheme, scanner));
    }
    while (!scanner.isDone) {
      if (scanner.scan(addressRegExp)) {
        spans.add(_buildNumericSpan(colorScheme, scanner, isHex: true));
      } else if (scanner.scan(numericRegExp)) {
        spans.add(_buildNumericSpan(colorScheme, scanner, isHex: false));
      } else if (scanner.scan(registerRegExp)) {
        spans.add(_buildRegisterSpan(colorScheme, scanner));
      } else {
        spans.add(
          TextSpan(
            text: String.fromCharCode(scanner.readChar()),
          ),
        );
      }
    }
    return TextSpan(children: spans);
  }
}

class _DartObjectColumn extends _CodeColumnData {
  _DartObjectColumn() : super.wide('Object');

  @override
  String getValue(Instruction dataObject) =>
      _objectToDisplayValue(dataObject.object);

  // TODO(bkonyi): verify this covers all cases.
  String _objectToDisplayValue(Object? object) {
    if (object is InstanceRef) {
      final instance = object;
      switch (instance.kind!) {
        case InstanceKind.kNull:
          return 'null';
        case InstanceKind.kBool:
          return instance.valueAsString!;
        case InstanceKind.kList:
          return 'List(${instance.length})';
        case InstanceKind.kString:
          return '"${instance.valueAsString}"';
        case InstanceKind.kPlainInstance:
          return 'TODO(PlainInstance)';
        case InstanceKind.kClosure:
          return instance.closureFunction!.name!;
      }
    }

    if (object is FuncRef) {
      final func = object;
      return '${func.owner.name}.${func.name!}';
    }

    if (object is CodeRef) {
      final code = object;
      return code.name!;
    }

    if (object is FieldRef) {
      final field = object;
      return '${field.declaredType!.name} ${field.name}';
    }

    if (object is TypeArgumentsRef) {
      final typeArgsRef = object;
      return 'TypeArguments(${typeArgsRef.name!})';
    }

    // Note: this check should be last as [ObjRef] is a super type to most
    // other types in package:vm_service.
    if (object is ObjRef) {
      final objRef = object;
      if (objRef.isICData) {
        final icData = objRef.asICData;
        return 'ICData (${icData.selector})';
      }
      if (objRef.vmType != null) {
        return objRef.vmType!;
      }
    }

    return object?.toString() ?? '';
  }
}

/// A widget for the object inspector historyViewport displaying information
/// related to [Code] objects in the Dart VM.
class VmCodeDisplay extends StatelessWidget {
  const VmCodeDisplay({
    required this.code,
  });

  final CodeObject code;

  @override
  Widget build(BuildContext context) {
    return CodeTable(code: code);
  }
}

class CodeTable extends StatelessWidget {
  CodeTable({
    Key? key,
    required this.code,
  }) : super(key: key);

  final columns = <ColumnData<Instruction>>[
    _AddressColumn(),
    _InstructionColumn(),
    _DartObjectColumn(),
    if (profilerTicksEnabled) ...[
      _ProfileTicksColumn('Inclusive'),
      _ProfileTicksColumn('Exclusive'),
    ],
  ];

  final CodeObject code;

  @override
  Widget build(BuildContext context) {
    return FlatTable<Instruction>(
      columnGroups: [
        ColumnGroup(title: 'Instructions', range: const Range(0, 3)),
        if (profilerTicksEnabled)
          ColumnGroup(title: 'Profiler Ticks', range: const Range(4, 6)),
      ],
      columns: columns,
      data: code.obj.disassembly.instructions,
      keyFactory: (instruction) => Key(instruction.address),
      onItemSelected: (_) => null,
      sortColumn: columns[0],
      sortDirection: SortDirection.ascending,
    );
  }
}
