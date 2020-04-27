// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/theme.dart';
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
            if (scrollController.hasClients) {
              // If we're at the end already, scroll to expose the new
              // content.
              // TODO(devoncarew): We should generalize the
              // auto-scroll-to-bottom feature.
              final pos = scrollController.position;
              if (pos.pixels == pos.maxScrollExtent) {
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
              }
            }

            return ListView.builder(
              itemCount: lines.length,
              itemExtent: CodeView.rowHeight,
              controller: scrollController,
              itemBuilder: (context, index) {
                return Text(
                  lines[index],
                  maxLines: 1,
                  style: textStyle,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _scrollToBottom() async {
    if (mounted && scrollController.hasClients) {
      await scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: rapidDuration,
        curve: defaultCurve,
      );

      // Scroll again if we've received new content in the interim.
      final pos = scrollController.position;
      if (pos.pixels != pos.maxScrollExtent) {
        scrollController.jumpTo(pos.maxScrollExtent);
      }
    }
  }
}
