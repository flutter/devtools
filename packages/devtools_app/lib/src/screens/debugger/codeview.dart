// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../shared/common_widgets.dart';
import '../../shared/config_specific/logger/logger.dart';
import '../../shared/console/primitives/source_location.dart';
import '../../shared/console/widgets/expandable_variable.dart';
import '../../shared/dialogs.dart';
import '../../shared/globals.dart';
import '../../shared/history_viewport.dart';
import '../../shared/object_tree.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/flutter_widgets/linked_scroll_controller.dart';
import '../../shared/primitives/listenable.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/theme.dart';
import '../../shared/ui/colors.dart';
import '../../shared/ui/hover.dart';
import '../../shared/ui/search.dart';
import '../../shared/ui/utils.dart';
import '../../shared/utils.dart';
import '../vm_developer/vm_service_private_extensions.dart';
import 'breakpoints.dart';
import 'codeview_controller.dart';
import 'common.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';
import 'file_search.dart';
import 'key_sets.dart';

final debuggerCodeViewSearchKey =
    GlobalKey(debugLabel: 'DebuggerCodeViewSearchKey');

final debuggerCodeViewFileOpenerKey =
    GlobalKey(debugLabel: 'DebuggerCodeViewFileOpenerKey');

// TODO(kenz): consider moving lines / pausedPositions calculations to the
// controller.
class CodeView extends StatefulWidget {
  const CodeView({
    Key? key,
    required this.codeViewController,
    required this.scriptRef,
    required this.parsedScript,
    this.debuggerController,
    this.lineRange,
    this.initialPosition,
    this.onSelected,
    this.enableFileExplorer = true,
    this.enableSearch = true,
    this.enableHistory = true,
  }) : super(key: key);

  static const debuggerCodeViewHorizontalScrollbarKey =
      Key('debuggerCodeViewHorizontalScrollbarKey');

  static const debuggerCodeViewVerticalScrollbarKey =
      Key('debuggerCodeViewVerticalScrollbarKey');

  static double get rowHeight => scaleByFontFactor(20.0);

  final CodeViewController codeViewController;
  final DebuggerController? debuggerController;
  final ScriptLocation? initialPosition;
  final ScriptRef? scriptRef;
  final ParsedScript? parsedScript;
  // TODO(bkonyi): consider changing this to (or adding support for)
  // `highlightedLineRange`, which would tell the code view to display the
  // the script's source in its entirety, with lines outside of the range being
  // rendered as if they have been greyed out.
  final LineRange? lineRange;
  final bool enableFileExplorer;
  final bool enableSearch;
  final bool enableHistory;

  final void Function(ScriptRef scriptRef, int line)? onSelected;

  @override
  _CodeViewState createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView>
    with AutoDisposeMixin, SearchFieldMixin<CodeView> {
  static const searchFieldRightPadding = 75.0;

  late final LinkedScrollControllerGroup verticalController;
  late final ScrollController gutterController;
  ScrollController? profileController;
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
    // TODO(jacobr): this lint does not understand that some methods have side
    // effects.
    // ignore: prefer-moving-to-variable
    gutterController = verticalController.addAndGet();
    // TODO(jacobr): this lint does not understand that some methods have side
    // effects.
    // ignore: prefer-moving-to-variable
    textController = verticalController.addAndGet();
    if (widget.codeViewController.showProfileInformation.value) {
      // TODO(jacobr): this lint does not understand that some methods have side
      // effects.
      // ignore: prefer-moving-to-variable
      profileController = verticalController.addAndGet();
    }
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
      widget.codeViewController.scriptLocation,
      _handleScriptLocationChanged,
    );

