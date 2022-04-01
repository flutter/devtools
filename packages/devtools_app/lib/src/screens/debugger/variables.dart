// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart' hide Stack;
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../primitives/listenable.dart';
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/notifications.dart';
import '../../shared/routing.dart';
import '../../shared/theme.dart';
import '../../shared/tree.dart';
import '../inspector/diagnostics.dart';
import '../inspector/inspector_screen.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';

class Variables extends StatelessWidget {
  const Variables({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DebuggerController>(context);
    // TODO(kenz): preserve expanded state of tree on switching frames and
    // on stepping.
    return TreeView<DartObjectNode>(
      dataRootsListenable: controller.variables,
      dataDisplayProvider: (variable, onPressed) =>
          displayProvider(context, variable, onPressed, controller),
      onItemSelected: (variable) => onItemPressed(variable, controller),
    );
  }

  void onItemPressed(DartObjectNode v, DebuggerController controller) {
    // On expansion, lazily build the variables tree for performance reasons.
    if (v.isExpanded) {
      v.children.forEach(buildVariablesTree);
    }
  }
}

class ExpandableVariable extends StatelessWidget {
  const ExpandableVariable({
    Key key,
    this.variable,
    @required this.debuggerController,
  })  : assert(debuggerController != null),
        super(key: key);

  final DartObjectNode variable;
  final DebuggerController debuggerController;

  @override
  Widget build(BuildContext context) {
    if (variable == null) return const SizedBox();
    // TODO(kenz): preserve expanded state of tree on switching frames and
    // on stepping.
    return TreeView<DartObjectNode>(
      dataRootsListenable:
          FixedValueListenable<List<DartObjectNode>>([variable]),
      shrinkWrap: true,
      dataDisplayProvider: (variable, onPressed) =>
          displayProvider(context, variable, onPressed, debuggerController),
      onItemSelected: (variable) => onItemPressed(variable, debuggerController),
    );
  }

  void onItemPressed(DartObjectNode v, DebuggerController controller) {
    // On expansion, lazily build the variables tree for performance reasons.
    if (v.isExpanded) {
      v.children.forEach(buildVariablesTree);
    }
  }
}

// TODO(jacobr): this looks like a widget.
Widget displayProvider(
  BuildContext context,
  DartObjectNode variable,
  VoidCallback onTap,
  DebuggerController controller,
) {
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
          theme.fixedFontStyle,
        ),
      ),
      onTap: onTap,
    );
  }
  final diagnostic = variable.ref?.diagnostic;
  if (diagnostic != null) {
    return DiagnosticsNodeDescription(
      diagnostic,
      isSelected: false,
      multiline: true,
      style: theme.fixedFontStyle,
      debuggerController: controller,
    );
  }
  return DevToolsTooltip(
    message: variable.displayValue,
    waitDuration: tooltipWaitLong,
    child: SelectableText.rich(
      TextSpan(
        text: variable.name?.isNotEmpty ?? false ? '${variable.name}: ' : null,
        style: theme.fixedFontStyle,
        children: [
          TextSpan(
            text: variable.displayValue,
            style: theme.subtleFixedFontStyle,
          ),
        ],
      ),
      selectionControls: VariableSelectionControls(
        handleInspect: serviceManager.inspectorService != null
            ? (delegate) async {
                delegate.hideToolbar();
                final router = DevToolsRouterDelegate.of(context);
                final notifications = Notifications.of(context);
                final inspectorService = serviceManager.inspectorService;
                if (await variable.inspectWidget()) {
                  router.navigateIfNotCurrent(InspectorScreen.id);
                } else {
                  if (inspectorService.isDisposed) return;
                  final isInspectable = await variable.isInspectable;
                  if (inspectorService.isDisposed) return;
                  if (isInspectable) {
                    notifications?.push(
                      'Widget is already the current inspector selection.',
                    );
                  } else {
                    notifications?.push(
                      'Only Elements and RenderObjects can currently be inspected',
                    );
                  }
                }
              }
            : null,
      ),
      onTap: onTap,
    ),
  );
}

/// Android Material styled text selection controls.
class VariableSelectionControls extends MaterialTextSelectionControls {
  VariableSelectionControls({
    @required this.handleInspect,
  });

  final void Function(TextSelectionDelegate delegate) handleInspect;

  /// Builder for material-style copy/paste text selection toolbar with added
  /// Dart DevTools specific functionality.
  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ClipboardStatusNotifier clipboardStatus,
    Offset lastSecondaryTapDownPosition,
  ) {
    return _TextSelectionControlsToolbar(
      globalEditableRegion: globalEditableRegion,
      textLineHeight: textLineHeight,
      selectionMidpoint: selectionMidpoint,
      endpoints: endpoints,
      delegate: delegate,
      clipboardStatus: clipboardStatus,
      handleCut:
          canCut(delegate) ? () => handleCut(delegate, clipboardStatus) : null,
      handleCopy: canCopy(delegate)
          ? () => handleCopy(delegate, clipboardStatus)
          : null,
      handlePaste: canPaste(delegate) ? () => handlePaste(delegate) : null,
      handleSelectAll:
          canSelectAll(delegate) ? () => handleSelectAll(delegate) : null,
      handleInspect:
          handleInspect != null ? () => handleInspect(delegate) : null,
    );
  }
}

/// The highest level toolbar widget, built directly by buildToolbar.
class _TextSelectionControlsToolbar extends StatefulWidget {
  const _TextSelectionControlsToolbar({
    Key key,
    @required this.clipboardStatus,
    @required this.delegate,
    @required this.endpoints,
    @required this.globalEditableRegion,
    @required this.handleInspect,
    @required this.handleCut,
    @required this.handleCopy,
    @required this.handlePaste,
    @required this.handleSelectAll,
    @required this.selectionMidpoint,
    @required this.textLineHeight,
  }) : super(key: key);

