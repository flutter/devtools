// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../config_specific/logger/logger.dart';
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/flutter_widgets/linked_scroll_controller.dart';
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/dialogs.dart';
import '../../shared/globals.dart';
import '../../shared/history_viewport.dart';
import '../../shared/object_tree.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/colors.dart';
import '../../ui/hover.dart';
import '../../ui/search.dart';
import '../../ui/utils.dart';
import 'breakpoints.dart';
import 'common.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';
import 'file_search.dart';
import 'key_sets.dart';
import 'program_explorer_model.dart';
import 'variables.dart';

final debuggerCodeViewSearchKey =
    GlobalKey(debugLabel: 'DebuggerCodeViewSearchKey');

// TODO(kenz): consider moving lines / pausedPositions calculations to the
// controller.
class CodeView extends StatefulWidget {
  const CodeView({
    Key? key,
    required this.controller,
    this.initialPosition,
    this.scriptRef,
    this.parsedScript,
    this.onSelected,
  }) : super(key: key);

  static const debuggerCodeViewHorizontalScrollbarKey =
      Key('debuggerCodeViewHorizontalScrollbarKey');

  static const debuggerCodeViewVerticalScrollbarKey =
      Key('debuggerCodeViewVerticalScrollbarKey');

  static double get rowHeight => scaleByFontFactor(20.0);
  static double get assumedCharacterWidth => scaleByFontFactor(16.0);

  final DebuggerController controller;
  final ScriptLocation? initialPosition;
  final ScriptRef? scriptRef;
  final ParsedScript? parsedScript;

  final void Function(ScriptRef scriptRef, int line)? onSelected;

  @override
  _CodeViewState createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView>
    with AutoDisposeMixin, SearchFieldMixin<CodeView> {
  static const searchFieldRightPadding = 75.0;

  late final LinkedScrollControllerGroup verticalController;
  late final ScrollController gutterController;
  late final ScrollController textController;
  late final ScrollController horizontalController;

  ScriptRef? get scriptRef => widget.scriptRef;

  ParsedScript? get parsedScript => widget.parsedScript;

  ScriptLocation? get initialPosition => widget.initialPosition;

  // Used to ensure we don't update the scroll position when expanding or
  // collapsing the file explorer.
  ScriptRef? _lastScriptRef;

  @override
  void initState() {
    super.initState();

    verticalController = LinkedScrollControllerGroup();
    gutterController = verticalController.addAndGet();
    textController = verticalController.addAndGet();
    horizontalController = ScrollController();
    _lastScriptRef = widget.scriptRef;

    final lineCount = initialPosition?.location?.line;
    if (lineCount != null) {
      // Lines are 1-indexed. Scrolling to line 1 required a scroll position of
      // 0.
      final lineIndex = lineCount - 1;
      final scrollPosition = lineIndex * CodeView.rowHeight;
      verticalController.jumpTo(scrollPosition);
    }

    addAutoDisposeListener(
      widget.controller.scriptLocation,
      _handleScriptLocationChanged,
    );
  }

  @override
  void didUpdateWidget(CodeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      cancelListeners();

      addAutoDisposeListener(
        widget.controller.scriptLocation,
        _handleScriptLocationChanged,
      );
    }
  }

  @override
  void dispose() {
    gutterController.dispose();
    textController.dispose();
    horizontalController.dispose();
    widget.controller.scriptLocation
        .removeListener(_handleScriptLocationChanged);
    super.dispose();
  }

  void _handleScriptLocationChanged() {
    if (mounted) {
      _updateScrollPosition();
    }
  }

