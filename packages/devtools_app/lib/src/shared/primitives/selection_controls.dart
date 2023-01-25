// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;

/// Android Material styled text selection controls.
class VariableSelectionControls extends MaterialTextSelectionControls {
  VariableSelectionControls({
    required this.onInspect,
  });

  final void Function(TextSelectionDelegate delegate)? onInspect;

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
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) {
    return _TextSelectionControlsToolbar(
      globalEditableRegion: globalEditableRegion,
      textLineHeight: textLineHeight,
      selectionMidpoint: selectionMidpoint,
      endpoints: endpoints,
      delegate: delegate,
      clipboardStatus: clipboardStatus!,
      handleCut: canCut(delegate) ? () => handleCut(delegate) : null,
      handleCopy: canCopy(delegate) ? () => handleCopy(delegate) : null,
      handlePaste:
          canPaste(delegate) ? () => unawaited(handlePaste(delegate)) : null,
      handleSelectAll:
          canSelectAll(delegate) ? () => handleSelectAll(delegate) : null,
      handleInspect: onInspect != null ? () => onInspect!(delegate) : null,
    );
  }
}

/// The highest level toolbar widget, built directly by buildToolbar.
class _TextSelectionControlsToolbar extends StatefulWidget {
  const _TextSelectionControlsToolbar({
    Key? key,
    required this.clipboardStatus,
    required this.delegate,
    required this.endpoints,
    required this.globalEditableRegion,
    required this.handleInspect,
    required this.handleCut,
    required this.handleCopy,
    required this.handlePaste,
    required this.handleSelectAll,
    required this.selectionMidpoint,
    required this.textLineHeight,
  }) : super(key: key);

  final ValueListenable<ClipboardStatus> clipboardStatus;
  final TextSelectionDelegate delegate;
  final List<TextSelectionPoint> endpoints;
  final Rect globalEditableRegion;
  final VoidCallback? handleInspect;
  final VoidCallback? handleCut;
  final VoidCallback? handleCopy;
  final VoidCallback? handlePaste;
  final VoidCallback? handleSelectAll;
  final Offset selectionMidpoint;
  final double textLineHeight;

  @override
  _TextSelectionControlsToolbarState createState() =>
      _TextSelectionControlsToolbarState();
}

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
  }

  @override
  void didUpdateWidget(_TextSelectionControlsToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clipboardStatus != oldWidget.clipboardStatus) {
      widget.clipboardStatus.addListener(_onChangedClipboardStatus);
      oldWidget.clipboardStatus.removeListener(_onChangedClipboardStatus);
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.clipboardStatus.removeListener(_onChangedClipboardStatus);
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

// Forked from material/text_selection.dart
const double _kHandleSize = 22.0;

// Padding between the toolbar and the anchor.
const double _kToolbarContentDistanceBelow = _kHandleSize - 2.0;
const double _kToolbarContentDistance = 8.0;

/// The label and callback for the available default text selection menu buttons.
class _TextSelectionToolbarItemData {
  const _TextSelectionToolbarItemData({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;
}