  final ClipboardStatusNotifier clipboardStatus;
  final TextSelectionDelegate delegate;
  final List<TextSelectionPoint> endpoints;
  final Rect globalEditableRegion;
  final VoidCallback handleInspect;
  final VoidCallback handleCut;
  final VoidCallback handleCopy;
  final VoidCallback handlePaste;
  final VoidCallback handleSelectAll;
  final Offset selectionMidpoint;
  final double textLineHeight;

  @override
  _TextSelectionControlsToolbarState createState() =>
      _TextSelectionControlsToolbarState();
}

// Forked from material/text_selection.dart
const double _kHandleSize = 22.0;

// Padding between the toolbar and the anchor.
const double _kToolbarContentDistanceBelow = _kHandleSize - 2.0;
const double _kToolbarContentDistance = 8.0;

class _TextSelectionControlsToolbarState
    extends State<_TextSelectionControlsToolbar> with TickerProviderStateMixin {
  void _onChangedClipboardStatus() {
    setState(() {
      // Inform the widget that the value of clipboardStatus has changed.
    });
  }

  @override
  void initState() {
    super.initState();
    widget.clipboardStatus.addListener(_onChangedClipboardStatus);
    widget.clipboardStatus.update();
  }

  @override
  void didUpdateWidget(_TextSelectionControlsToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clipboardStatus != oldWidget.clipboardStatus) {
      widget.clipboardStatus.addListener(_onChangedClipboardStatus);
      oldWidget.clipboardStatus.removeListener(_onChangedClipboardStatus);
    }
    widget.clipboardStatus.update();
  }

  @override
  void dispose() {
    super.dispose();
    // When used in an Overlay, it can happen that this is disposed after its
    // creator has already disposed _clipboardStatus.
    if (!widget.clipboardStatus.disposed) {
      widget.clipboardStatus.removeListener(_onChangedClipboardStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If there are no buttons to be shown, don't render anything.
    if (widget.handleCut == null &&
        widget.handleCopy == null &&
        widget.handlePaste == null &&
        widget.handleSelectAll == null) {
      return const SizedBox.shrink();
    }
    // If the paste button is desired, don't render anything until the state of
    // the clipboard is known, since it's used to determine if paste is shown.
    if (widget.handlePaste != null &&
        widget.clipboardStatus.value == ClipboardStatus.unknown) {
      return const SizedBox.shrink();
    }

    // Calculate the positioning of the menu. It is placed above the selection
    // if there is enough room, or otherwise below.
    final startTextSelectionPoint = widget.endpoints[0];
    final endTextSelectionPoint =
        widget.endpoints.length > 1 ? widget.endpoints[1] : widget.endpoints[0];
    final anchorAbove = Offset(
      widget.globalEditableRegion.left + widget.selectionMidpoint.dx,
      widget.globalEditableRegion.top +
          startTextSelectionPoint.point.dy -
          widget.textLineHeight -
          _kToolbarContentDistance,
    );
    final anchorBelow = Offset(
      widget.globalEditableRegion.left + widget.selectionMidpoint.dx,
      widget.globalEditableRegion.top +
          endTextSelectionPoint.point.dy +
          _kToolbarContentDistanceBelow,
    );

    // Determine which buttons will appear so that the order and total number is
    // known. A button's position in the menu can slightly affect its
    // appearance.
    assert(debugCheckHasMaterialLocalizations(context));
    final localizations = MaterialLocalizations.of(context);
    final itemDatas = <_TextSelectionToolbarItemData>[
      if (widget.handleInspect != null)
        _TextSelectionToolbarItemData(
          label: 'Inspect',
          onPressed: widget.handleInspect,
        ),
      if (widget.handleCut != null)
        _TextSelectionToolbarItemData(
          label: localizations.cutButtonLabel,
          onPressed: widget.handleCut,
        ),
      if (widget.handleCopy != null)
        _TextSelectionToolbarItemData(
          label: localizations.copyButtonLabel,
          onPressed: widget.handleCopy,
        ),
      if (widget.handlePaste != null &&
          widget.clipboardStatus.value == ClipboardStatus.pasteable)
        _TextSelectionToolbarItemData(
          label: localizations.pasteButtonLabel,
          onPressed: widget.handlePaste,
        ),
      if (widget.handleSelectAll != null)
        _TextSelectionToolbarItemData(
          label: localizations.selectAllButtonLabel,
          onPressed: widget.handleSelectAll,
        ),
    ];

    // If there is no option available, build an empty widget.
    if (itemDatas.isEmpty) {
      return const SizedBox(width: 0.0, height: 0.0);
    }

    return TextSelectionToolbar(
      anchorAbove: anchorAbove,
      anchorBelow: anchorBelow,
      children: itemDatas
          .asMap()
          .entries
          .map((MapEntry<int, _TextSelectionToolbarItemData> entry) {
        return TextSelectionToolbarTextButton(
          padding: TextSelectionToolbarTextButton.getPadding(
            entry.key,
            itemDatas.length,
          ),
          onPressed: entry.value.onPressed,
          child: Text(entry.value.label),
        );
      }).toList(),
    );
  }
}

/// The label and callback for the available default text selection menu buttons.
class _TextSelectionToolbarItemData {
  const _TextSelectionToolbarItemData({
    @required this.label,
    @required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;
}