  void _updateScrollPosition({bool animate = true}) {
    if (widget.controller.scriptLocation.value?.scriptRef.uri !=
        scriptRef?.uri) {
      return;
    }

    if (!verticalController.hasAttachedControllers) {
      // TODO(devoncarew): I'm uncertain why this occurs.
      log('LinkedScrollControllerGroup has no attached controllers');
      return;
    }
    final line = widget.controller.scriptLocation.value?.location?.line;
    if (line == null) {
      // Don't scroll to top if we're just rebuilding the code view for the
      // same script.
      if (_lastScriptRef?.uri != scriptRef?.uri) {
        // Default to scrolling to the top of the script.
        if (animate) {
          verticalController.animateTo(
            0,
            duration: longDuration,
            curve: defaultCurve,
          );
        } else {
          verticalController.jumpTo(0);
        }
        _lastScriptRef = scriptRef;
      }
      return;
    }

    final position = verticalController.position;
    final extent = position.extentInside;

    // TODO(devoncarew): Adjust this so we don't scroll if we're already in the
    // middle third of the screen.
    final lineCount = parsedScript?.lineCount;
    if (lineCount != null && lineCount * CodeView.rowHeight > extent) {
      final lineIndex = line - 1;
      final scrollPosition =
          lineIndex * CodeView.rowHeight - ((extent - CodeView.rowHeight) / 2);
      if (animate) {
        verticalController.animateTo(
          scrollPosition,
          duration: longDuration,
          curve: defaultCurve,
        );
      } else {
        verticalController.jumpTo(scrollPosition);
      }
    }
    _lastScriptRef = scriptRef;
  }

