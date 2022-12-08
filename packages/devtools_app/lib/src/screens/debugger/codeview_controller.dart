// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/config_specific/logger/logger.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/history_manager.dart';
import '../../shared/routing.dart';
import '../../shared/ui/search.dart';
import '../vm_developer/vm_service_private_extensions.dart';
import 'debugger_model.dart';
import 'program_explorer_controller.dart';
import 'syntax_highlighter.dart';

class CodeViewController extends DisposableController
    with
        AutoDisposeControllerMixin,
        SearchControllerMixin<SourceToken>,
        RouteStateHandlerMixin {
  CodeViewController() {
    _scriptHistoryListener = () {
      final currentScriptValue = scriptsHistory.current.value;
      if (currentScriptValue != null)
        _showScriptLocation(ScriptLocation(currentScriptValue));
    };
    scriptsHistory.current.addListener(_scriptHistoryListener);
  }

  @override
  void dispose() {
    super.dispose();
    scriptsHistory.current.removeListener(_scriptHistoryListener);
  }

  /// Perform operations based on changes in navigation state.
  ///
  /// This method is only invoked if [subscribeToRouterEvents] has been called on
  /// this instance with a valid [DevToolsRouterDelegate].
  @override
  void onRouteStateUpdate(DevToolsNavigationState state) {
    switch (state.kind) {
      case CodeViewSourceLocationNavigationState.type:
        {
          final processedState =
              CodeViewSourceLocationNavigationState._fromState(state);
          // TODO(bkonyi): investigate delay in scrolling to source location.
          showScriptLocation(processedState.location, focusLine: true);
        }
    }
  }

  ValueListenable<ScriptLocation?> get scriptLocation => _scriptLocation;
  final _scriptLocation = ValueNotifier<ScriptLocation?>(null);

  ValueListenable<ScriptRef?> get currentScriptRef => _currentScriptRef;
  final _currentScriptRef = ValueNotifier<ScriptRef?>(null);

  ValueListenable<ParsedScript?> get currentParsedScript => parsedScript;
  @visibleForTesting
  final parsedScript = ValueNotifier<ParsedScript?>(null);

  ValueListenable<bool> get showSearchInFileField => _showSearchInFileField;
  final _showSearchInFileField = ValueNotifier<bool>(false);

  ValueListenable<bool> get showFileOpener => _showFileOpener;
  final _showFileOpener = ValueNotifier<bool>(false);

  ValueListenable<bool> get fileExplorerVisible => _librariesVisible;
  final _librariesVisible = ValueNotifier(false);

  final programExplorerController = ProgramExplorerController();

  final ScriptsHistory scriptsHistory = ScriptsHistory();
  late VoidCallback _scriptHistoryListener;

  ValueListenable<bool> get showCodeCoverage => _showCodeCoverage;
  final _showCodeCoverage = ValueNotifier<bool>(false);

  ValueListenable<bool> get showProfileInformation => _showProfileInformation;
  final _showProfileInformation = ValueNotifier<bool>(false);

  /// Specifies which line should have focus applied in [CodeView].
  ///
  /// A line can be focused by invoking `showScriptLocation` with `focusLine`
  /// set to true.
  ValueListenable<int> get focusLine => _focusLine;
  final _focusLine = ValueNotifier<int>(-1);

  void toggleShowCodeCoverage() {
    _showCodeCoverage.value = !_showCodeCoverage.value;
  }

  void toggleShowProfileInformation() {
    _showProfileInformation.value = !_showProfileInformation.value;
  }

  void clearState() {
    // It would be nice to not clear the script history but it is currently
    // coupled to ScriptRef objects so that is unsafe.
    scriptsHistory.clear();
    parsedScript.value = null;
    _currentScriptRef.value = null;
    _scriptLocation.value = null;
    _librariesVisible.value = false;
  }

  void clearScriptHistory() {
    scriptsHistory.clear();
  }

  /// Callback to be called when the debugger screen is first loaded.
  ///
  /// We delay calling this method until the debugger screen is first loaded
  /// for performance reasons. None of the code here needs to be called when
  /// DevTools first connects to an app, and doing so inhibits DevTools from
  /// connecting to low-end devices.
  Future<void> maybeSetupProgramExplorer() async {
    await _maybeSetUpProgramExplorer();
    addAutoDisposeListener(currentScriptRef, _maybeSetUpProgramExplorer);
  }

  Future<void> _maybeSetUpProgramExplorer() async {
    if (!programExplorerController.initialized.value) {
      programExplorerController
        ..initListeners()
        ..initialize();
    }
    if (currentScriptRef.value != null) {
      await programExplorerController.selectScriptNode(currentScriptRef.value);
      programExplorerController.resetOutline();
    }
  }

  Future<Script?> getScriptForRef(ScriptRef ref) async {
    final cachedScript = scriptManager.getScriptCached(ref);
    if (cachedScript == null) {
      return await scriptManager.getScript(ref);
    }
    return cachedScript;
  }

  /// Jump to the given ScriptRef and optional SourcePosition.
  void showScriptLocation(
    ScriptLocation scriptLocation, {
    bool focusLine = false,
  }) {
    // TODO(elliette): This is here so that when a program is selected in the
    // program explorer, the file opener will close (if it was open). Instead,
    // give the program explorer focus so that the focus changes so the file
    // opener will close automatically when its focus is lost.
    toggleFileOpenerVisibility(false);

    _showScriptLocation(scriptLocation, focusLine: focusLine);

    // Update the scripts history (and make sure we don't react to the
    // subsequent event).
    scriptsHistory.current.removeListener(_scriptHistoryListener);
    scriptsHistory.pushEntry(scriptLocation.scriptRef);
    scriptsHistory.current.addListener(_scriptHistoryListener);
  }

  Future<void> refreshCodeStatistics() async {
    final current = parsedScript.value;
    if (current == null) {
      return;
    }
    final isolateRef = serviceManager.isolateManager.selectedIsolate.value!;
    final processedReport = await _getSourceReport(
      isolateRef,
      current.script,
    );

    parsedScript.value = ParsedScript(
      script: current.script,
      highlighter: current.highlighter,
      executableLines: current.executableLines,
      sourceReport: processedReport,
    );
  }

  /// Resets the current script information before invoking [showScriptLocation].
  void resetScriptLocation(ScriptLocation scriptLocation) {
    _scriptLocation.value = null;
    _currentScriptRef.value = null;
    parsedScript.value = null;
    showScriptLocation(scriptLocation);
  }

  /// Show the given script location (without updating the script navigation
  /// history).
  void _showScriptLocation(
    ScriptLocation scriptLocation, {
    bool focusLine = false,
  }) {
    _currentScriptRef.value = scriptLocation.scriptRef;
    if (_currentScriptRef.value == null) {
      log('Trying to show a location with a null script ref', LogLevel.error);
    }

    unawaited(_parseCurrentScript());

    if (focusLine) {
      _focusLine.value = scriptLocation.location?.line ?? -1;
    }
    // We want to notify regardless of the previous scriptLocation, temporarily
    // set to null to ensure that happens.
    _scriptLocation.value = null;
    _scriptLocation.value = scriptLocation;
  }

  Future<ProcessedSourceReport> _getSourceReport(
    IsolateRef isolateRef,
    Script script,
  ) async {
    final hitLines = <int>{};
    final missedLines = <int>{};
    try {
      final report = await serviceManager.service!.getSourceReport(
        isolateRef.id!,
        // TODO(bkonyi): make _Profile a public report type.
        // See https://github.com/dart-lang/sdk/issues/50641
        const [
          SourceReportKind.kCoverage,
          '_Profile',
        ],
        scriptId: script.id!,
        reportLines: true,
      );

      for (final range in report.ranges!) {
        final coverage = range.coverage!;
        hitLines.addAll(coverage.hits!);
        missedLines.addAll(coverage.misses!);
      }

      final profileReport = report.asProfileReport(script);
      return ProcessedSourceReport(
        coverageHitLines: hitLines,
        coverageMissedLines: missedLines,
        profilerEntries:
            profileReport.profileRanges.fold<Map<int, ProfileReportEntry>>(
          {},
          (last, e) => last..addAll(e.entries),
        ),
      );
    } catch (e) {
      // Ignore - not supported for all vm service implementations.
      log('$e');
    }
    return const ProcessedSourceReport.empty();
  }

  /// Parses the current script into executable lines and prepares the script
  /// for syntax highlighting.
  Future<void> _parseCurrentScript() async {
    // Return early if the current script has not changed.
    if (parsedScript.value?.script.id == _currentScriptRef.value?.id) return;

    final scriptRef = _currentScriptRef.value;
    if (scriptRef == null) return;
    final script = await getScriptForRef(scriptRef);

    // Create a new SyntaxHighlighter with the script's source in preparation
    // for building the code view.
    final highlighter = SyntaxHighlighter(source: script?.source ?? '');

    // Gather the data to display breakable lines.
    var executableLines = <int>{};

    if (script != null) {
      final isolateRef = serviceManager.isolateManager.selectedIsolate.value!;
      try {
        final positions = await breakpointManager.getBreakablePositions(
          isolateRef,
          script,
        );
        executableLines = Set.from(
          positions.where((p) => p.line != null).map((p) => p.line),
        );
      } catch (e) {
        // Ignore - not supported for all vm service implementations.
        log('$e');
      }

      final processedReport = await _getSourceReport(
        isolateRef,
        script,
      );

      parsedScript.value = ParsedScript(
        script: script,
        highlighter: highlighter,
        executableLines: executableLines,
        sourceReport: processedReport,
      );
    }
  }

  /// Make the 'Libraries' view on the right-hand side of the screen visible or
  /// hidden.
  void toggleLibrariesVisible() {
    toggleFileOpenerVisibility(false);
    _librariesVisible.value = !_librariesVisible.value;
  }

  void toggleSearchInFileVisibility(bool visible) {
    _showSearchInFileField.value = visible;
    if (!visible) {
      resetSearch();
    }
  }

  void toggleFileOpenerVisibility(bool visible) {
    _showFileOpener.value = visible;
  }

  // TODO(kenz): search through previous matches when possible.
  @override
  List<SourceToken> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) {
    if (search.isEmpty || parsedScript.value == null) {
      return [];
    }
    final matches = <SourceToken>[];
    final caseInsensitiveSearch = search.toLowerCase();

    final currentScript = parsedScript.value!;
    for (int i = 0; i < currentScript.lines.length; i++) {
      final line = currentScript.lines[i].toLowerCase();
      final matchesForLine = caseInsensitiveSearch.allMatches(line);
      if (matchesForLine.isNotEmpty) {
        matches.addAll(
          matchesForLine.map(
            (m) => SourceToken(
              position: SourcePosition(line: i, column: m.start),
              length: m.end - m.start,
            ),
          ),
        );
      }
    }
    return matches;
  }
}

