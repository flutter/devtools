// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../config_specific/logger/logger.dart';
import '../dialogs.dart';
import '../flutter_widgets/linked_scroll_controller.dart';
import '../globals.dart';
import '../history_viewport.dart';
import '../theme.dart';
import '../ui/colors.dart';
import '../ui/search.dart';
import '../ui/utils.dart';
import '../utils.dart';
import 'breakpoints.dart';
import 'common.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';
import 'hover.dart';
import 'variables.dart';

final debuggerCodeViewSearchKey =
    GlobalKey(debugLabel: 'DebuggerCodeViewSearchKey');

// TODO(kenz): consider moving lines / pausedPositions calculations to the
// controller.
class CodeView extends StatefulWidget {
  const CodeView({
    Key key,
    this.controller,
    this.scriptRef,
    this.parsedScript,
    this.onSelected,
  }) : super(key: key);

  static double get rowHeight => scaleByFontFactor(20.0);
  static double get assumedCharacterWidth => scaleByFontFactor(16.0);

  final DebuggerController controller;
  final ScriptRef scriptRef;
  final ParsedScript parsedScript;

  final void Function(ScriptRef scriptRef, int line) onSelected;

  @override
  _CodeViewState createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView>
    with AutoDisposeMixin, SearchFieldMixin<CodeView> {
  static const searchFieldRightPadding = 75.0;

  LinkedScrollControllerGroup verticalController;
  ScrollController gutterController;
  ScrollController textController;

  ScriptRef get scriptRef => widget.scriptRef;

  ParsedScript get parsedScript => widget.parsedScript;

  @override
  void initState() {
    super.initState();

    verticalController = LinkedScrollControllerGroup();
    gutterController = verticalController.addAndGet();
    textController = verticalController.addAndGet();

    addAutoDisposeListener(
      widget.controller.scriptLocation,
      _handleScriptLocationChanged,
    );
  }

  @override
  void didUpdateWidget(CodeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      cancel();

      addAutoDisposeListener(
          widget.controller.scriptLocation, _handleScriptLocationChanged);
    }
  }

