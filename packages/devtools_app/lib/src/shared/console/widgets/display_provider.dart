// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
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
import '../../ui/colors.dart';
import 'description.dart';

/// The display provider for variables fetched via the VM service protocol.
class DisplayProvider extends StatefulWidget {
  const DisplayProvider({
    super.key,
    required this.variable,
    required this.onTap,
    this.onCopy,
  });

  final DartObjectNode variable;
  final VoidCallback onTap;
  final void Function(DartObjectNode)? onCopy;

  @override
  State<DisplayProvider> createState() => _DisplayProviderState();
}

class _DisplayProviderState extends State<DisplayProvider> {
  bool isHovered = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.variable.text != null) {
      return InteractivityWrapper(
        onTap: widget.onTap,
        menuButtons: _getMenuButtons(context),
        child: Text.rich(
          TextSpan(
            children: processAnsiTerminalCodes(
              widget.variable.text,
              theme.subtleFixedFontStyle,
            ),
          ),
        ),
      );
    }
    final diagnostic = widget.variable.ref?.diagnostic;
    if (diagnostic != null) {
      return DiagnosticsNodeDescription(
        diagnostic,
        multiline: true,
        style: theme.fixedFontStyle,
      );
    }

    // Only enable hover behaviour when copy behaviour is provided.
    final isHoverEnabled = widget.onCopy != null;

    final hasName = widget.variable.name?.isNotEmpty ?? false;

    // The tooltip can be hovered over in order to see the original text.
    final originalDisplayValue = widget.variable.displayValue.toString();
    // Only 1 line of text is permitted in the tree, since we only get 1 row.
    // So replace all newlines with \\n so that the user can still see that
    // there are new lines in the value.
    final displayValue = originalDisplayValue.replaceAll('\n', '\\n');
    final contents = InteractivityWrapper(
      onTap: widget.onTap,
      menuButtons: _getMenuButtons(
        context,
      ),
      child: DevToolsTooltip(
        message: originalDisplayValue,
        child: Container(
          color: isHovered ? Theme.of(context).highlightColor : null,
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  TextSpan(
                    text: hasName ? widget.variable.name : null,
                    style: widget.variable.artificialName
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
                        text: displayValue,
                        style: widget.variable.artificialValue
                            ? theme.subtleFixedFontStyle
                            : _variableDisplayStyle(theme, widget.variable),
                      ),
                    ],
                  ),
                ),
              ),
              if (isHovered && widget.onCopy != null)
                DevToolsButton(
                  icon: Icons.copy,
                  outlined: false,
                  onPressed: () => widget.onCopy!.call(widget.variable),
                ),
            ],
          ),
        ),
      ),
    );

    if (isHoverEnabled) {
      return SelectionContainer.disabled(
        child: MouseRegion(
          onEnter: (_) {
            setState(() {
              isHovered = true;
            });
          },
          onExit: (event) {
            setState(() {
              isHovered = false;
            });
          },
          child: contents,
        ),
      );
    }
    return contents;
  }

  List<ContextMenuButtonItem> _getMenuButtons(
    BuildContext context,
  ) {
    return [
      if (widget.variable.isRerootable)
        ContextMenuButtonItem(
          onPressed: () {
            ContextMenuController.removeAny();
            final ref = widget.variable.ref;
            serviceConnection.consoleService.appendBrowsableInstance(
              instanceRef: widget.variable.value as InstanceRef?,
              isolateRef: ref?.isolateRef,
              heapSelection: ref?.heapSelection,
            );
          },
          label: 'Reroot',
        ),
      if (serviceConnection.inspectorService != null && widget.variable.isRoot)
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
    final inspectorService = serviceConnection.inspectorService;
    if (await widget.variable.inspectWidget()) {
      router.navigateIfNotCurrent(ScreenMetaData.inspector.id);
    } else {
      if (inspectorService!.isDisposed) return;
      final isInspectable = await widget.variable.isInspectable;
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
          case const (String):
            kind = InstanceKind.kString;
            break;
          case const (num):
            kind = InstanceKind.kInt;
            break;
          case const (bool):
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