class ProcessedSourceReport {
  ProcessedSourceReport({
    required this.coverageHitLines,
    required this.coverageMissedLines,
    required this.profilerEntries,
  });

  const ProcessedSourceReport.empty()
      : coverageHitLines = const <int>{},
        coverageMissedLines = const <int>{},
        profilerEntries = const <int, ProfileReportEntry>{};

  final Set<int> coverageHitLines;
  final Set<int> coverageMissedLines;
  final Map<int, ProfileReportEntry> profilerEntries;
}

/// Maintains the navigation history of the debugger's code area - which files
/// were opened, whether it's possible to navigate forwards and backwards in the
/// history, ...
class ScriptsHistory extends HistoryManager<ScriptRef> {
  // TODO(devoncarew): This class should also record and restore scroll
  // positions.

  final _openedScripts = <ScriptRef>{};

  bool get hasScripts => _openedScripts.isNotEmpty;

  void pushEntry(ScriptRef ref) {
    if (ref == current.value) return;

    while (hasNext) {
      pop();
    }

    _openedScripts.remove(ref);
    _openedScripts.add(ref);

    push(ref);
  }

  Iterable<ScriptRef> get openedScripts => _openedScripts.toList().reversed;
}

class ParsedScript {
  ParsedScript({
    required this.script,
    required this.highlighter,
    required this.executableLines,
    required this.sourceReport,
  }) : lines = (script.source?.split('\n') ?? const []).toList();

  final Script script;

  final SyntaxHighlighter highlighter;

  final Set<int> executableLines;

  final ProcessedSourceReport? sourceReport;

  final List<String> lines;

  int get lineCount => lines.length;
}

/// State used to inform [CodeViewController]s listening for
/// [DevToolsNavigationState] changes to display a specific source location.
class CodeViewSourceLocationNavigationState extends DevToolsNavigationState {
  CodeViewSourceLocationNavigationState({
    required ScriptRef script,
    required int line,
  }) : super(
          kind: type,
          state: <String, String?>{
            _kScriptId: script.id,
            _kUri: script.uri,
            _kLine: line.toString(),
          },
        );

  CodeViewSourceLocationNavigationState._fromState(
    DevToolsNavigationState state,
  ) : super(
          kind: type,
          state: state.state,
        );

  static const _kScriptId = 'scriptId';
  static const _kUri = 'uri';
  static const _kLine = 'line';
  static const type = 'codeViewSourceLocation';

  ScriptRef get script => ScriptRef(
        id: state[_kScriptId]!,
        uri: state[_kUri],
      );

  int get line => int.parse(state[_kLine]!);

  ScriptLocation get location => ScriptLocation(
        script,
        location: SourcePosition(line: line, column: 1),
      );
}