  @override
  void dispose() {
    gutterController.dispose();
    textController.dispose();
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
    if (widget.controller.scriptLocation.value?.scriptRef != scriptRef) {
      return;
    }

    final location = widget.controller.scriptLocation.value?.location;
    if (location?.line == null) {
      return;
    }

    if (!verticalController.hasAttachedControllers) {
      // TODO(devoncarew): I'm uncertain why this occurs.
      log('LinkedScrollControllerGroup has no attached controllers');
      return;
    }

    final position = verticalController.position;
    final extent = position.extentInside;

    // TODO(devoncarew): Adjust this so we don't scroll if we're already in the
    // middle third of the screen.
    if (parsedScript.lineCount * CodeView.rowHeight > extent) {
      // Scroll to the middle of the screen.
      final lineIndex = location.line - 1;
      final scrollPosition =
          lineIndex * CodeView.rowHeight - (extent - CodeView.rowHeight) / 2;
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
  }

  void _onPressed(int line) {
    widget.onSelected(scriptRef, line);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (scriptRef == null) {
      return Center(
        child: Text(
          'No script selected',
          style: theme.textTheme.subtitle1,
        ),
      );
    }

    if (parsedScript == null) {
      return const CenteredCircularProgressIndicator();
    }

    return ValueListenableBuilder(
      valueListenable: widget.controller.showSearchInFileField,
      builder: (context, showSearch, _) {
        return Stack(
          children: [
            buildCodeArea(context),
            if (showSearch)
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
    if (parsedScript.script.source != null) {
      if (parsedScript.script.source.length < 500000 &&
          parsedScript.highlighter != null) {
        final highlighted = parsedScript.highlighter.highlight(context);

        // Look for [TextSpan]s which only contain '\n' to manually break the
        // output from the syntax highlighter into individual lines.
        var currentLine = <TextSpan>[];
        highlighted.visitChildren((span) {
          currentLine.add(span);
          if (span.toPlainText() == '\n') {
            lines.add(
              TextSpan(
                style: theme.fixedFontStyle,
                children: currentLine,
              ),
            );
            currentLine = <TextSpan>[];
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
            for (final line in parsedScript.script.source.split('\n'))
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
      generateTitle: (script) => script.uri,
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
      contentBuilder: (context, script) {
        if (lines.isNotEmpty) {
          return DefaultTextStyle(
            style: theme.fixedFontStyle,
            child: Expanded(
              child: Scrollbar(
                controller: textController,
                child: ValueListenableBuilder<StackFrameAndSourcePosition>(
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
                              executableLines: parsedScript.executableLines,
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
                              return Lines(
                                constraints: constraints,
                                scrollController: textController,
                                lines: lines,
                                pausedFrame: pausedFrame,
                                searchMatchesNotifier:
                                    widget.controller.searchMatches,
                                activeSearchMatchNotifier:
                                    widget.controller.activeSearchMatch,
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

  Widget buildSearchInFileField() {
    return Card(
      elevation: defaultElevation,
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(defaultBorderRadius),
      ),
      child: Container(
        width: wideSearchTextWidth,
        height: defaultTextFieldHeight + 2 * denseSpacing,
        padding: const EdgeInsets.all(denseSpacing),
        child: buildSearchField(
          controller: widget.controller,
          searchFieldKey: debuggerCodeViewSearchKey,
          searchFieldEnabled: parsedScript != null,
          shouldRequestFocus: true,
          supportsNavigation: true,
          onClose: () => widget.controller.toggleSearchInFileVisibility(false),
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
              scriptRef.uri,
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
    @required this.gutterWidth,
    @required this.scrollController,
    @required this.lineCount,
    @required this.pausedFrame,
    @required this.breakpoints,
    @required this.executableLines,
    @required this.onPressed,
    @required this.allowInteraction,
  });

  final double gutterWidth;
  final ScrollController scrollController;
  final int lineCount;
  final StackFrameAndSourcePosition pausedFrame;
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
    Key key,
    @required this.lineNumber,
    @required this.isBreakpoint,
    @required this.isExecutable,
    @required this.isPausedHere,
    @required this.onPressed,
    @required this.allowInteraction,
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

    final foregroundColor = theme.isDarkTheme
        ? theme.textTheme.bodyText2.color
        : theme.primaryColor;
    final subtleColor = theme.unselectedWidgetColor;

    const bpBoxSize = 12.0;
    const executionPointIndent = 10.0;

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
                      isBreakpoint ? foregroundColor : subtleColor,
                    ),
                  ),
                ),
              ),
            Text('$lineNumber', textAlign: TextAlign.end),
            Container(
              padding: const EdgeInsets.only(left: executionPointIndent),
              alignment: Alignment.centerLeft,
              child: AnimatedOpacity(
                duration: defaultDuration,
                curve: defaultCurve,
                opacity: isPausedHere ? 1.0 : 0.0,
                child: Icon(
                  Icons.label,
                  size: defaultIconSize,
                  color: foregroundColor,
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
    Key key,
    @required this.constraints,
    @required this.scrollController,
    @required this.lines,
    @required this.pausedFrame,
    @required this.searchMatchesNotifier,
    @required this.activeSearchMatchNotifier,
  }) : super(key: key);

  final BoxConstraints constraints;
  final ScrollController scrollController;
  final List<TextSpan> lines;
  final StackFrameAndSourcePosition pausedFrame;
  final ValueListenable<List<SourceToken>> searchMatchesNotifier;
  final ValueListenable<SourceToken> activeSearchMatchNotifier;

  @override
  _LinesState createState() => _LinesState();
}

class _LinesState extends State<Lines> with AutoDisposeMixin {
  List<SourceToken> searchMatches;

  SourceToken activeSearch;

  @override
  void initState() {
    super.initState();

    cancel();
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

      if (activeSearch != null) {
        final isOutOfViewTop = activeSearch.position.line * CodeView.rowHeight <
            widget.scrollController.offset + CodeView.rowHeight;
        final isOutOfViewBottom =
            activeSearch.position.line * CodeView.rowHeight >
                widget.scrollController.offset +
                    widget.constraints.maxHeight -
                    CodeView.rowHeight;

        if (isOutOfViewTop || isOutOfViewBottom) {
          // Scroll this search token to the middle of the view.
          final targetOffset = math.max(
            activeSearch.position.line * CodeView.rowHeight -
                widget.constraints.maxHeight / 2,
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
        return LineItem(
          lineContents: widget.lines[index],
          pausedFrame: pausedLine == lineNum ? widget.pausedFrame : null,
          searchMatches: searchMatchesForLine(index),
          activeSearchMatch:
              activeSearch?.position?.line == index ? activeSearch : null,
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
    Key key,
    @required this.lineContents,
    this.pausedFrame,
    this.searchMatches,
    this.activeSearchMatch,
  }) : super(key: key);

  static const _hoverDelay = Duration(milliseconds: 150);
  static const _removeDelay = Duration(milliseconds: 50);
  static const _hoverWidth = 400.0;

  final TextSpan lineContents;
  final StackFrameAndSourcePosition pausedFrame;
  final List<SourceToken> searchMatches;
  final SourceToken activeSearchMatch;

  @override
  _LineItemState createState() => _LineItemState();
}

class _LineItemState extends State<LineItem> {
  /// A timer that shows a [HoverCard] with an evaluation result when completed.
  Timer _showTimer;

  /// A timer that removes a [HoverCard] when completed.
  Timer _removeTimer;

  /// Displays the evaluation result of a source code item.
  HoverCard _hoverCard;

  DebuggerController _debuggerController;

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
    if (!_debuggerController.isPaused.value) return;
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
          final response = await _debuggerController.evalAtCurrentFrame(word);
          final isolateRef = _debuggerController.isolateRef;
          if (response is! InstanceRef) return;
          final variable = Variable.fromValue(
            value: response,
            isolateRef: isolateRef,
          );
          await buildVariablesTree(variable);
          if (_hasMouseExited) return;
          _hoverCard?.remove();
          _hoverCard = HoverCard(
            contents: SingleChildScrollView(
              child: Container(
                constraints:
                    const BoxConstraints(maxHeight: maxHoverCardHeight),
                child: Material(
                  child: ExpandableVariable(
                    debuggerController: _debuggerController,
                    variable: ValueNotifier(variable),
                  ),
                ),
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
    _debuggerController = Provider.of<DebuggerController>(context);

    Widget child;
    if (widget.pausedFrame != null) {
      final column = widget.pausedFrame.column;

      final foregroundColor =
          darkTheme ? theme.textTheme.bodyText2.color : theme.primaryColor;

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
              // of the correct characters and styles would be risky as it leads
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
                    color: foregroundColor,
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

    final backgroundColor = widget.pausedFrame != null
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
    final activeSearchAwareContents =
        _activeSearchAwareLineContents(widget.lineContents.children);
    final allSearchAwareContents =
        _searchMatchAwareLineContents(activeSearchAwareContents);
    return TextSpan(
      children: allSearchAwareContents,
      style: widget.lineContents.style,
    );
  }

  List<TextSpan> _contentsWithMatch(
    List<TextSpan> startingContents,
    SourceToken match,
    Color matchColor,
  ) {
    final contentsWithMatch = <TextSpan>[];
    var startColumnForSpan = 0;
    for (final span in startingContents) {
      final spanText = span.toPlainText();
      final startColumnForMatch = match.position.column;
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

  List<TextSpan> _activeSearchAwareLineContents(
    List<TextSpan> startingContents,
  ) {
    if (widget.activeSearchMatch == null) return startingContents;
    return _contentsWithMatch(
      startingContents,
      widget.activeSearchMatch,
      activeSearchMatchColor,
    );
  }

  List<TextSpan> _searchMatchAwareLineContents(
    List<TextSpan> startingContents,
  ) {
    if (widget.searchMatches.isEmpty) return startingContents;
    final searchMatchesToFind = List<SourceToken>.from(widget.searchMatches)
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
      child: const Icon(
        Icons.more_vert,
        size: actionsIconSize,
      ),
    );
  }
}

class ScriptHistoryPopupMenu extends StatelessWidget {
  const ScriptHistoryPopupMenu({
    @required this.itemBuilder,
    @required this.onSelected,
    @required this.enabled,
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
      offset: const Offset(
        actionsIconSize + denseSpacing,
        buttonMinWidth + denseSpacing,
      ),
      child: const Icon(
        Icons.history,
        size: actionsIconSize,
      ),
    );
  }
}

class ScriptPopupMenuOption {
  const ScriptPopupMenuOption({
    @required this.label,
    @required this.onSelected,
    this.icon,
  });

  final String label;

  final void Function(BuildContext, DebuggerController) onSelected;

  final IconData icon;

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

final defaultScriptPopupMenuOptions = [copyScriptNameOption, goToLineOption];

final copyScriptNameOption = ScriptPopupMenuOption(
  label: 'Copy filename',
  icon: Icons.content_copy,
  onSelected: (_, controller) => Clipboard.setData(
    ClipboardData(text: controller.scriptLocation.value?.scriptRef?.uri),
  ),
);

void showGoToLineDialog(BuildContext context, DebuggerController controller) {
  showDialog(
    context: context,
    builder: (context) => GoToLineDialog(controller),
  );
}

const goToLineOption = ScriptPopupMenuOption(
  label: 'Go to line number',
  icon: Icons.list,
  onSelected: showGoToLineDialog,
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
              if (value.isNotEmpty) {
                Navigator.of(context).pop(dialogDefaultContext);
                final line = int.parse(value);
                _debuggerController.showScriptLocation(
                  ScriptLocation(
                    _debuggerController.scriptLocation.value.scriptRef,
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
