// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/common_widgets.dart';
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
  final scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle =
        theme.textTheme.bodyText2.copyWith(fontFamily: 'RobotoMono');

    return OutlinedBorder(
      child: Padding(
        padding: const EdgeInsets.all(denseSpacing),
        child: ValueListenableBuilder<List<String>>(
          valueListenable: widget.controller.stdio,
          builder: (context, lines, _) {
            // If we're at the end already, scroll to expose the new
            // content.
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
