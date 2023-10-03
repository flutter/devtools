// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart';

import '../../../app.dart';
import '../../diagnostics/dap_object_node.dart';
import '../../diagnostics/dart_object_node.dart';
import '../../globals.dart';
import '../../primitives/utils.dart';
import '../../screen.dart';
import '../../ui/colors.dart';
import 'description.dart';

/// The display provider for variables fetched via the VM service protocol.
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
        menuButtons: _getMenuButtons(context),
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
      menuButtons: _getMenuButtons(context),
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

  List<ContextMenuButtonItem> _getMenuButtons(
    BuildContext context,
  ) {
    return [
      if (variable.isRerootable)
        ContextMenuButtonItem(
          onPressed: () {
            ContextMenuController.removeAny();
            final ref = variable.ref;
            serviceConnection.consoleService.appendBrowsableInstance(
              instanceRef: variable.value as InstanceRef?,
              isolateRef: ref?.isolateRef,
              heapSelection: ref?.heapSelection,
            );
          },
          label: 'Reroot',
        ),
      if (serviceConnection.inspectorService != null && variable.isRoot)
        ContextMenuButtonItem(
          onPressed: () {
            ContextMenuController.removeAny();
            _handleInspect(context);
          },
          label: 'Inspect',
        ),
    ];
  }

  void _handleInspect(
    BuildContext context,
  ) async {
    final state = DevToolsApp.of(context);
    final inspectorService = serviceConnection.inspectorService;
    if (await variable.inspectWidget()) {
      state.navigateIfNotCurrent(ScreenMetaData.inspector.id);
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

/// The display provider for variables fetched via the Debug Adapter Protocol.
class DapDisplayProvider extends StatelessWidget {
  const DapDisplayProvider({
    super.key,
    required this.node,
    required this.onTap,
  });

  final DapObjectNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final variable = node.variable;
    final name = variable.name;
    final value = variable.value;

    // TODO(https://github.com/flutter/devtools/issues/6056): Wrap in
    // interactivity wrapper to provide inspect and re-root functionality. Add
    // tooltip on hover to provide type information.
    return Text.rich(
      TextSpan(
        text: name,
        style: theme.fixedFontStyle.apply(
          color: theme.colorScheme.controlFlowSyntaxColor,
        ),
        children: [
          TextSpan(
            text: ': ',
            style: theme.fixedFontStyle,
          ),
          // TODO(https://github.com/flutter/devtools/issues/6056): Change text
          // style based on variable type.
          TextSpan(
            text: value,
            style: theme.subtleFixedFontStyle,
          ),
        ],
      ),
    );
  }
}

/// A wrapper that allows the user to interact with the variable.
///
/// Responds to primary and secondary click events.
class InteractivityWrapper extends StatefulWidget {
  const InteractivityWrapper({
    super.key,
    required this.child,
    this.menuButtons,
    this.onTap,
  });

  /// Button items shown in a context menu on secondary click.
  ///
  /// If none are provided, then no action will happen on secondary click.
  final List<ContextMenuButtonItem>? menuButtons;

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
    _maybeShowMenu(details.globalPosition);
  }

  void _maybeShowMenu(Offset offset) {
    // TODO(https://github.com/flutter/devtools/issues/6018): Once
    // https://github.com/flutter/flutter/issues/129692 is fixed, disable the
    // browser's native context menu on secondary-click, and enable this menu.
    if (kIsWeb && BrowserContextMenu.enabled) {
      return;
    }

    if (_contextMenuController.isShown) {
      return;
    }
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (context) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: TextSelectionToolbarAnchors(primaryAnchor: offset),
          buttonItems: widget.menuButtons,
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
    final contextMenuOnSecondaryTapEnabled =
        widget.menuButtons != null && widget.menuButtons!.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      onSecondaryTapUp:
          contextMenuOnSecondaryTapEnabled ? _onSecondaryTapUp : null,
      child: widget.child,
    );
  }
}
