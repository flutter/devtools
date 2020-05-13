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
    return Stack(
      children: [
        ConsoleOutput(lines: widget.controller.stdio),
        Container(
          alignment: Alignment.bottomRight,
          child: ConsoleControls(
            lines: widget.controller.stdio,
            onCopyPressed: () {
              Clipboard.setData(ClipboardData(
                text: widget.controller.stdio.value.join('\n'),
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
  }
}

/// Optionally renders a ButtonBar with Console Controls,
/// Copy and Clear.
/// The callbacks for those buttons are passed from the outside.
class ConsoleControls extends StatelessWidget {
  const ConsoleControls({
    @required ValueListenable<List<String>> lines,
    this.onCopyPressed,
    this.onDeletePressed,
  })  : _lines = lines,
        super();

  final Function onCopyPressed;
  final Function onDeletePressed;

  final ValueListenable<List<String>> _lines;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
        valueListenable: _lines,
        builder: (context, lines, _) {
          return lines.isEmpty
              ? Container()
              : ButtonBar(
                  buttonPadding: EdgeInsets.zero,
                  alignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.content_copy),
                        onPressed: onCopyPressed,
                        tooltip: 'Copy to clipboard.'),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onDeletePressed,
                      tooltip: 'Clear console output.',
                    ),
                  ],
                );
        });
  }
}

/// Renders a widget with the output of the console.
/// This is a ListView of text lines, with monospace font and a border.
class ConsoleOutput extends StatelessWidget {
  const ConsoleOutput({@required ValueListenable<List<String>> lines})
      : _lines = lines,
        super();

  final ValueListenable<List<String>> _lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle =
        theme.textTheme.bodyText2.copyWith(fontFamily: 'RobotoMono');

    final scrollController = ScrollController();

    return OutlineDecoration(
      child: Padding(
        padding: const EdgeInsets.all(denseSpacing),
        child: ValueListenableBuilder<List<String>>(
          valueListenable: _lines,
          builder: (context, lines, _) {
            // If we're at the end already, scroll to expose the new content.
            if (scrollController.hasClients &&
                scrollController.atScrollBottom) {
              scrollController.autoScrollToBottom();
            }

            return ListView.builder(
              itemCount: lines.length,
              itemExtent: CodeView.rowHeight,
              controller: scrollController,
              itemBuilder: (context, index) {
                return RichText(
                  text: TextSpan(
                    children: processAnsiTerminalCodes(
                      lines[index],
                      textStyle,
                    ),
                  ),
                  maxLines: 1,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
