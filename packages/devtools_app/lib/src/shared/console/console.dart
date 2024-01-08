// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../common_widgets.dart';
import '../primitives/utils.dart';
import 'console_service.dart';
import 'widgets/expandable_variable.dart';

// TODO(devoncarew): Allow scrolling horizontally as well.

// TODO(devoncarew): Support hyperlinking to stack traces.

/// Renders a Console widget with output [lines] and an optional [title] and
/// [footer].
class Console extends StatelessWidget {
  const Console({
    super.key,
    required this.lines,
    this.title,
    this.footer,
  });

  final Widget? title;
  final Widget? footer;
  final ValueListenable<List<ConsoleLine>> lines;

  @override
  Widget build(BuildContext context) {
    return ConsoleFrame(
      title: title,
      child: _ConsoleOutput(lines: lines, footer: footer),
    );
  }
}

class ConsoleFrame extends StatelessWidget {
  const ConsoleFrame({
    super.key,
    required this.child,
    this.title,
  });

  final Widget? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: densePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) title!,
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Renders a widget with the output of the console.
///
/// This is a ListView of text lines, with a monospace font and a border.
class _ConsoleOutput extends StatefulWidget {
  const _ConsoleOutput({
    Key? key,
    required this.lines,
    this.footer,
  }) : super(key: key);

  final ValueListenable<List<ConsoleLine>> lines;

  final Widget? footer;

  @override
  _ConsoleOutputState createState() => _ConsoleOutputState();
}

class _ConsoleOutputState extends State<_ConsoleOutput>
    with AutoDisposeMixin<_ConsoleOutput> {
  // The scroll controller must survive ConsoleOutput re-renders
  // to work as intended, so it must be part of the "state".
  final ScrollController _scroll = ScrollController();

  static const _scrollBarKey = Key('console-scrollbar');

  List<ConsoleLine> _currentLines = const [];
  bool _scrollToBottom = true;
  bool _considerScrollAtBottom = true;
  double _lastScrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _initHelper();
  }

  void _onScrollChanged() {
    // Detect if the user has scrolled up and stop scrolling to the bottom if
    // they have scrolled up.
    if (_scroll.hasClients) {
      if (_scroll.atScrollBottom) {
        _considerScrollAtBottom = true;
      } else if (_lastScrollOffset > _scroll.offset) {
        _considerScrollAtBottom = false;
      }
      _lastScrollOffset = _scroll.offset;
    }
  }

  // Whenever the widget updates, refresh the scroll position if needed.
  @override
  void didUpdateWidget(_ConsoleOutput oldWidget) {
    if (oldWidget.lines != widget.lines) {
      _initHelper();
    }
    super.didUpdateWidget(oldWidget);
  }

  void _initHelper() {
    cancelListeners();
    addAutoDisposeListener(widget.lines, _onConsoleLinesChanged);
    addAutoDisposeListener(_scroll, _onScrollChanged);
    _onConsoleLinesChanged();
  }

  void _onConsoleLinesChanged() {
    final nextLines = widget.lines.value;
    if (nextLines == _currentLines) return;

    var forceScrollIntoView = false;
    for (int i = _currentLines.length; i < nextLines.length; i++) {
      if (nextLines[i].forceScrollIntoView) {
        forceScrollIntoView = true;
        break;
      }
    }
    setState(() {
      _currentLines = nextLines;
    });

    if (forceScrollIntoView ||
        _considerScrollAtBottom ||
        (_scroll.hasClients && _scroll.atScrollBottom)) {
      _scrollToBottom = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_scrollToBottom) {
      _scrollToBottom = false;
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (_scroll.hasClients) {
          unawaited(_scroll.autoScrollToBottom());
        } else {
          // Set back to true to retry scrolling when we are back in view.
          // We expected to be in view after the frame but it turns out we were
          // not.
          _scrollToBottom = true;
        }
      });
    }
    return Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      key: _scrollBarKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
        child: SelectionArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(denseSpacing),
            itemCount: _currentLines.length + (widget.footer != null ? 1 : 0),
            controller: _scroll,
            // Scroll physics to try to keep content within view and avoid bouncing.
            physics: const ClampingScrollPhysics(
              parent: RangeMaintainingScrollPhysics(),
            ),
            separatorBuilder: (_, __) {
              return const PaddedDivider.noPadding();
            },
            itemBuilder: (context, index) {
              if (index == _currentLines.length && widget.footer != null) {
                return widget.footer!;
              }
              final line = _currentLines[index];
              if (line is TextConsoleLine) {
                return Text.rich(
                  TextSpan(
                    // TODO(jacobr): consider caching the processed ansi terminal
                    // codes.
                    children: processAnsiTerminalCodes(
                      line.text,
                      theme.regularTextStyle,
                    ),
                  ),
                );
              } else if (line is VariableConsoleLine) {
                return ExpandableVariable(
                  variable: line.variable,
                  isSelectable: false,
                );
              } else {
                assert(
                  false,
                  'ConsoleLine of unsupported type ${line.runtimeType} encountered',
                );
                return const SizedBox();
              }
            },
          ),
        ),
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
    super.key,
    this.onPressed,
    this.tooltip = 'Clear contents',
    this.buttonKey,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final Key? buttonKey;

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
