// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart';

import '../../diagnostics/dap_object_node.dart';
import '../../diagnostics/dart_object_node.dart';
import '../../globals.dart';
import '../../primitives/utils.dart';
import '../../routing.dart';
import '../../screen.dart';
import '../../theme.dart';
import 'description.dart';

/// Defines how to display and interact with a variable node.
abstract class NodeDisplayProvider<T> extends StatelessWidget {
  const NodeDisplayProvider({
    super.key,
    required this.node,
    required this.onTap,
  });

  final T node;

  final VoidCallback onTap;
}

/// The display provider for variables fetched via the VM service protocol.
class VmDisplayProvider extends StatelessWidget implements NodeDisplayProvider {
  const VmDisplayProvider({
    super.key,
    required this.node,
    required this.onTap,
  });

  @override
  final DartObjectNode node;

  @override
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (node.text != null) {
      return InteractivityWrapper(
        onTap: onTap,
        menuButtons: _getMenuButtons(context),
        child: Text.rich(
          TextSpan(
            children: processAnsiTerminalCodes(
              node.text,
              theme.subtleFixedFontStyle,
            ),
          ),
        ),
      );
    }
    final diagnostic = node.ref?.diagnostic;
    if (diagnostic != null) {
      return DiagnosticsNodeDescription(
        diagnostic,
        multiline: true,
        style: theme.fixedFontStyle,
      );
    }

    final hasName = node.name?.isNotEmpty ?? false;
    return InteractivityWrapper(
      onTap: onTap,
      menuButtons: _getMenuButtons(context),
      child: Text.rich(
        TextSpan(
          text: hasName ? node.name : null,
          style: node.artificialName
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
              text: node.displayValue.toString(),
              style: node.artificialValue
                  ? theme.subtleFixedFontStyle
                  : _variableDisplayStyle(theme, node),
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
      if (node.isRerootable)
        ContextMenuButtonItem(
          onPressed: () {
            ContextMenuController.removeAny();
            final ref = node.ref;
            serviceManager.consoleService.appendBrowsableInstance(
              instanceRef: node.value as InstanceRef?,
              isolateRef: ref?.isolateRef,
              heapSelection: ref?.heapSelection,
            );
          },
          label: 'Reroot',
        ),
      if (serviceManager.inspectorService != null && node.isRoot)
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
    final router = DevToolsRouterDelegate.of(context);
    final inspectorService = serviceManager.inspectorService;
    if (await node.inspectWidget()) {
      router.navigateIfNotCurrent(ScreenMetaData.inspector.id);
    } else {
      if (inspectorService!.isDisposed) return;
      final isInspectable = await node.isInspectable;
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
class DapDisplayProvider extends StatelessWidget
    implements NodeDisplayProvider {
  const DapDisplayProvider({
    super.key,
    required this.node,
    required this.onTap,
  });

  @override
  final DapObjectNode node;

  @override
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
