// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../debugger/debugger_controller.dart';
import '../debugger/variables.dart';
import '../primitives/auto_dispose_mixin.dart';
import '../primitives/utils.dart';
import 'common_widgets.dart';
import 'console_service.dart';
import 'theme.dart';

// TODO(devoncarew): Allow scrolling horizontally as well.

// TODO(devoncarew): Support hyperlinking to stack traces.

/// Renders a ConsoleOutput widget with ConsoleControls overlaid on the
/// top-right corner.
class Console extends StatelessWidget {
  const Console({
    this.controls = const <Widget>[],
    required this.lines,
    this.title,
    this.footer,
  }) : super();

  final Widget? title;
  final Widget? footer;
  final List<Widget> controls;
  final ValueListenable<List<ConsoleLine>> lines;

  @visibleForTesting
  String get textContent => lines.value.join('\n');

  @override
  Widget build(BuildContext context) {
    return ConsoleFrame(
      controls: controls,
      title: title,
      child: _ConsoleOutput(lines: lines, footer: footer),
    );
  }
}

class ConsoleFrame extends StatelessWidget {
  const ConsoleFrame({
    this.controls = const <Widget>[],
    required this.child,
    this.title,
  }) : super();

  final Widget? title;
  final Widget child;
  final List<Widget> controls;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) title!,
        Expanded(
          child: Material(
            child: Stack(
              children: [
                child,
                if (controls.isNotEmpty)
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
    required this.controls,
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

  late DebuggerController _debuggerController;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _debuggerController = Provider.of<DebuggerController>(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_scrollToBottom) {
      _scrollToBottom = false;
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (_scroll.hasClients) {
          _scroll.autoScrollToBottom();
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
      isAlwaysShown: true,
      key: _scrollBarKey,
      child: ListView.separated(
        padding: const EdgeInsets.all(denseSpacing),
        itemCount: _currentLines.length + (widget.footer != null ? 1 : 0),
        controller: _scroll,
        // Scroll physics to try to keep content within view and avoid bouncing.
        physics: const ClampingScrollPhysics(
          parent: RangeMaintainingScrollPhysics(),
        ),
        separatorBuilder: (_, __) {
          return const Divider();
        },
        itemBuilder: (context, index) {
          if (index == _currentLines.length && widget.footer != null) {
            return widget.footer!;
          }
          final line = _currentLines[index];
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
              variable: line.variable,
              debuggerController: _debuggerController,
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