    // Create and dispose the controller used for the profile information
    // gutter to ensure that the scroll position is kept in sync with the main
    // gutter and code view when the widget is toggled on/off. If we don't do
    // this, the profile information gutter will always be at position 0 when
    // first enabled until the user scrolls.
    addAutoDisposeListener(
      widget.codeViewController.showProfileInformation,
      () {
        if (widget.codeViewController.showProfileInformation.value) {
          profileController = verticalController.addAndGet();
        } else {
          profileController!.dispose();
          profileController = null;
        }
      },
    );
  }

  @override
  void didUpdateWidget(CodeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.codeViewController != oldWidget.codeViewController) {
      cancelListeners();

      addAutoDisposeListener(
        widget.codeViewController.scriptLocation,
        _handleScriptLocationChanged,
      );
    }
  }

  @override
  void dispose() {
    gutterController.dispose();
    profileController?.dispose();
    textController.dispose();
    horizontalController.dispose();
    widget.codeViewController.scriptLocation
        .removeListener(_handleScriptLocationChanged);
    super.dispose();
  }

  void _handleScriptLocationChanged() {
    if (mounted) {
      _updateScrollPosition();
    }
  }

  void _updateScrollPosition({bool animate = true}) {
    if (widget.codeViewController.scriptLocation.value?.scriptRef.uri !=
        scriptRef?.uri) {
      return;
    }

    void updateScrollPositionImpl() {
      if (!verticalController.hasAttachedControllers) {
        // TODO(devoncarew): I'm uncertain why this occurs.
        log('LinkedScrollControllerGroup has no attached controllers');
        return;
      }
      final line =
          widget.codeViewController.scriptLocation.value?.location?.line;
      if (line == null) {
        // Don't scroll to top if we're just rebuilding the code view for the
        // same script.
        if (_lastScriptRef?.uri != scriptRef?.uri) {
          // Default to scrolling to the top of the script.
          if (animate) {
            unawaited(
              verticalController.animateTo(
                0,
                duration: longDuration,
                curve: defaultCurve,
              ),
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
        final scrollPosition = lineIndex * CodeView.rowHeight -
            ((extent - CodeView.rowHeight) / 2);
        if (animate) {
          unawaited(
            verticalController.animateTo(
              scrollPosition,
              duration: longDuration,
              curve: defaultCurve,
            ),
          );
        } else {
          verticalController.jumpTo(scrollPosition);
        }
      }
      _lastScriptRef = scriptRef;
    }

    verticalController.hasAttachedControllers
        ? updateScrollPositionImpl()
        : WidgetsBinding.instance.addPostFrameCallback(
            (_) => updateScrollPositionImpl(),
          );
  }

  @override
  Widget build(BuildContext context) {
    if (parsedScript == null) {
      return const CenteredCircularProgressIndicator();
    }

    return DualValueListenableBuilder<bool, bool>(
      firstListenable: widget.enableFileExplorer
          ? widget.codeViewController.showFileOpener
          : const FixedValueListenable<bool>(false),
      secondListenable: widget.enableSearch
          ? widget.codeViewController.showSearchInFileField
          : const FixedValueListenable<bool>(false),
      builder: (context, showFileOpener, showSearch, _) {
        return Stack(
          children: [
            scriptRef == null
                ? CodeViewEmptyState(widget: widget, context: context)
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
        final highlighted = script.highlighter.highlight(
          context,
          lineRange: widget.lineRange,
        );

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

    _updateScrollPosition(animate: false);

    final contentBuilder = (context, ScriptRef? script) {
      if (lines.isNotEmpty) {
        return DefaultTextStyle(
          style: theme.fixedFontStyle,
          child: Scrollbar(
            key: CodeView.debuggerCodeViewVerticalScrollbarKey,
            controller: textController,
            thumbVisibility: true,
            // Only listen for vertical scroll notifications (ignore those
            // from the nested horizontal SingleChildScrollView):
            notificationPredicate: (ScrollNotification notification) =>
                notification.depth == 1,
            child: ValueListenableBuilder<StackFrameAndSourcePosition?>(
              valueListenable: widget.debuggerController?.selectedStackFrame ??
                  const FixedValueListenable<StackFrameAndSourcePosition?>(
                    null,
                  ),
              builder: (context, frame, _) {
                final pausedFrame = frame == null
                    ? null
                    : (frame.scriptRef == scriptRef ? frame : null);
                return Row(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable:
                          widget.codeViewController.showProfileInformation,
                      builder: (context, showProfileInformation, _) {
                        return Gutters(
                          scriptRef: script,
                          gutterController: gutterController,
                          profileController: profileController,
                          codeViewController: widget.codeViewController,
                          debuggerController: widget.debuggerController,
                          lines: lines,
                          lineRange: widget.lineRange,
                          onSelected: widget.onSelected,
                          pausedFrame: pausedFrame,
                          parsedScript: parsedScript,
                          showProfileInformation: showProfileInformation,
                        );
                      },
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double fileWidth = calculateTextSpanWidth(
                            findLongestTextSpan(lines),
                          );

                          return Scrollbar(
                            key:
                                CodeView.debuggerCodeViewHorizontalScrollbarKey,
                            thumbVisibility: true,
                            controller: horizontalController,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: horizontalController,
                              child: SizedBox(
                                height: constraints.maxHeight,
                                width: math.max(
                                  constraints.maxWidth,
                                  fileWidth,
                                ),
                                child: Lines(
                                  height: constraints.maxHeight,
                                  codeViewController: widget.codeViewController,
                                  scrollController: textController,
                                  lines: lines,
                                  pausedFrame: pausedFrame,
                                  searchMatchesNotifier:
                                      widget.codeViewController.searchMatches,
                                  activeSearchMatchNotifier: widget
                                      .codeViewController.activeSearchMatch,
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
        );
      } else {
        return Center(
          child: Text(
            'No source available',
            style: theme.textTheme.titleMedium,
          ),
        );
      }
    };
    if (widget.enableHistory) {
      return HistoryViewport(
        history: widget.codeViewController.scriptsHistory,
        generateTitle: (ScriptRef? script) {
          final scriptUri = script?.uri;
          if (scriptUri == null) return '';
          return scriptUri;
        },
        onTitleTap: () =>
            widget.codeViewController.toggleFileOpenerVisibility(true),
        controls: [
          ScriptPopupMenu(widget.codeViewController),
          ScriptHistoryPopupMenu(
            itemBuilder: _buildScriptMenuFromHistory,
            onSelected: (scriptRef) {
              widget.codeViewController
                  .showScriptLocation(ScriptLocation(scriptRef));
            },
            enabled: widget.codeViewController.scriptsHistory.hasScripts,
          ),
        ],
        contentBuilder: (context, ScriptRef? scriptRef) {
          return Expanded(
            child: contentBuilder(context, scriptRef),
          );
        },
      );
    }
    return contentBuilder(context, widget.scriptRef);
  }

  Widget buildFileSearchField() {
    return ElevatedCard(
      key: debuggerCodeViewFileOpenerKey,
      width: extraWideSearchTextWidth,
      height: defaultTextFieldHeight,
      padding: EdgeInsets.zero,
      child: FileSearchField(
        codeViewController: widget.codeViewController,
      ),
    );
  }

  Widget buildSearchInFileField() {
    return ElevatedCard(
      width: wideSearchTextWidth,
      height: defaultTextFieldHeight + 2 * denseSpacing,
      child: buildSearchField(
        controller: widget.codeViewController,
        searchFieldKey: debuggerCodeViewSearchKey,
        searchFieldEnabled: parsedScript != null,
        shouldRequestFocus: true,
        supportsNavigation: true,
        onClose: () =>
            widget.codeViewController.toggleSearchInFileVisibility(false),
      ),
    );
  }

  List<PopupMenuEntry<ScriptRef>> _buildScriptMenuFromHistory(
    BuildContext context,
  ) {
    const scriptHistorySize = 16;

    return widget.codeViewController.scriptsHistory.openedScripts
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

class CodeViewEmptyState extends StatelessWidget {
  const CodeViewEmptyState({
    super.key,
    required this.widget,
    required this.context,
  });

  final CodeView widget;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ElevatedButton(
        autofocus: true,
        onPressed: () =>
            widget.codeViewController.toggleFileOpenerVisibility(true),
        child: Text(
          'Open a file ($openFileKeySetDescription)',
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}

class ProfileInformationGutter extends StatelessWidget {
  const ProfileInformationGutter({
    required this.scrollController,
    required this.lineOffset,
    required this.lineCount,
    required this.sourceReport,
  });

  final ScrollController scrollController;
  final int lineOffset;
  final int lineCount;
  final ProcessedSourceReport sourceReport;

  static const totalTimeTooltip =
      'Percent of time that a sampled line spent executing its own\n code as '
      'well as the code for any methods it called.';

  static const selfTimeTooltip =
      'Percent of time that a sampled line spent executing only its own code.';

  @override
  Widget build(BuildContext context) {
    // Gutter width accounts for:
    //  - a maximum of 16 characters of text (e.g., '100.00 %' x 2)
    //  - Spacing for the vertical divider
    final gutterWidth = assumedMonospaceCharacterWidth * 16 + denseSpacing;
    return OutlineDecoration.onlyRight(
      child: Container(
        width: gutterWidth,
        decoration: BoxDecoration(
          color: Theme.of(context).titleSolidBackgroundColor,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                const _ProfileInformationGutterHeader(
                  totalTimeTooltip: totalTimeTooltip,
                  selfTimeTooltip: selfTimeTooltip,
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemExtent: CodeView.rowHeight,
                    itemCount: lineCount,
                    itemBuilder: (context, index) {
                      final lineNum = lineOffset + index + 1;
                      final data = sourceReport.profilerEntries[lineNum];
                      if (data == null) {
                        return const SizedBox();
                      }
                      return ProfileInformationGutterItem(
                        lineNumber: lineNum,
                        profilerData: data,
                      );
                    },
                  ),
                ),
              ],
            ),
            const Center(
              child: VerticalDivider(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInformationGutterHeader extends StatelessWidget {
  const _ProfileInformationGutterHeader({
    required this.totalTimeTooltip,
    required this.selfTimeTooltip,
  });

  final String totalTimeTooltip;
  final String selfTimeTooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: CodeView.rowHeight,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: DevToolsTooltip(
                    message: totalTimeTooltip,
                    child: const Text(
                      'Total %',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: denseSpacing),
                Expanded(
                  child: DevToolsTooltip(
                    message: selfTimeTooltip,
                    child: const Text(
                      'Self %',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 0,
          ),
        ],
      ),
    );
  }
}

class ProfileInformationGutterItem extends StatelessWidget {
  const ProfileInformationGutterItem({
    Key? key,
    required this.lineNumber,
    required this.profilerData,
  }) : super(key: key);

  final int lineNumber;

  final ProfileReportEntry profilerData;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: CodeView.rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ProfilePercentageItem(
              percentage: profilerData.inclusivePercentage,
              hoverText: ProfileInformationGutter.totalTimeTooltip,
            ),
          ),
          Expanded(
            child: ProfilePercentageItem(
              percentage: profilerData.exclusivePercentage,
              hoverText: ProfileInformationGutter.selfTimeTooltip,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePercentageItem extends StatelessWidget {
  const ProfilePercentageItem({
    required this.percentage,
    required this.hoverText,
  });

  final double percentage;
  final String hoverText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color? color;
    if (percentage > 5) {
      color = colorScheme.performanceHighImpactColor;
    } else if (percentage > 1) {
      color = colorScheme.performanceMediumImpactColor;
    } else {
      color = colorScheme.performanceLowImpactColor;
    }
    return DevToolsTooltip(
      message: hoverText,
      child: Container(
        color: color,
        padding: const EdgeInsets.symmetric(
          horizontal: densePadding,
        ),
        child: Text(
          '${percentage.toStringAsFixed(2)} %',
          textAlign: TextAlign.end,
        ),
      ),
    );
  }
}

typedef IntCallback = void Function(int value);

class Gutters extends StatelessWidget {
  const Gutters({
    required this.scriptRef,
    this.debuggerController,
    required this.codeViewController,
    required this.lines,
    required this.lineRange,
    required this.gutterController,
    required this.showProfileInformation,
    required this.profileController,
    required this.parsedScript,
    this.pausedFrame,
    this.onSelected,
  });

  final ScriptRef? scriptRef;
  final DebuggerController? debuggerController;
  final CodeViewController codeViewController;
  final ScrollController gutterController;
  final ScrollController? profileController;
  final StackFrameAndSourcePosition? pausedFrame;
  final List<TextSpan> lines;
  final LineRange? lineRange;
  final ParsedScript? parsedScript;
  final void Function(ScriptRef scriptRef, int line)? onSelected;
  final bool showProfileInformation;

  @override
  Widget build(BuildContext context) {
    final lineCount = lineRange?.size ?? lines.length;
    final lineOffset = (lineRange?.begin ?? 1) - 1;
    final sourceReport =
        parsedScript?.sourceReport ?? const ProcessedSourceReport.empty();

    // Apply the log change-of-base formula to get the max number of digits in
    // a line number. Add a character width space for:
    //   - each character in the longest line number
    //   - one for the breakpoint dot
    //   - two for the paused arrow
    final gutterWidth = assumedMonospaceCharacterWidth * 4 +
        assumedMonospaceCharacterWidth *
            (defaultEpsilon + math.log(math.max(lines.length, 100)) / math.ln10)
                .truncateToDouble();

    return Row(
      children: [
        DualValueListenableBuilder<List<BreakpointAndSourcePosition>, bool>(
          firstListenable: breakpointManager.breakpointsWithLocation,
          secondListenable: codeViewController.showCodeCoverage,
          builder: (context, breakpoints, showCodeCoverage, _) {
            return Gutter(
              gutterWidth: gutterWidth,
              scrollController: gutterController,
              lineCount: lineCount,
              lineOffset: lineOffset,
              pausedFrame: pausedFrame,
              breakpoints:
                  breakpoints.where((bp) => bp.scriptRef == scriptRef).toList(),
              executableLines: parsedScript?.executableLines ?? const <int>{},
              sourceReport: sourceReport,
              onPressed: _onPressed,
              // Disable dots for possible breakpoint locations.
              allowInteraction: !(debuggerController?.isSystemIsolate ?? false),
              showCodeCoverage: showCodeCoverage,
            );
          },
        ),
        const SizedBox(width: denseSpacing),
        !showProfileInformation
            ? const SizedBox()
            : Padding(
                padding: const EdgeInsets.only(right: denseSpacing),
                child: ProfileInformationGutter(
                  scrollController: profileController!,
                  lineCount: lineCount,
                  lineOffset: lineOffset,
                  sourceReport: sourceReport,
                ),
              ),
      ],
    );
  }

  void _onPressed(int line) {
    final onSelectedLocal = onSelected!;
    final script = scriptRef;
    if (onSelected != null && script != null) {
      onSelectedLocal(script, line);
    }
  }
}

class Gutter extends StatelessWidget {
  const Gutter({
    required this.gutterWidth,
    required this.scrollController,
    required this.lineOffset,
    required this.lineCount,
    required this.pausedFrame,
    required this.breakpoints,
    required this.executableLines,
    required this.onPressed,
    required this.allowInteraction,
    required this.sourceReport,
    required this.showCodeCoverage,
  });

  final double gutterWidth;
  final ScrollController scrollController;
  final int lineOffset;
  final int lineCount;
  final StackFrameAndSourcePosition? pausedFrame;
  final List<BreakpointAndSourcePosition> breakpoints;
  final Set<int> executableLines;
  final ProcessedSourceReport sourceReport;
  final IntCallback onPressed;
  final bool allowInteraction;
  final bool showCodeCoverage;

  @override
  Widget build(BuildContext context) {
    final bpLineSet = Set.from(breakpoints.map((bp) => bp.line));
    final theme = Theme.of(context);
    final coverageLines =
        sourceReport.coverageHitLines.union(sourceReport.coverageMissedLines);
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
          final lineNum = lineOffset + index + 1;
          bool? coverageHit;
          if (showCodeCoverage && coverageLines.contains(lineNum)) {
            coverageHit = sourceReport.coverageHitLines.contains(lineNum);
          }
          return GutterItem(
            lineNumber: lineNum,
            onPressed: () => onPressed(lineNum),
            isBreakpoint: bpLineSet.contains(lineNum),
            isExecutable: executableLines.contains(lineNum),
            isPausedHere: pausedFrame?.line == lineNum,
            allowInteraction: allowInteraction,
            coverageHit: coverageHit,
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
    required this.coverageHit,
  }) : super(key: key);

  final int lineNumber;

  final bool isBreakpoint;

  final bool isExecutable;

  final bool allowInteraction;

  final bool? coverageHit;

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
    Color? color;
    final hasCoverage = coverageHit;
    if (hasCoverage != null && isExecutable) {
      color = hasCoverage
          ? theme.colorScheme.coverageHitColor
          : theme.colorScheme.coverageMissColor;
    }
    return InkWell(
      onTap: onPressed,
      // Force usage of default mouse pointer when gutter interaction is
      // disabled.
      mouseCursor: allowInteraction ? null : SystemMouseCursors.basic,
      child: Container(
        color: color,
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
    required this.codeViewController,
    required this.scrollController,
    required this.lines,
    required this.pausedFrame,
    required this.searchMatchesNotifier,
    required this.activeSearchMatchNotifier,
  }) : super(key: key);

  final double height;
  final CodeViewController codeViewController;
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
          unawaited(
            widget.scrollController.animateTo(
              targetOffset,
              duration: defaultDuration,
              curve: defaultCurve,
            ),
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
        return ValueListenableBuilder<int>(
          valueListenable: widget.codeViewController.focusLine,
          builder: (context, focusLine, _) {
            final isFocusedLine = focusLine == lineNum;
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
  Future<HoverCardData?> _generateHoverCardData({
    required PointerEvent event,
    // TODO(jacobr): this needs to be ignored as this method is passed as a
    // callback.
    // ignore: avoid-unused-parameters
    required bool Function() isHoverStale,
  }) async {
    if (!controller.isPaused.value) return null;

    final word = wordForHover(
      event.localPosition.dx,
      widget.lineContents,
    );

    if (word != '') {
      try {
        final response = await controller.evalService.evalAtCurrentFrame(word);
        final isolateRef = controller.isolateRef.value;
        if (response is! InstanceRef) return null;
        final variable = DartObjectNode.fromValue(
          value: response,
          isolateRef: isolateRef,
        );
        await buildVariablesTree(variable);
        return HoverCardData(
          title: word,
          contents: Material(
            child: ExpandableVariable(
              variable: variable,
            ),
          ),
          width: LineItem._hoverWidth,
        );
      } catch (_) {
        // Silently fail and don't display a HoverCard.
        return null;
      }
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

  @override
  void dispose() {
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
                opacity: 0.5,
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
              ),
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

  Widget _hoverableLine() => HoverCardTooltip.async(
        enabled: () => true,
        asyncTimeout: 100,
        asyncGenerateHoverCardData: _generateHoverCardData,
        child: SelectableText.rich(
          searchAwareLineContents(),
          scrollPhysics: const NeverScrollableScrollPhysics(),
          maxLines: 1,
        ),
      );

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
    final searchMatchesToFind = List<SourceToken>.of(searchMatches)
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
}

class ScriptPopupMenu extends StatelessWidget {
  const ScriptPopupMenu(this._controller);

  final CodeViewController _controller;

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

  final void Function(BuildContext, CodeViewController) onSelected;

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
  onSelected: (_, controller) {
    unawaited(() async {
      await Clipboard.setData(
        ClipboardData(text: await fetchScriptLocationFullFilePath(controller)),
      );
    }());
  },
);

@visibleForTesting
Future<String?> fetchScriptLocationFullFilePath(
  CodeViewController controller,
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

void showGoToLineDialog(BuildContext context, CodeViewController controller) {
  unawaited(
    showDialog(
      context: context,
      builder: (context) => GoToLineDialog(controller),
    ),
  );
}

final goToLineOption = ScriptPopupMenuOption(
  label: 'Go to line number ($goToLineNumberKeySetDescription)',
  icon: Icons.list,
  onSelected: showGoToLineDialog,
);

void showFileOpener(BuildContext _, CodeViewController controller) {
  controller.toggleFileOpenerVisibility(true);
}

final openFileOption = ScriptPopupMenuOption(
  label: 'Open file ($openFileKeySetDescription)',
  icon: Icons.folder_open,
  onSelected: showFileOpener,
);

class GoToLineDialog extends StatelessWidget {
  const GoToLineDialog(this._codeViewController);

  final CodeViewController _codeViewController;

  @override
  Widget build(BuildContext context) {
    return DevToolsDialog(
      title: const DialogTitleText('Go To'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            autofocus: true,
            onSubmitted: (value) {
              final scriptRef =
                  _codeViewController.scriptLocation.value?.scriptRef;
              if (value.isNotEmpty && scriptRef != null) {
                Navigator.of(context).pop(dialogDefaultContext);
                final line = int.parse(value);
                _codeViewController.showScriptLocation(
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
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
        ],
      ),
      actions: const [
        DialogCancelButton(),
      ],
    );
  }
}