  void _onPressed(int line) {
    final onSelected = widget.onSelected;
    final script = scriptRef;
    if (onSelected != null && script != null) {
      onSelected(script, line);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (parsedScript == null) {
      return const CenteredCircularProgressIndicator();
    }

    return DualValueListenableBuilder<bool, bool>(
      firstListenable: widget.controller.showFileOpener,
      secondListenable: widget.controller.showSearchInFileField,
      builder: (context, showFileOpener, showSearch, _) {
        return Stack(
          children: [
            scriptRef == null
                ? buildEmptyState(context)
                : buildCodeArea(context),
            if (showFileOpener)
              Positioned(
                left: noPadding,
                right: noPadding,
                child: buildFileSearchField(),
              ),
            if (showSearch && scriptRef != null)
              Positioned(
                top: denseSpacing,
                right: searchFieldRightPadding,
                child: buildSearchInFileField(),
              ),
          ],
        );
      },
    );
  }

  Widget buildCodeArea(BuildContext context) {
    final theme = Theme.of(context);

    final lines = <TextSpan>[];

    // Ensure the syntax highlighter has been initialized.
    // TODO(bkonyi): process source for highlighting on a separate thread.
    final script = parsedScript;
    final scriptSource = parsedScript?.script.source;
    if (script != null && scriptSource != null) {
      if (scriptSource.length < 500000) {
        final highlighted = script.highlighter.highlight(context);

        // Look for [InlineSpan]s which only contain '\n' to manually break the
        // output from the syntax highlighter into individual lines.
        var currentLine = <InlineSpan>[];
        highlighted.visitChildren((span) {
          currentLine.add(span);
          if (span.toPlainText() == '\n') {
            lines.add(
              TextSpan(
                style: theme.fixedFontStyle,
                children: currentLine,
              ),
            );
            currentLine = <InlineSpan>[];
          }
          return true;
        });
        lines.add(
          TextSpan(
            style: theme.fixedFontStyle,
            children: currentLine,
          ),
        );
      } else {
        lines.addAll(
          [
            for (final line in scriptSource.split('\n'))
              TextSpan(
                style: theme.fixedFontStyle,
                text: line,
              ),
          ],
        );
      }
    }

    // Apply the log change-of-base formula, then add 16dp padding for every
    // digit in the maximum number of lines.
    final gutterWidth = CodeView.assumedCharacterWidth * 1.5 +
        CodeView.assumedCharacterWidth *
            (defaultEpsilon + math.log(math.max(lines.length, 100)) / math.ln10)
                .truncateToDouble();

    _updateScrollPosition(animate: false);

    return HistoryViewport(
      history: widget.controller.scriptsHistory,
      generateTitle: (ScriptRef? script) {
        final scriptUri = script?.uri;
        if (scriptUri == null) return '';
        return scriptUri;
      },
      onTitleTap: () => widget.controller.toggleFileOpenerVisibility(true),
      controls: [
        ScriptPopupMenu(widget.controller),
        ScriptHistoryPopupMenu(
          itemBuilder: _buildScriptMenuFromHistory,
          onSelected: (scriptRef) {
            widget.controller.showScriptLocation(ScriptLocation(scriptRef));
          },
          enabled: widget.controller.scriptsHistory.hasScripts,
        ),
      ],
      contentBuilder: (context, ScriptRef? script) {
        if (lines.isNotEmpty) {
          return DefaultTextStyle(
            style: theme.fixedFontStyle,
            child: Expanded(
              child: Scrollbar(
                key: CodeView.debuggerCodeViewVerticalScrollbarKey,
                controller: textController,
                thumbVisibility: true,
                // Only listen for vertical scroll notifications (ignore those
                // from the nested horizontal SingleChildScrollView):
                notificationPredicate: (ScrollNotification notification) =>
                    notification.depth == 1,
                child: ValueListenableBuilder<StackFrameAndSourcePosition?>(
                  valueListenable: widget.controller.selectedStackFrame,
                  builder: (context, frame, _) {
                    final pausedFrame = frame == null
                        ? null
                        : (frame.scriptRef == scriptRef ? frame : null);

                    return Row(
                      children: [
                        ValueListenableBuilder<
                            List<BreakpointAndSourcePosition>>(
                          valueListenable:
                              widget.controller.breakpointsWithLocation,
                          builder: (context, breakpoints, _) {
                            return Gutter(
                              gutterWidth: gutterWidth,
                              scrollController: gutterController,
                              lineCount: lines.length,
                              pausedFrame: pausedFrame,
                              breakpoints: breakpoints
                                  .where((bp) => bp.scriptRef == scriptRef)
                                  .toList(),
                              executableLines: parsedScript != null
                                  ? parsedScript!.executableLines
                                  : <int>{},
                              onPressed: _onPressed,
                              // Disable dots for possible breakpoint locations.
                              allowInteraction:
                                  !widget.controller.isSystemIsolate,
                            );
                          },
                        ),
                        const SizedBox(width: denseSpacing),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double fileWidth = calculateTextSpanWidth(
                                findLongestTextSpan(lines),
                              );

                              return Scrollbar(
                                key: CodeView
                                    .debuggerCodeViewHorizontalScrollbarKey,
                                thumbVisibility: true,
                                controller: horizontalController,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  controller: horizontalController,
                                  child: SizedBox(
                                    height: constraints.maxHeight,
                                    width: fileWidth,
                                    child: Lines(
                                      height: constraints.maxHeight,
                                      debugController: widget.controller,
                                      scrollController: textController,
                                      lines: lines,
                                      pausedFrame: pausedFrame,
                                      searchMatchesNotifier:
                                          widget.controller.searchMatches,
                                      activeSearchMatchNotifier:
                                          widget.controller.activeSearchMatch,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        } else {
          return Expanded(
            child: Center(
              child: Text(
                'No source available',
                style: theme.textTheme.subtitle1,
              ),
            ),
          );
        }
      },
    );
  }

  Widget buildFileSearchField() {
    return ElevatedCard(
      child: FileSearchField(
        debuggerController: widget.controller,
      ),
      width: extraWideSearchTextWidth,
      height: defaultTextFieldHeight,
      padding: EdgeInsets.zero,
    );
  }

  Widget buildSearchInFileField() {
    return ElevatedCard(
      child: buildSearchField(
        controller: widget.controller,
        searchFieldKey: debuggerCodeViewSearchKey,
        searchFieldEnabled: parsedScript != null,
        shouldRequestFocus: true,
        supportsNavigation: true,
        onClose: () => widget.controller.toggleSearchInFileVisibility(false),
      ),
      width: wideSearchTextWidth,
      height: defaultTextFieldHeight + 2 * denseSpacing,
    );
  }

  Widget buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ElevatedButton(
        autofocus: true,
        onPressed: () => widget.controller.toggleFileOpenerVisibility(true),
        child: Text(
          'Open a file ($openFileKeySetDescription)',
          style: theme.textTheme.subtitle1,
        ),
      ),
    );
  }

  List<PopupMenuEntry<ScriptRef>> _buildScriptMenuFromHistory(
    BuildContext context,
  ) {
    const scriptHistorySize = 16;

    return widget.controller.scriptsHistory.openedScripts
        .take(scriptHistorySize)
        .map((scriptRef) {
      return PopupMenuItem(
        value: scriptRef,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ScriptRefUtils.fileName(scriptRef),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              scriptRef.uri ?? '',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context).subtleTextStyle,
            ),
          ],
        ),
      );
    }).toList();
  }
}

typedef IntCallback = void Function(int value);

class Gutter extends StatelessWidget {
  const Gutter({
    required this.gutterWidth,
    required this.scrollController,
    required this.lineCount,
    required this.pausedFrame,
    required this.breakpoints,
    required this.executableLines,
    required this.onPressed,
    required this.allowInteraction,
  });

  final double gutterWidth;
  final ScrollController scrollController;
  final int lineCount;
  final StackFrameAndSourcePosition? pausedFrame;
  final List<BreakpointAndSourcePosition> breakpoints;
  final Set<int> executableLines;
  final IntCallback onPressed;
  final bool allowInteraction;

  @override
  Widget build(BuildContext context) {
    final bpLineSet = Set.from(breakpoints.map((bp) => bp.line));
    final theme = Theme.of(context);
    return Container(
      width: gutterWidth,
      decoration: BoxDecoration(
        border: Border(right: defaultBorderSide(theme)),
        color: Theme.of(context).titleSolidBackgroundColor,
      ),
      child: ListView.builder(
        controller: scrollController,
        itemExtent: CodeView.rowHeight,
        itemCount: lineCount,
        itemBuilder: (context, index) {
          final lineNum = index + 1;
          return GutterItem(
            lineNumber: lineNum,
            onPressed: () => onPressed(lineNum),
            isBreakpoint: bpLineSet.contains(lineNum),
            isExecutable: executableLines.contains(lineNum),
            isPausedHere: pausedFrame?.line == lineNum,
            allowInteraction: allowInteraction,
          );
        },
      ),
    );
  }
}

class GutterItem extends StatelessWidget {
  const GutterItem({
    Key? key,
    required this.lineNumber,
    required this.isBreakpoint,
    required this.isExecutable,
    required this.isPausedHere,
    required this.onPressed,
    required this.allowInteraction,
  }) : super(key: key);

  final int lineNumber;

  final bool isBreakpoint;

  final bool isExecutable;

  final bool allowInteraction;

  /// Whether the execution point is currently paused here.
  final bool isPausedHere;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final breakpointColor = theme.colorScheme.breakpointColor;
    final subtleColor = theme.unselectedWidgetColor;

    final bpBoxSize = breakpointRadius * 2;
    final executionPointIndent = scaleByFontFactor(10.0);

    return InkWell(
      onTap: onPressed,
      // Force usage of default mouse pointer when gutter interaction is
      // disabled.
      mouseCursor: allowInteraction ? null : SystemMouseCursors.basic,
      child: Container(
        height: CodeView.rowHeight,
        padding: const EdgeInsets.only(right: 4.0),
        child: Stack(
          alignment: AlignmentDirectional.centerStart,
          fit: StackFit.expand,
          children: [
            if (allowInteraction && (isExecutable || isBreakpoint))
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: bpBoxSize,
                  height: bpBoxSize,
                  child: Center(
                    child: createAnimatedCircleWidget(
                      isBreakpoint ? breakpointRadius : executableLineRadius,
                      isBreakpoint ? breakpointColor : subtleColor,
                    ),
                  ),
                ),
              ),
            Text('$lineNumber', textAlign: TextAlign.end),
            Container(
              padding: EdgeInsets.only(left: executionPointIndent),
              alignment: Alignment.centerLeft,
              child: AnimatedOpacity(
                duration: defaultDuration,
                curve: defaultCurve,
                opacity: isPausedHere ? 1.0 : 0.0,
                child: Icon(
                  Icons.label,
                  size: defaultIconSize,
                  color: breakpointColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Lines extends StatefulWidget {
  const Lines({
    Key? key,
    required this.height,
    required this.debugController,
    required this.scrollController,
    required this.lines,
    required this.pausedFrame,
    required this.searchMatchesNotifier,
    required this.activeSearchMatchNotifier,
  }) : super(key: key);

  final double height;
  final DebuggerController debugController;
  final ScrollController scrollController;
  final List<TextSpan> lines;
  final StackFrameAndSourcePosition? pausedFrame;
  final ValueListenable<List<SourceToken>> searchMatchesNotifier;
  final ValueListenable<SourceToken?> activeSearchMatchNotifier;

  @override
  _LinesState createState() => _LinesState();
}

class _LinesState extends State<Lines> with AutoDisposeMixin {
  late List<SourceToken> searchMatches;

  SourceToken? activeSearch;

  @override
  void initState() {
    super.initState();

    cancelListeners();
    searchMatches = widget.searchMatchesNotifier.value;
    addAutoDisposeListener(widget.searchMatchesNotifier, () {
      setState(() {
        searchMatches = widget.searchMatchesNotifier.value;
      });
    });

    activeSearch = widget.activeSearchMatchNotifier.value;
    addAutoDisposeListener(widget.activeSearchMatchNotifier, () {
      setState(() {
        activeSearch = widget.activeSearchMatchNotifier.value;
      });

      final activeSearchLine = activeSearch?.position.line;
      if (activeSearchLine != null) {
        final isOutOfViewTop = activeSearchLine * CodeView.rowHeight <
            widget.scrollController.offset + CodeView.rowHeight;
        final isOutOfViewBottom = activeSearchLine * CodeView.rowHeight >
            widget.scrollController.offset + widget.height - CodeView.rowHeight;

        if (isOutOfViewTop || isOutOfViewBottom) {
          // Scroll this search token to the middle of the view.
          final targetOffset = math.max<double>(
            activeSearchLine * CodeView.rowHeight - widget.height / 2,
            0.0,
          );
          widget.scrollController.animateTo(
            targetOffset,
            duration: defaultDuration,
            curve: defaultCurve,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pausedLine = widget.pausedFrame?.line;
    return ListView.builder(
      controller: widget.scrollController,
      itemExtent: CodeView.rowHeight,
      itemCount: widget.lines.length,
      itemBuilder: (context, index) {
        final lineNum = index + 1;
        final isPausedLine = pausedLine == lineNum;
        return ValueListenableBuilder<VMServiceObjectNode?>(
          valueListenable:
              widget.debugController.programExplorerController.outlineSelection,
          builder: (context, outlineNode, _) {
            final isFocusedLine =
                (outlineNode?.location?.location?.line ?? -1) == lineNum;
            return LineItem(
              lineContents: widget.lines[index],
              pausedFrame: isPausedLine ? widget.pausedFrame : null,
              focused: isPausedLine || isFocusedLine,
              searchMatches: searchMatchesForLine(index),
              activeSearchMatch:
                  activeSearch?.position.line == index ? activeSearch : null,
            );
          },
        );
      },
    );
  }

  List<SourceToken> searchMatchesForLine(int index) {
    return searchMatches
        .where((searchToken) => searchToken.position.line == index)
        .toList();
  }
}

class LineItem extends StatefulWidget {
  const LineItem({
    Key? key,
    required this.lineContents,
    this.pausedFrame,
    this.focused = false,
    this.searchMatches,
    this.activeSearchMatch,
  }) : super(key: key);

  static const _hoverDelay = Duration(milliseconds: 150);
  static const _removeDelay = Duration(milliseconds: 50);
  static double get _hoverWidth => scaleByFontFactor(400.0);

  final TextSpan lineContents;
  final StackFrameAndSourcePosition? pausedFrame;
  final bool focused;
  final List<SourceToken>? searchMatches;
  final SourceToken? activeSearchMatch;

  @override
  _LineItemState createState() => _LineItemState();
}

class _LineItemState extends State<LineItem>
    with ProvidedControllerMixin<DebuggerController, LineItem> {
  /// A timer that shows a [HoverCard] with an evaluation result when completed.
  Timer? _showTimer;

  /// A timer that removes a [HoverCard] when completed.
  Timer? _removeTimer;

  /// Displays the evaluation result of a source code item.
  HoverCard? _hoverCard;

  String _previousHoverWord = '';
  bool _hasMouseExited = false;

  void _onHoverExit() {
    _showTimer?.cancel();
    _hasMouseExited = true;
    _removeTimer = Timer(LineItem._removeDelay, () {
      _hoverCard?.maybeRemove();
      _previousHoverWord = '';
    });
  }

  void _onHover(PointerHoverEvent event, BuildContext context) {
    _showTimer?.cancel();
    _removeTimer?.cancel();
    _hasMouseExited = false;
    if (!controller.isPaused.value) return;
    _showTimer = Timer(LineItem._hoverDelay, () async {
      final word = wordForHover(
        event.localPosition.dx,
        widget.lineContents,
      );
      if (word == _previousHoverWord) return;
      _previousHoverWord = word;
      _hoverCard?.remove();
      if (word != '') {
        try {
          final response = await controller.evalAtCurrentFrame(word);
          final isolateRef = controller.isolateRef;
          if (response is! InstanceRef) return;
          final variable = DartObjectNode.fromValue(
            value: response,
            isolateRef: isolateRef,
          );
          await buildVariablesTree(variable);
          if (_hasMouseExited) return;
          _hoverCard?.remove();
          _hoverCard = HoverCard.fromHoverEvent(
            contents: Material(
              child: ExpandableVariable(
                debuggerController: controller,
                variable: variable,
              ),
            ),
            event: event,
            width: LineItem._hoverWidth,
            title: word,
            context: context,
          );
        } catch (_) {
          // Silently fail and don't display a HoverCard.
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _removeTimer?.cancel();
    _hoverCard?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final darkTheme = theme.brightness == Brightness.dark;

    Widget child;
    final column = widget.pausedFrame?.column;
    if (column != null) {
      final breakpointColor = theme.colorScheme.breakpointColor;

      // The following constants are tweaked for using the
      // 'Icons.label_important' icon.
      const colIconSize = 13.0;
      const colLeftOffset = -3.0;
      const colBottomOffset = 13.0;
      const colIconRotate = -90 * math.pi / 180;

      // TODO: support selecting text across multiples lines.
      child = Stack(
        children: [
          Row(
            children: [
              // Create a hidden copy of the first column-1 characters of the
              // line as a hack to correctly compute where to place
              // the cursor. Approximating by using column-1 spaces instead
              // of the correct characters and style s would be risky as it leads
              // to small errors if the font is not fixed size or the font
              // styles vary depending on the syntax highlighting.
              // TODO(jacobr): there might be some api exposed on SelectedText
              // to allow us to render this as a proper overlay as similar
              // functionality exists to render the selection handles properly.
              Opacity(
                opacity: 0,
                child: RichText(
                  text: truncateTextSpan(widget.lineContents, column - 1),
                ),
              ),
              Transform.translate(
                offset: const Offset(colLeftOffset, colBottomOffset),
                child: Transform.rotate(
                  angle: colIconRotate,
                  child: Icon(
                    Icons.label_important,
                    size: colIconSize,
                    color: breakpointColor,
                  ),
                ),
              )
            ],
          ),
          _hoverableLine(),
        ],
      );
    } else {
      child = _hoverableLine();
    }

    final backgroundColor = widget.focused
        ? (darkTheme
            ? theme.canvasColor.brighten()
            : theme.canvasColor.darken())
        : null;

    return Container(
      alignment: Alignment.centerLeft,
      height: CodeView.rowHeight,
      color: backgroundColor,
      child: child,
    );
  }

  TextSpan searchAwareLineContents() {
    final children = widget.lineContents.children;
    if (children == null) return const TextSpan();

    final activeSearchAwareContents = _activeSearchAwareLineContents(children);
    final allSearchAwareContents =
        _searchMatchAwareLineContents(activeSearchAwareContents!);
    return TextSpan(
      children: allSearchAwareContents,
      style: widget.lineContents.style,
    );
  }

  List<InlineSpan> _contentsWithMatch(
    List<InlineSpan> startingContents,
    SourceToken match,
    Color matchColor,
  ) {
    final contentsWithMatch = <InlineSpan>[];
    var startColumnForSpan = 0;
    for (final span in startingContents) {
      final spanText = span.toPlainText();
      final startColumnForMatch = match.position.column!;
      if (startColumnForSpan <= startColumnForMatch &&
          startColumnForSpan + spanText.length > startColumnForMatch) {
        // The active search is part of this [span].
        final matchStartInSpan = startColumnForMatch - startColumnForSpan;
        final matchEndInSpan = matchStartInSpan + match.length;

        // Add the part of [span] that occurs before the search match.
        contentsWithMatch.add(
          TextSpan(
            text: spanText.substring(0, matchStartInSpan),
            style: span.style,
          ),
        );

        final matchStyle =
            (span.style ?? DefaultTextStyle.of(context).style).copyWith(
          color: Colors.black,
          backgroundColor: matchColor,
        );

        if (matchEndInSpan <= spanText.length) {
          final matchText =
              spanText.substring(matchStartInSpan, matchEndInSpan);
          final trailingText = spanText.substring(matchEndInSpan);
          // Add the match and any part of [span] that occurs after the search
          // match.
          contentsWithMatch.addAll([
            TextSpan(
              text: matchText,
              style: matchStyle,
            ),
            if (trailingText.isNotEmpty)
              TextSpan(
                text: spanText.substring(matchEndInSpan),
                style: span.style,
              ),
          ]);
        } else {
          // In this case, the active search match exists across multiple spans,
          // so we need to add the part of the match that is in this [span] and
          // continue looking for the remaining part of the match in the spans
          // to follow.
          contentsWithMatch.add(
            TextSpan(
              text: spanText.substring(matchStartInSpan),
              style: matchStyle,
            ),
          );
          final remainingMatchLength =
              match.length - (spanText.length - matchStartInSpan);
          match = SourceToken(
            position: SourcePosition(
              line: match.position.line,
              column: startColumnForMatch + match.length - remainingMatchLength,
            ),
            length: remainingMatchLength,
          );
        }
      } else {
        contentsWithMatch.add(span);
      }
      startColumnForSpan += spanText.length;
    }
    return contentsWithMatch;
  }

  List<InlineSpan>? _activeSearchAwareLineContents(
    List<InlineSpan> startingContents,
  ) {
    final activeSearchMatch = widget.activeSearchMatch;
    if (activeSearchMatch == null) return startingContents;
    return _contentsWithMatch(
      startingContents,
      activeSearchMatch,
      activeSearchMatchColor,
    );
  }

  List<InlineSpan> _searchMatchAwareLineContents(
    List<InlineSpan> startingContents,
  ) {
    final searchMatches = widget.searchMatches;
    if (searchMatches == null || searchMatches.isEmpty) return startingContents;
    final searchMatchesToFind = List<SourceToken>.from(searchMatches)
      ..remove(widget.activeSearchMatch);

    var contentsWithMatch = startingContents;
    for (final match in searchMatchesToFind) {
      contentsWithMatch = _contentsWithMatch(
        contentsWithMatch,
        match,
        searchMatchColor,
      );
    }
    return contentsWithMatch;
  }

  Widget _hoverableLine() => MouseRegion(
        onExit: (_) => _onHoverExit(),
        onHover: (e) => _onHover(e, context),
        child: SelectableText.rich(
          searchAwareLineContents(),
          scrollPhysics: const NeverScrollableScrollPhysics(),
          maxLines: 1,
        ),
      );
}

class ScriptPopupMenu extends StatelessWidget {
  const ScriptPopupMenu(this._controller);

  final DebuggerController _controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ScriptPopupMenuOption>(
      onSelected: (option) => option.onSelected(context, _controller),
      itemBuilder: (_) => [
        for (final menuOption in defaultScriptPopupMenuOptions)
          menuOption.build(context),
        for (final extensionMenuOption in devToolsExtensionPoints
            .buildExtraDebuggerScriptPopupMenuOptions())
          extensionMenuOption.build(context),
      ],
      child: Icon(
        Icons.more_vert,
        size: actionsIconSize,
      ),
    );
  }
}

class ScriptHistoryPopupMenu extends StatelessWidget {
  const ScriptHistoryPopupMenu({
    required this.itemBuilder,
    required this.onSelected,
    required this.enabled,
  });

  final PopupMenuItemBuilder<ScriptRef> itemBuilder;

  final void Function(ScriptRef) onSelected;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ScriptRef>(
      itemBuilder: itemBuilder,
      tooltip: 'Select recent script',
      enabled: enabled,
      onSelected: onSelected,
      offset: Offset(
        actionsIconSize + denseSpacing,
        buttonMinWidth + denseSpacing,
      ),
      child: Icon(
        Icons.history,
        size: actionsIconSize,
      ),
    );
  }
}

class ScriptPopupMenuOption {
  const ScriptPopupMenuOption({
    required this.label,
    required this.onSelected,
    this.icon,
  });

  final String label;

  final void Function(BuildContext, DebuggerController) onSelected;

  final IconData? icon;

  PopupMenuItem<ScriptPopupMenuOption> build(BuildContext context) {
    return PopupMenuItem<ScriptPopupMenuOption>(
      value: this,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).regularTextStyle),
          if (icon != null)
            Icon(
              icon,
              size: actionsIconSize,
            ),
        ],
      ),
    );
  }
}

final defaultScriptPopupMenuOptions = [
  copyPackagePathOption,
  copyFilePathOption,
  goToLineOption,
  openFileOption,
];

final copyPackagePathOption = ScriptPopupMenuOption(
  label: 'Copy package path',
  icon: Icons.content_copy,
  onSelected: (_, controller) => Clipboard.setData(
    ClipboardData(text: controller.scriptLocation.value?.scriptRef.uri),
  ),
);

final copyFilePathOption = ScriptPopupMenuOption(
  label: 'Copy file path',
  icon: Icons.content_copy,
  onSelected: (_, controller) async {
    return Clipboard.setData(
      ClipboardData(text: await fetchScriptLocationFullFilePath(controller)),
    );
  },
);

@visibleForTesting
Future<String?> fetchScriptLocationFullFilePath(
  DebuggerController controller,
) async {
  String? filePath;
  final packagePath = controller.scriptLocation.value!.scriptRef.uri;
  if (packagePath != null) {
    final isolateId = serviceManager.isolateManager.selectedIsolate.value!.id!;
    filePath = serviceManager.resolvedUriManager.lookupFileUri(
      isolateId,
      packagePath,
    );
    if (filePath == null) {
      await serviceManager.resolvedUriManager.fetchFileUris(
        isolateId,
        [packagePath],
      );
      filePath = serviceManager.resolvedUriManager.lookupFileUri(
        isolateId,
        packagePath,
      );
    }
  }
  return filePath;
}

void showGoToLineDialog(BuildContext context, DebuggerController controller) {
  showDialog(
    context: context,
    builder: (context) => GoToLineDialog(controller),
  );
}

final goToLineOption = ScriptPopupMenuOption(
  label: 'Go to line number ($goToLineNumberKeySetDescription)',
  icon: Icons.list,
  onSelected: showGoToLineDialog,
);

void showFileOpener(BuildContext context, DebuggerController controller) {
  controller.toggleFileOpenerVisibility(true);
}

final openFileOption = ScriptPopupMenuOption(
  label: 'Open file ($openFileKeySetDescription)',
  icon: Icons.folder_open,
  onSelected: showFileOpener,
);

class GoToLineDialog extends StatelessWidget {
  const GoToLineDialog(this._debuggerController);

  final DebuggerController _debuggerController;

  @override
  Widget build(BuildContext context) {
    return DevToolsDialog(
      title: dialogTitleText(Theme.of(context), 'Go To'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            autofocus: true,
            onSubmitted: (value) {
              final scriptRef =
                  _debuggerController.scriptLocation.value?.scriptRef;
              if (value.isNotEmpty && scriptRef != null) {
                Navigator.of(context).pop(dialogDefaultContext);
                final line = int.parse(value);
                _debuggerController.showScriptLocation(
                  ScriptLocation(
                    scriptRef,
                    location: SourcePosition(line: line, column: 0),
                  ),
                );
              }
            },
            decoration: InputDecoration(
              labelText: 'Line Number',
              contentPadding: EdgeInsets.all(scaleByFontFactor(5.0)),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly
            ],
          )
        ],
      ),
      actions: const [
        DialogCancelButton(),
      ],
    );
  }
}
