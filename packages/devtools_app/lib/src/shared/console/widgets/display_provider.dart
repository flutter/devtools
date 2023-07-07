// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Stack;
import 'package:vm_service/vm_service.dart';

import '../../../shared/globals.dart';
import '../../../shared/primitives/selection_controls.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/routing.dart';
import '../../../shared/theme.dart';
import '../../diagnostics/dart_object_node.dart';
import '../../primitives/simple_items.dart';
import 'description.dart';

VariableSelectionControls _selectionControls({
  required DartObjectNode variable,
  required Function(TextSelectionDelegate delegate)? onInspect,
}) {
  final ref = variable.ref;
  return VariableSelectionControls(
    onReroot: variable.isRerootable
        ? (delegate) {
            serviceManager.consoleService.appendBrowsableInstance(
              instanceRef: variable.value as InstanceRef?,
              isolateRef: ref?.isolateRef,
              heapSelection: ref?.heapSelection,
            );
          }
        : null,
    onInspect: onInspect,
  );
}

class DisplayProvider extends StatelessWidget {
  const DisplayProvider({
    super.key,
    required this.variable,
    required this.onTap,
  });

  final DartObjectNode variable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // TODO(devoncarew): Here, we want to wait until the tooltip wants to show,
    // then call toString() on variable and render the result in a tooltip. We
    // should also include the type of the value in the tooltip if the variable
    // is not null.
    if (variable.text != null) {
      return SelectableText.rich(
        TextSpan(
          children: processAnsiTerminalCodes(
            variable.text,
            theme.subtleFixedFontStyle,
          ),
        ),
        onTap: onTap,
        selectionControls:
            _selectionControls(variable: variable, onInspect: null),
      );
    }
    final diagnostic = variable.ref?.diagnostic;
    if (diagnostic != null) {
      return DiagnosticsNodeDescription(
        diagnostic,
        multiline: true,
        style: theme.fixedFontStyle,
      );
    }

    final hasName = variable.name?.isNotEmpty ?? false;
    return SelectableText.rich(
      TextSpan(
        text: hasName ? variable.name : null,
        style: variable.artificialName
            ? theme.subtleFixedFontStyle
            : theme.fixedFontStyle.apply(
                color: theme.colorScheme.controlFlowSyntaxColor,
              ),
        children: [
          if (hasName)
            TextSpan(
              text: ': ',
              style: theme.fixedFontStyle,
            ),
          TextSpan(
            text: variable.displayValue.toString(),
            style: variable.artificialValue
                ? theme.subtleFixedFontStyle
                : _variableDisplayStyle(theme, variable),
          ),
        ],
      ),
      selectionControls: _selectionControls(
        variable: variable,
        onInspect: serviceManager.inspectorService == null
            ? null
            : (delegate) => _handleInspect(delegate, context),
      ),
      onTap: onTap,
    );
  }

  void _handleInspect(
    TextSelectionDelegate delegate,
    BuildContext context,
  ) async {
    delegate.hideToolbar();
    final router = DevToolsRouterDelegate.of(context);
    final inspectorService = serviceManager.inspectorService;
    if (await variable.inspectWidget()) {
      router.navigateIfNotCurrent(ScreenMetaData.inspector.id);
    } else {
      if (inspectorService!.isDisposed) return;
      final isInspectable = await variable.isInspectable;
      if (inspectorService.isDisposed) return;
      if (isInspectable) {
        notificationService.push(
          'Widget is already the current inspector selection.',
        );
      } else {
        notificationService.push(
          'Only Elements and RenderObjects can currently be inspected',
        );
      }
    }
  }

  TextStyle _variableDisplayStyle(ThemeData theme, DartObjectNode variable) {
    final style = theme.subtleFixedFontStyle;
    String? kind = variable.ref?.instanceRef?.kind;
    // Handle nodes with primative values.
    if (kind == null) {
      final value = variable.ref?.value;
      if (value != null) {
        switch (value.runtimeType) {
          case String:
            kind = InstanceKind.kString;
            break;
          case num:
            kind = InstanceKind.kInt;
            break;
          case bool:
            kind = InstanceKind.kBool;
            break;
        }
      }
      kind ??= InstanceKind.kNull;
    }
    switch (kind) {
      case InstanceKind.kString:
        return style.apply(
          color: theme.colorScheme.stringSyntaxColor,
        );
      case InstanceKind.kInt:
      case InstanceKind.kDouble:
        return style.apply(
          color: theme.colorScheme.numericConstantSyntaxColor,
        );
      case InstanceKind.kBool:
      case InstanceKind.kNull:
        return style.apply(
          color: theme.colorScheme.modifierSyntaxColor,
        );
      default:
        return style;
    }
  }
}
