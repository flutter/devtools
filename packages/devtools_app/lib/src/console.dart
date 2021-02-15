// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'debugger/debugger_controller.dart';
import 'debugger/variables.dart';
import 'theme.dart';
import 'utils.dart';

// TODO(devoncarew): Allow scrolling horizontally as well.

// TODO(devoncarew): Support hyperlinking to stack traces.

/// Renders a ConsoleOutput widget with ConsoleControls overlaid on the
/// top-right corner.
class Console extends StatelessWidget {
  const Console({
    this.controls,
    @required this.lines,
    this.title,
  }) : super();

  final Widget title;
  final List<Widget> controls;
  final List<ConsoleLine> lines;

  @visibleForTesting
  String get textContent => lines.join('\n');

  @override
  Widget build(BuildContext context) {
    return ConsoleFrame(
      controls: controls,
      title: title,
      child: _ConsoleOutput(lines: lines),
    );
  }
}

class ConsoleFrame extends StatelessWidget {
  const ConsoleFrame({
    this.controls,
    @required this.child,
    this.title,
  }) : super();

  final Widget title;
  final Widget child;
  final List<Widget> controls;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) title,
        Expanded(
          child: Material(
            child: Stack(
              children: [
                child,
                if (controls != null && controls.isNotEmpty)
                  _ConsoleControls(
                    controls: controls,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
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

  final List<ConsoleLine> lines;

  @override
  _ConsoleOutputState createState() => _ConsoleOutputState();
}

class _ConsoleOutputState extends State<_ConsoleOutput> {
  // The scroll controller must survive ConsoleOutput re-renders
  // to work as intended, so it must be part of the "state".
  final ScrollController _scroll = ScrollController();

  // Whenever the widget updates, refresh the scroll position if needed.
  @override
  void didUpdateWidget(Widget oldWidget) {
    if (_scroll.hasClients && _scroll.atScrollBottom) {
      _scroll.autoScrollToBottom();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.all(denseSpacing),
        itemCount: widget.lines?.length ?? 0,
        controller: _scroll,
        itemBuilder: (context, index) {
          final line = widget.lines[index];
          if (line is TextConsoleLine) {
            return SelectableText.rich(
              TextSpan(
                // TODO(jacobr): consider caching the processed ansi terminal
                // codes.
                children: processAnsiTerminalCodes(
                  line.text,
                  theme.fixedFontStyle,
                ),
              ),
            );
          } else if (line is VariableConsoleLine) {
            return ExpandableVariable(
              variable: ValueNotifier(line.variable),
            );
          } else {
            assert(false,
                'ConsoleLine of unsupported type ${line.runtimeType} encountered');
            return const SizedBox();
          }
        },
      ),
    );
  }
}

// CONTROLS

/// A Console Control to "delete" the contents of the console.
///
/// This just preconfigures a ConsoleControl with the `delete` icon,
/// and the `onPressed` function passed from the outside.
class DeleteControl extends StatelessWidget {
  const DeleteControl({
    this.onPressed,
    this.tooltip = 'Clear contents',
    this.buttonKey,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    return ToolbarAction(
      icon: Icons.delete,
      tooltip: tooltip,
      onPressed: onPressed,
      key: buttonKey,
    );
  }
}

/// The type of data provider function used by the CopyToClipboard Control.
typedef ClipboardDataProvider = String Function();

/// A Console Control that copies `data` to the clipboard.
///
/// If it succeeds, it displays a notification with `successMessage`.
class CopyToClipboardControl extends StatelessWidget {
  const CopyToClipboardControl({
    this.dataProvider,
    this.successMessage = 'Copied to clipboard.',
    this.tooltip = 'Copy to clipboard',
    this.buttonKey,
  });

  final ClipboardDataProvider dataProvider;
  final String successMessage;
  final String tooltip;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    final disabled = dataProvider == null;
    return ToolbarAction(
      icon: Icons.content_copy,
      tooltip: tooltip,
      onPressed: disabled
          ? null
          : () => copyToClipboard(dataProvider(), successMessage, context),
      key: buttonKey,
    );
  }
}
