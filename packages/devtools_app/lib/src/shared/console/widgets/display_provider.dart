// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Stack;
import 'package:vm_service/vm_service.dart';

import '../../../shared/globals.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/routing.dart';
import '../../../shared/theme.dart';
import '../../diagnostics/dart_object_node.dart';
import '../../primitives/simple_items.dart';
import 'description.dart';

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

    if (variable.text != null) {
      return InteractivityWrapper(
        onTap: onTap,
        buttonItems: _getButtonItems(context),
        child: Text.rich(
          TextSpan(
            children: processAnsiTerminalCodes(
              variable.text,
              theme.subtleFixedFontStyle,
            ),
          ),
        ),
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
    return InteractivityWrapper(
      onTap: onTap,
      buttonItems: _getButtonItems(context),
      child: Text.rich(
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
      ),
    );
  }

  List<ContextMenuButtonItem> _getButtonItems(
    BuildContext context,
  ) {
    final buttonItems = <ContextMenuButtonItem>[];

    if (variable.isRerootable) {
      buttonItems.add(
        ContextMenuButtonItem(
          onPressed: () {
            ContextMenuController.removeAny();
            final ref = variable.ref;
            serviceManager.consoleService.appendBrowsableInstance(
              instanceRef: variable.value as InstanceRef?,
              isolateRef: ref?.isolateRef,
              heapSelection: ref?.heapSelection,
            );
          },
          label: 'Reroot',
        ),
      );
    }

    if (serviceManager.inspectorService != null && variable.isRoot) {
      buttonItems.add(
        ContextMenuButtonItem(
          onPressed: () {
            ContextMenuController.removeAny();
            _handleInspect(context);
          },
          label: 'Inspect',
        ),
      );
    }

    return buttonItems;
  }

  void _handleInspect(
    BuildContext context,
  ) async {
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

/// A wrapper that allows the user to interact with the variable.
///
/// Responds to primary and secondary click events.
class InteractivityWrapper extends StatefulWidget {
  const InteractivityWrapper({
    super.key,
    required this.child,
    required this.buttonItems,
    this.onTap,
  });

  /// Button items shown in a context menu on secondary click.
  final List<ContextMenuButtonItem> buttonItems;

  /// Optional callback when tapped.
  final void Function()? onTap;

  /// The child widget that will be listened to for gestures.
  final Widget child;

  @override
  State<InteractivityWrapper> createState() => _InteractivityWrapperState();
}

class _InteractivityWrapperState extends State<InteractivityWrapper> {
  final ContextMenuController _contextMenuController = ContextMenuController();

  void _onTap() {
    ContextMenuController.removeAny();
    final onTap = widget.onTap;
    if (onTap != null) {
      onTap();
    }
  }

  void _onSecondaryTapUp(TapUpDetails details) {
    if (!_contextMenuController.isShown) {
      _showMenu(details.globalPosition);
    }
  }

  void _showMenu(Offset offset) {
    if (widget.buttonItems.isEmpty) {
      return;
    }
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (context) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: TextSelectionToolbarAnchors(primaryAnchor: offset),
          buttonItems: widget.buttonItems,
        );
      },
    );
  }

  @override
  void dispose() {
    _contextMenuController.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      onSecondaryTapUp: _onSecondaryTapUp,
      child: widget.child,
    );
  }
}
