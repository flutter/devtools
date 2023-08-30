// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../shared/common_widgets.dart';
import '../../shared/console/widgets/expandable_variable.dart';
import '../../shared/diagnostics/dart_object_node.dart';
import '../../shared/diagnostics/primitives/source_location.dart';
import '../../shared/diagnostics/tree_builder.dart';
import '../../shared/globals.dart';
import '../../shared/history_viewport.dart';
import '../../shared/primitives/flutter_widgets/linked_scroll_controller.dart';
import '../../shared/primitives/listenable.dart';
import '../../shared/primitives/utils.dart';
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

final _log = Logger('codeview');

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

  static double get rowHeight =>
      isDense() ? scaleByFontFactor(16.0) : scaleByFontFactor(20.0);

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
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> with AutoDisposeMixin {
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
    gutterController = verticalController.addAndGet();
    textController = verticalController.addAndGet();
    if (widget.codeViewController.showProfileInformation.value) {
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
      widget.codeViewController.initSearch();
      addAutoDisposeListener(
        widget.codeViewController.scriptLocation,
        _handleScriptLocationChanged,
      );
    }

    if (oldWidget.scriptRef != widget.scriptRef) {
      _updateScrollPosition();
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
        _log.info('LinkedScrollControllerGroup has no attached controllers');
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
        var scrollPosition = lineIndex * CodeView.rowHeight -
            ((extent - CodeView.rowHeight) / 2);
        scrollPosition = scrollPosition.clamp(0.0, position.extentTotal);
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

    return Stack(
      children: [
        scriptRef == null
            ? CodeViewEmptyState(widget: widget)
            : buildCodeArea(context),
        PositionedPopup(
          isVisibleListenable: widget.codeViewController.showFileOpener,
          left: noPadding,
          right: noPadding,
          child: buildFileSearchField(),
        ),
        PositionedPopup(
          isVisibleListenable: widget.codeViewController.showSearchInFileField,
          top: denseSpacing,
          right: searchFieldRightPadding,
          child: buildSearchInFileField(),
        ),
      ],
    );
  }

  Widget buildCodeArea(BuildContext context) {
    final theme = Theme.of(context);

    final lines = <TextSpan>[];

    // Ensure the syntax highlighter has been initialized.
    final script = parsedScript;
    final scriptSource = parsedScript?.script.source;
    if (script != null && scriptSource != null) {
      // It takes ~1 second to syntax highlight 100,000 characters. Therefore,
      // we only highlight scripts with less than 100,000 characters. If we want
      // to support larger files, we should process the source for highlighting
      // on a separate isolate.
      if (scriptSource.length < 100000) {
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

    Widget contentBuilder(_, ScriptRef? script) {
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
                final pausedFrame =
                    frame?.scriptRef == scriptRef ? frame : null;

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
                                  selectedFrameNotifier: widget
                                      .debuggerController?.selectedStackFrame,
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
    }

    if (widget.enableHistory) {
      return HistoryViewport(
        history: widget.codeViewController.scriptsHistory,
        generateTitle: (ScriptRef? script) {
          final scriptUri = script?.uri;
          if (scriptUri == null) return '';
          return scriptUri;
        },
        titleIcon: Icons.search,
        onTitleTap: () => widget.codeViewController
          ..toggleFileOpenerVisibility(true)
          ..toggleSearchInFileVisibility(false),
        controls: [
          ScriptPopupMenu(widget.codeViewController),
          ScriptHistoryPopupMenu(
            itemBuilder: _buildScriptMenuFromHistory,
            onSelected: (scriptRef) async {
              await widget.codeViewController
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
      width: extraWideSearchFieldWidth,
      height: defaultTextFieldHeight,
      padding: EdgeInsets.zero,
      child: FileSearchField(
        codeViewController: widget.codeViewController,
      ),
    );
  }

  Widget buildSearchInFileField() {
    return ElevatedCard(
      width: wideSearchFieldWidth,
      height: defaultTextFieldHeight + 2 * denseSpacing,
      child: SearchField<CodeViewController>(
        searchController: widget.codeViewController,
        searchFieldEnabled: parsedScript != null,
        shouldRequestFocus: true,
        searchFieldWidth: wideSearchFieldWidth,
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
  });

  final CodeView widget;

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
    super.key,
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
      child: SizedBox(
        width: gutterWidth,
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
                      return ProfileInformationGutterItem(profilerData: data);
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
    return SizedBox(
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
    required this.profilerData,
  }) : super(key: key);

  final ProfileReportEntry profilerData;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
    super.key,
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
    super.key,
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
        MultiValueListenableBuilder(
          listenables: [
            breakpointManager.breakpointsWithLocation,
            codeViewController.showCodeCoverage,
          ],
          builder: (context, values, _) {
            final breakpoints =
                values.first as List<BreakpointAndSourcePosition>;
            final showCodeCoverage = values.second as bool;
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
    super.key,
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
      ),
      child: ListView.builder(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
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

    final breakpointColor = theme.colorScheme.primary;
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
    required this.searchMatchesNotifier,
    required this.activeSearchMatchNotifier,
    required this.selectedFrameNotifier,
  }) : super(key: key);

  final double height;
  final CodeViewController codeViewController;
  final ScrollController scrollController;
  final List<TextSpan> lines;
  final ValueListenable<List<SourceToken>> searchMatchesNotifier;
  final ValueListenable<SourceToken?> activeSearchMatchNotifier;
  final ValueListenable<StackFrameAndSourcePosition?>? selectedFrameNotifier;

  @override
  State<Lines> createState() => _LinesState();
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
      _maybeScrollToLine(activeSearchLine);
    });

    addAutoDisposeListener(widget.selectedFrameNotifier, () {
      final selectedFrame = widget.selectedFrameNotifier?.value;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _maybeScrollToLine(selectedFrame?.line);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final pausedFrame = widget.selectedFrameNotifier?.value;
    final pausedLine = pausedFrame?.line;

    return SelectionArea(
      child: ListView.builder(
        controller: widget.scrollController,
        physics: const ClampingScrollPhysics(),
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
                pausedFrame: isPausedLine ? pausedFrame : null,
                focused: isPausedLine || isFocusedLine,
                searchMatches: _searchMatchesForLine(index),
                activeSearchMatch:
                    activeSearch?.position.line == index ? activeSearch : null,
              );
            },
          );
        },
      ),
    );
  }

  List<SourceToken> _searchMatchesForLine(int index) {
    return searchMatches
        .where((searchToken) => searchToken.position.line == index)
        .toList();
  }

  void _maybeScrollToLine(int? lineNumber) {
    if (lineNumber == null) return;

    final isOutOfViewTop = lineNumber * CodeView.rowHeight <
        widget.scrollController.offset + CodeView.rowHeight;
    final isOutOfViewBottom = lineNumber * CodeView.rowHeight >
        widget.scrollController.offset + widget.height - CodeView.rowHeight;

    if (isOutOfViewTop || isOutOfViewBottom) {
      // Scroll this search token to the middle of the view.
      final targetOffset = math.max<double>(
        lineNumber * CodeView.rowHeight - widget.height / 2,
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
  State<LineItem> createState() => _LineItemState();
}

class _LineItemState extends State<LineItem>
    with ProvidedControllerMixin<DebuggerController, LineItem> {
  Future<HoverCardData?> _generateHoverCardData({
    required PointerEvent event,
    required bool Function() isHoverStale,
  }) async {
    if (!serviceConnection.serviceManager.isMainIsolatePaused) return null;

    final word = wordForHover(
      event.localPosition.dx,
      widget.lineContents,
    );

    if (word != '') {
      try {
        final response = await evalService.evalAtCurrentFrame(word);
        final isolateRef = serviceConnection
            .serviceManager.isolateManager.selectedIsolate.value;
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

    Widget child;
    final column = widget.pausedFrame?.column;
    if (column != null) {
      final breakpointColor = theme.colorScheme.primary;
      final widthToCurrentColumn = calculateTextSpanWidth(
        truncateTextSpan(widget.lineContents, column - 1),
      );
      // The following constants are tweaked for using the
      // 'Icons.label_important' icon.
      const colIconSize = 13.0;
      // Subtract 3 to offset the icon at the start of the character:
      final colLeftOffset = widthToCurrentColumn - 3.0;
      const colBottomOffset = 13.0;
      const colIconRotate = -90 * math.pi / 180;

      // TODO: support selecting text across multiples lines.
      child = Stack(
        children: [
          Row(
            children: [
              Transform.translate(
                offset: Offset(colLeftOffset, colBottomOffset),
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

    final backgroundColor =
        widget.focused ? theme.colorScheme.selectedRowBackgroundColor : null;

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
        child: Text.rich(
          searchAwareLineContents(),
          maxLines: 1,
        ),
      );

  TextSpan searchAwareLineContents() {
    // If syntax highlighting is disabled for the script, then
    // `widget.lineContents` is simply a `TextSpan` with no children.
    final lineContents = widget.lineContents.children ?? [widget.lineContents];
    final activeSearchAwareContents =
        _activeSearchAwareLineContents(lineContents);
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
  const ScriptPopupMenu(this._controller, {super.key});

  final CodeViewController _controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ScriptPopupMenuOption>(
      onSelected: (option) => option.onSelected(context, _controller),
      itemBuilder: (_) => [
        for (final menuOption in defaultScriptPopupMenuOptions)
          menuOption.build(),
        for (final extensionMenuOption in devToolsExtensionPoints
            .buildExtraDebuggerScriptPopupMenuOptions())
          extensionMenuOption.build(),
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
    super.key,
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

  PopupMenuItem<ScriptPopupMenuOption> build() {
    return PopupMenuItem<ScriptPopupMenuOption>(
      value: this,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
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
    ClipboardData(text: controller.scriptLocation.value?.scriptRef.uri ?? ''),
  ),
);

final copyFilePathOption = ScriptPopupMenuOption(
  label: 'Copy file path',
  icon: Icons.content_copy,
  onSelected: (_, controller) {
    unawaited(() async {
      final filePath = await fetchScriptLocationFullFilePath(controller);
      await Clipboard.setData(
        ClipboardData(text: filePath ?? ''),
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
    final isolateId = serviceConnection
        .serviceManager.isolateManager.selectedIsolate.value!.id!;
    filePath = serviceConnection.resolvedUriManager.lookupFileUri(
      isolateId,
      packagePath,
    );
    if (filePath == null) {
      await serviceConnection.resolvedUriManager.fetchFileUris(
        isolateId,
        [packagePath],
      );
      filePath = serviceConnection.resolvedUriManager.lookupFileUri(
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
  const GoToLineDialog(this._codeViewController, {super.key});

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
            onSubmitted: (value) async {
              final scriptRef =
                  _codeViewController.scriptLocation.value?.scriptRef;
              if (value.isNotEmpty && scriptRef != null) {
                Navigator.of(context).pop(dialogDefaultContext);
                final line = int.parse(value);
                await _codeViewController.showScriptLocation(
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

class PositionedPopup extends StatelessWidget {
  const PositionedPopup({
    super.key,
    required this.isVisibleListenable,
    required this.child,
    this.top,
    this.left,
    this.right,
  });

  final ValueListenable<bool> isVisibleListenable;
  final double? top;
  final double? left;
  final double? right;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isVisibleListenable,
      builder: (context, isVisible, _) {
        return isVisible
            ? Positioned(
                top: top,
                left: left,
                right: right,
                child: child,
              )
            : const SizedBox.shrink();
      },
    );
  }
}

extension CodeViewColorScheme on ColorScheme {
  Color get performanceLowImpactColor => const Color(0xFF5CB246);
  Color get performanceMediumImpactColor => const Color(0xFFF7AC2A);
  Color get performanceHighImpactColor => const Color(0xFFC94040);

  Color get coverageHitColor => performanceLowImpactColor;
  Color get coverageMissColor => performanceHighImpactColor;
}
