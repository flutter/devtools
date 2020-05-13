// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/notifications.dart';
import '../../flutter/theme.dart';
import '../../flutter/utils.dart';
import 'codeview.dart';
import 'debugger_controller.dart';

// TODO(devoncarew): Allow scrolling horizontally as well.

// TODO(devoncarew): Show some small UI indicator when we receive stdout/stderr.

// TODO(devoncarew): Support hyperlinking to stack traces.

/// Display the stdout and stderr output from the process under debug.
class Console extends StatefulWidget {
  const Console({
    Key key,
    this.controller,
  }) : super(key: key);

  final DebuggerController controller;

  @override
  _ConsoleState createState() => _ConsoleState();
}

class _ConsoleState extends State<Console> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: widget.controller.stdio,
      builder: (context, lines, _) {
        // Extract this to a reusable ConsoleWithControls StatelessWidget?
        return Stack(
          children: [
            ConsoleOutput(lines: lines),
            Container(
              alignment: Alignment.bottomRight,
              child: ConsoleControls(
                disabled: lines.isEmpty,
                onCopyPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: lines.join('\n'),
                  )).then((_) {
                    Notifications.of(context)?.push(
                      'Copied!',
                    );
                  });
                },
                onDeletePressed: widget.controller.clearStdio,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Optionally renders a ButtonBar with Console Controls,
/// Copy and Clear.
/// The callbacks for those buttons are passed from the outside.
class ConsoleControls extends StatelessWidget {
  const ConsoleControls({
    this.disabled,
    this.onCopyPressed,
    this.onDeletePressed,
  }) : super();

  final Function onCopyPressed;
  final Function onDeletePressed;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return disabled
        ? Container()
        : ButtonBar(
            buttonPadding: EdgeInsets.zero,
            alignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.content_copy),
                onPressed: onCopyPressed,
                tooltip: 'Copy to clipboard.',
              ),
              IconButton(
                icon: const Icon(Icons.block),
                onPressed: onDeletePressed,
                tooltip: 'Clear console output.',
              ),
            ],
          );
  }
}

/// Renders a widget with the output of the console.
/// This is a ListView of text lines, with a monospace font and a border.
class ConsoleOutput extends StatefulWidget {
  const ConsoleOutput({
    Key key,
    this.lines,
  }) : super(key: key);

  final List<String> lines;

  @override
  _ConsoleOutputState createState() => _ConsoleOutputState();
}

class _ConsoleOutputState extends State<ConsoleOutput> {
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
      child: Padding(
        padding: const EdgeInsets.all(denseSpacing),
        child: ListView.builder(
          itemCount: widget.lines.length,
          itemExtent: CodeView.rowHeight,
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
