// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../debugger/flutter/codeview.dart';

import './common_widgets.dart';
import './theme.dart';
import './utils.dart';

// TODO(devoncarew): Allow scrolling horizontally as well.

// TODO(devoncarew): Show some small UI indicator when we receive stdout/stderr.

// TODO(devoncarew): Support hyperlinking to stack traces.

/// Renders a ConsoleOutput widget with ConsoleControls overlaid on the
/// top-right corner.
class Console extends StatelessWidget {
  const Console({
    this.controls = const <Widget>[],
    this.lines = const <String>[],
  }) : super();

  final List<Widget> controls;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Material(
        child: Stack(
      children: [
        _ConsoleOutput(lines: lines),
        if (controls.isNotEmpty)
          _ConsoleControls(
            controls: controls,
          ),
      ],
    ));
  }
}

/// Renders a top-right aligned ButtonBar wrapping a List of IconButtons
/// (`controls`).
class _ConsoleControls extends StatelessWidget {
  const _ConsoleControls({
    this.controls,
  }) : super();

  final List<Widget> controls;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topRight,
      child: ButtonBar(
        buttonPadding: EdgeInsets.zero,
        alignment: MainAxisAlignment.end,
        children: controls,
      ),
    );
  }
}

/// Renders a widget with the output of the console.
///
/// This is a ListView of text lines, with a monospace font and a border.
class _ConsoleOutput extends StatefulWidget {
  const _ConsoleOutput({
    Key key,
    this.lines,
  }) : super(key: key);

  final List<String> lines;

  @override
  _ConsoleOutputState createState() => _ConsoleOutputState();
}

class _ConsoleOutputState extends State<_ConsoleOutput> {
  // The scroll controller must survive ConsoleOutput re-renders
  // to work as intended, so it must be part of the "state".
  final ScrollController _scroll = ScrollController();

  // Whenever the widget updates, refresh the scroll position if needed.
  @override
  void didUpdateWidget(oldWidget) {
    if (_scroll.hasClients && _scroll.atScrollBottom) {
      _scroll.autoScrollToBottom();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle =
        theme.textTheme.bodyText2.copyWith(fontFamily: 'RobotoMono');

    return OutlineDecoration(
      child: Scrollbar(
        child: ListView.builder(
          padding: const EdgeInsets.all(denseSpacing),
          itemCount: widget.lines?.length ?? 0,
          itemExtent: CodeView.rowHeight, // TODO: Get from theme?
          controller: _scroll,
          itemBuilder: (context, index) {
            return RichText(
              text: TextSpan(
                children: processAnsiTerminalCodes(
                  widget.lines[index],
                  textStyle,
                ),
              ),
              maxLines: 1,
            );
          },
        ),
      ),
    );
  }
}

// CONTROLS

/// A pre-configured IconButton that fits the ux of the Console widget.
/// 
/// The customizations are:
///  * Icon size: [actionsIconSize]
///  * Do not show [tooltip] if the button is disabled
///  * [VisualDensity.compact]
class ConsoleControl extends StatelessWidget {
  const ConsoleControl({this.icon, this.tooltip, this.onPressed, this.buttonKey});
  
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return IconButton(
      icon: Icon(icon, size: actionsIconSize),
      onPressed: onPressed,
      tooltip: disabled ? null : tooltip,
      visualDensity: VisualDensity.compact,
      key: buttonKey,
    );
  }
}

/// A Console Control to "delete" the contents of the console.
/// 
/// This just preconfigures a ConsoleControl with the `delete` icon,
/// and the `onPressed` function passed from the outside.
class DeleteControl extends StatelessWidget {
  const DeleteControl({this.onPressed, this.tooltip = 'Clear contents', this.buttonKey,});

  final VoidCallback onPressed;
  final String tooltip;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    return ConsoleControl(
      icon: Icons.delete,
      tooltip: tooltip,
      onPressed: onPressed,
      buttonKey: buttonKey,
    );
  }
}

/// A Console Control that copies `data` to the clipboard.
/// 
/// If it succeeds, it displays a notification with `successMessage`.
class CopyToClipboardControl extends StatelessWidget {

  const CopyToClipboardControl({this.data, this.successMessage = 'Copied to clipboard.', this.tooltip = 'Copy to clipboard', this.buttonKey,});

  final String data;
  final String successMessage;
  final String tooltip;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    final disabled = data == null || data.isEmpty;
    return ConsoleControl(
      icon: Icons.content_copy,
      tooltip: tooltip,
      onPressed: disabled ? null : () => copyToClipboard(data, successMessage, context),
      buttonKey: buttonKey,
    );
  }
}
