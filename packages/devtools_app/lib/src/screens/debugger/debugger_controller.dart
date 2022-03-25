// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:async/async.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../config_specific/logger/logger.dart';
import '../../primitives/auto_dispose.dart';
import '../../primitives/history_manager.dart';
import '../../primitives/message_bus.dart';
import '../../primitives/utils.dart';
import '../../service/isolate_state.dart';
import '../../service/vm_service_wrapper.dart';
import '../../shared/globals.dart';
import '../../ui/search.dart';
import 'debugger_model.dart';
import 'program_explorer_controller.dart';
import 'syntax_highlighter.dart';

// TODO(devoncarew): Add some delayed resume value notifiers (to be used to
// help debounce stepping operations).

// Make sure this a checked in with `mute: true`.
final _log = DebugTimingLogger('debugger', mute: true);

/// Responsible for managing the debug state of the app.
class DebuggerController extends DisposableController
    with AutoDisposeControllerMixin, SearchControllerMixin<SourceToken> {
  // `initialSwitchToIsolate` can be set to false for tests to skip the logic
  // in `switchToIsolate`.
  DebuggerController({this.initialSwitchToIsolate = true}) {
    _programExplorerController = ProgramExplorerController(
      debuggerController: this,
    );
    autoDisposeStreamSubscription(serviceManager.onConnectionAvailable
        .listen(_handleConnectionAvailable));
    if (_service != null) {
      initialize();
    }
    _scriptHistoryListener = () {
      if (scriptsHistory.current.value != null)
        _showScriptLocation(ScriptLocation(scriptsHistory.current.value!));
    };
    scriptsHistory.current.addListener(_scriptHistoryListener);
  }

  bool _firstDebuggerScreenLoaded = false;

  /// Callback to be called when the debugger screen is first loaded.
  ///
  /// We delay calling this method until the debugger screen is first loaded
  /// for performance reasons. None of the code here needs to be called when
  /// DevTools first connects to an app, and doing so inhibits DevTools from
  /// connecting to low-end devices.
  Future<void> onFirstDebuggerScreenLoad() async {
    if (!_firstDebuggerScreenLoaded) {
      await _maybeSetUpProgramExplorer();
      addAutoDisposeListener(currentScriptRef, _maybeSetUpProgramExplorer);
      _firstDebuggerScreenLoaded = true;
    }
  }

  Future<void> _maybeSetUpProgramExplorer() async {
    if (!programExplorerController.initialized.value) {
      programExplorerController
        ..initListeners()
        ..initialize();
    }
    if (currentScriptRef.value != null) {
      await programExplorerController.selectScriptNode(currentScriptRef.value);
    }
  }

  /// Method to call after the vm service shuts down.
  void onServiceShutdown() {
    _clearCaches();

    _hasTruncatedFrames.value = false;
    _getStackOperation?.cancel();
    _getStackOperation = null;
    // It would be nice to not clear the script history but it is currently
    // coupled to ScriptRef objects so that is unsafe.
    scriptsHistory.clear();
    _isPaused.value = false;
    _resuming.value = false;
    _lastEvent = null;
    _currentScriptRef.value = null;
    _scriptLocation.value = null;
    _uriToScriptMap.clear();
    _stackFramesWithLocation.value = [];
    _selectedStackFrame.value = null;
    _variables.value = [];
    _sortedScripts.value = [];
    _breakpoints.value = [];
    _breakpointsWithLocation.value = [];
    _selectedBreakpoint.value = null;
    _librariesVisible.value = false;
    isolateRef = null;
    _firstDebuggerScreenLoaded = false;
  }

  VmServiceWrapper? _lastService;

  void _handleConnectionAvailable(VmServiceWrapper service) {
    if (service == _lastService) return;
    _lastService = service;
    onServiceShutdown();
    if (service != null) {
      initialize();
    }
  }

  void initialize() {
    if (initialSwitchToIsolate) {
      assert(serviceManager.isolateManager.selectedIsolate.value != null);
      switchToIsolate(serviceManager.isolateManager.selectedIsolate.value);
    }

    addAutoDisposeListener(serviceManager.isolateManager.selectedIsolate, () {
      switchToIsolate(serviceManager.isolateManager.selectedIsolate.value);
    });
    autoDisposeStreamSubscription(
        _service!.onDebugEvent.listen(_handleDebugEvent));
    autoDisposeStreamSubscription(
        _service!.onIsolateEvent.listen(_handleIsolateEvent));
  }

  final bool initialSwitchToIsolate;

  IsolateState? get isolateDebuggerState =>
      serviceManager.isolateManager.isolateDebuggerState(isolateRef);

  VmServiceWrapper? get _service => serviceManager.service;

  /// Cache of autocomplete matches to show for a library when that library is
  /// imported.
  ///
  /// This cache includes autocompletes from libraries exported by the library
  /// but does not include autocompletes for libraries imported by this library.

  Map<LibraryRef?, Future<Set<String?>>> libraryMemberAutocompleteCache = {};

  /// Cache of autocomplete matches for a library for code written within that
  /// library.
  ///
  /// This cache includes autocompletes from all libraries imported and exported
  /// by the library as well as all private autocompletes for the library.
  Map<LibraryRef, Future<Set<String?>>>
      libraryMemberAndImportsAutocompleteCache = {};

  ProgramExplorerController get programExplorerController =>
      _programExplorerController;
  late final ProgramExplorerController _programExplorerController;

  final ScriptCache _scriptCache = ScriptCache();

  final ScriptsHistory scriptsHistory = ScriptsHistory();
  late VoidCallback _scriptHistoryListener;

  final _isPaused = ValueNotifier<bool>(false);

  ValueListenable<bool> get isPaused => _isPaused;

  final _resuming = ValueNotifier<bool>(false);

  /// This indicates that we've requested a resume (or step) operation from the
  /// VM, but haven't yet received the 'resumed' isolate event.
  ValueListenable<bool> get resuming => _resuming;

  Event? _lastEvent;

  Event? get lastEvent => _lastEvent;

  final _currentScriptRef = ValueNotifier<ScriptRef?>(null);

  ValueListenable<ScriptRef?> get currentScriptRef => _currentScriptRef;

  @visibleForTesting
  final parsedScript = ValueNotifier<ParsedScript?>(null);

  ValueListenable<ParsedScript?> get currentParsedScript => parsedScript;

  ValueListenable<bool> get showSearchInFileField => _showSearchInFileField;

  final _showSearchInFileField = ValueNotifier<bool>(false);

  ValueListenable<ScriptLocation?> get scriptLocation => _scriptLocation;

  final _scriptLocation = ValueNotifier<ScriptLocation?>(null);

  ValueListenable<bool> get showFileOpener => _showFileOpener;

  final _showFileOpener = ValueNotifier<bool>(false);

  final _clazzCache = <ClassRef, Class>{};

  /// Jump to the given ScriptRef and optional SourcePosition.
  void showScriptLocation(ScriptLocation scriptLocation) {
    // TODO(elliette): This is here so that when a program is selected in the
    // program explorer, the file opener will close (if it was open). Instead,
    // give the program explorer focus so that the focus changes so the file
    // opener will close automatically when its focus is lost.
    toggleFileOpenerVisibility(false);

    _showScriptLocation(scriptLocation);

    // Update the scripts history (and make sure we don't react to the
    // subsequent event).
    scriptsHistory.current.removeListener(_scriptHistoryListener);
    scriptsHistory.pushEntry(scriptLocation.scriptRef);
    scriptsHistory.current.addListener(_scriptHistoryListener);
  }

  /// Show the given script location (without updating the script navigation
  /// history).
  void _showScriptLocation(ScriptLocation scriptLocation) {
    _currentScriptRef.value = scriptLocation.scriptRef;
    if (_currentScriptRef.value == null) {
      log('Trying to show a location with a null script ref', LogLevel.error);
    }

    _parseCurrentScript();

    // We want to notify regardless of the previous scriptLocation, temporarily
    // set to null to ensure that happens.
    _scriptLocation.value = null;
    _scriptLocation.value = scriptLocation;
  }

  Future<Script?> getScriptForRef(ScriptRef? ref) async {
    final cachedScript = getScriptCached(ref);
    if (cachedScript == null && ref != null) {
      return await getScript(ref);
    }
    return cachedScript;
  }

  /// Parses the current script into executable lines and prepares the script
  /// for syntax highlighting.
  Future<void> _parseCurrentScript() async {
    // Return early if the current script has not changed.
    if (parsedScript.value?.script.id == _currentScriptRef.value?.id) return;

    final scriptRef = _currentScriptRef.value;
    final script = await getScriptForRef(scriptRef);

    // Create a new SyntaxHighlighter with the script's source in preparation
    // for building the code view.
    final highlighter = SyntaxHighlighter(source: script?.source ?? '');

    // Gather the data to display breakable lines.
    var executableLines = <int>{};

    if (script != null) {
      try {
        final positions = await (getBreakablePositions(script)
            as FutureOr<List<SourcePosition>>);
        executableLines = Set.from(positions.map((p) => p.line));
      } catch (e) {
        // Ignore - not supported for all vm service implementations.
        log('$e');
      }
      parsedScript.value = ParsedScript(
        script: script,
        highlighter: highlighter,
        executableLines: executableLines,
      );
    }
  }

  /// Find the owner library for a ClassRef, FuncRef, or LibraryRef.
  ///
  /// If Dart had union types, ref would be type ClassRef | FuncRef | LibraryRef
  Future<LibraryRef?> findOwnerLibrary(Object? ref) async {
    if (ref is LibraryRef) {
      return ref;
    }
    if (ref is ClassRef) {
      if (ref.library != null) {
        return ref.library;
      }
      // Fallback for older VMService versions.
      final clazz = await classFor(ref);
      return clazz?.library;
    }
    if (ref is FuncRef) {
      return findOwnerLibrary(ref.owner);
    }
    return null;
  }

  /// Returns the class for the provided [ClassRef].
  ///
  /// May return null.
  Future<Class?> classFor(ClassRef classRef) async {
    try {
      return _clazzCache[classRef] ??=
          await (getObject(classRef) as FutureOr<Class>);
    } catch (_) {}
    return null;
  }

  // A cached map of uris to ScriptRefs.
  final Map<String?, ScriptRef> _uriToScriptMap = {};

  final _stackFramesWithLocation =
      ValueNotifier<List<StackFrameAndSourcePosition>>([]);

  ValueListenable<List<StackFrameAndSourcePosition>>
      get stackFramesWithLocation => _stackFramesWithLocation;

  final _selectedStackFrame = ValueNotifier<StackFrameAndSourcePosition?>(null);

  ValueListenable<StackFrameAndSourcePosition?> get selectedStackFrame =>
      _selectedStackFrame;

  Frame? get frameForEval =>
      _selectedStackFrame.value?.frame ??
      _stackFramesWithLocation.value.safeFirst?.frame;

  final _variables = ValueNotifier<List<DartObjectNode>>([]);

  ValueListenable<List<DartObjectNode>> get variables => _variables;

  final _sortedScripts = ValueNotifier<List<ScriptRef>>([]);

  /// Return the sorted list of ScriptRefs active in the current isolate.
  ValueListenable<List<ScriptRef>> get sortedScripts => _sortedScripts;

  final ValueNotifier<List<Breakpoint?>?> _breakpoints =
      ValueNotifier<List<Breakpoint>?>([]);

  ValueListenable<List<Breakpoint?>?> get breakpoints => _breakpoints;

  final _breakpointsWithLocation =
      ValueNotifier<List<BreakpointAndSourcePosition>>([]);

  ValueListenable<List<BreakpointAndSourcePosition>>
      get breakpointsWithLocation => _breakpointsWithLocation;

  final _selectedBreakpoint = ValueNotifier<BreakpointAndSourcePosition?>(null);

  ValueListenable<BreakpointAndSourcePosition?> get selectedBreakpoint =>
      _selectedBreakpoint;

  final _exceptionPauseMode =
      ValueNotifier<String?>(ExceptionPauseMode.kUnhandled);

  ValueListenable<String?> get exceptionPauseMode => _exceptionPauseMode;

  final _librariesVisible = ValueNotifier(false);

  ValueListenable<bool> get fileExplorerVisible => _librariesVisible;

  /// Make the 'Libraries' view on the right-hand side of the screen visible or
  /// hidden.
  void toggleLibrariesVisible() {
    toggleFileOpenerVisibility(false);
    _librariesVisible.value = !_librariesVisible.value;
  }

  IsolateRef? isolateRef;
  bool get isSystemIsolate => isolateRef?.isSystemIsolate ?? false;

  final EvalHistory evalHistory = EvalHistory();

  void switchToIsolate(IsolateRef? ref) async {
    isolateRef = ref;
    _isPaused.value = false;
    await _pause(false);

    _clearCaches();

    if (ref == null) {
      _breakpoints.value = [];
      _breakpointsWithLocation.value = [];
      await _getStackOperation?.cancel();
      _populateFrameInfo([], truncated: false);
      return;
    }

    final isolate = await _service!.getIsolate(isolateRef!.id!);
    if (isolate.id != isolateRef?.id) {
      // Current request is obsolete.
      return;
    }

    if (isolate.pauseEvent != null &&
        isolate.pauseEvent!.kind != EventKind.kResume) {
      _lastEvent = isolate.pauseEvent;
      await _pause(true, pauseEvent: isolate.pauseEvent);
    }
    if (isolate.id != isolateRef?.id) {
      // Current request is obsolete.
      return;
    }

    _breakpoints.value = isolate.breakpoints;

    // Build _breakpointsWithLocation from _breakpoints.
    if (_breakpoints.value != null) {
      // ignore: unawaited_futures
      Future.wait(_breakpoints.value!.map(_createBreakpointWithLocation))
          .then((list) {
        if (isolate.id != isolateRef?.id) {
          // Current request is obsolete.
          return;
        }
        _breakpointsWithLocation.value = list.toList()..sort();
      });
    }

    _exceptionPauseMode.value = isolate.exceptionPauseMode;

    if (isolate.id != isolateRef?.id) {
      // Current request is obsolete.
      return;
    }
    await _populateScripts(isolate);
  }

  Future<Success> pause() => _service!.pause(isolateRef!.id!);

  Future<Success> resume() {
    _log.log('resume()');
    _resuming.value = true;
    return _service!.resume(isolateRef!.id!);
  }

  Future<Success> stepOver() {
    _log.log('stepOver()');
    _resuming.value = true;

    // Handle async suspensions; issue StepOption.kOverAsyncSuspension.
    final useAsyncStepping = _lastEvent?.atAsyncSuspension ?? false;
    return _service!
        .resume(
          isolateRef!.id!,
          step: useAsyncStepping
              ? StepOption.kOverAsyncSuspension
              : StepOption.kOver,
        )
        .whenComplete(() => _log.log('stepOver() completed'));
  }

  Future<Success> stepIn() {
    _resuming.value = true;

    return _service!.resume(isolateRef!.id!, step: StepOption.kInto);
  }

  Future<Success> stepOut() {
    _resuming.value = true;

    return _service!.resume(isolateRef!.id!, step: StepOption.kOut);
  }

  /// Evaluate the given expression in the context of the currently selected
  /// stack frame, or the top frame if there is no current selection.
  ///
  /// This will fail if the application is not currently paused.
  Future<Response> evalAtCurrentFrame(String expression) async {
    if (!isPaused.value) {
      return Future.error(
        RPCError.withDetails(
            'evaluateInFrame', RPCError.kInvalidParams, 'Isolate not paused'),
      );
    }

    if (stackFramesWithLocation.value.isEmpty) {
      return Future.error(
        RPCError.withDetails(
            'evaluateInFrame', RPCError.kInvalidParams, 'No frames available'),
      );
    }

    final frame = selectedStackFrame.value?.frame ??
        stackFramesWithLocation.value.first.frame;

    return _service!.evaluateInFrame(
      isolateRef!.id!,
      frame.index!,
      expression,
      disableBreakpoints: true,
    );
  }

  /// Call `toString()` on the given instance and return the result.
  Future<Response> invokeToString(InstanceRef instance) {
    return _service!.invoke(
      isolateRef!.id!,
      instance.id!,
      'toString',
      <String>[],
      disableBreakpoints: true,
    );
  }

  /// Retrieves the full string value of a [stringRef].
  Future<String?> retrieveFullStringValue(
    InstanceRef stringRef, {
    String onUnavailable(String? truncatedValue)?,
  }) async {
    return serviceManager.service!.retrieveFullStringValue(
      isolateRef!.id!,
      stringRef,
      onUnavailable: onUnavailable,
    );
  }

  Future<void> clearBreakpoints() async {
    final breakpoints = _breakpoints.value!.toList();
    await Future.forEach(breakpoints, (Breakpoint? breakpoint) {
      return removeBreakpoint(breakpoint!);
    });
  }

  Future<Breakpoint> addBreakpoint(String scriptId, int line) =>
      _service!.addBreakpoint(isolateRef!.id!, scriptId, line);

  Future<void> removeBreakpoint(Breakpoint breakpoint) =>
      _service!.removeBreakpoint(isolateRef!.id!, breakpoint.id!);

  Future<void> toggleBreakpoint(ScriptRef script, int line) async {
    if (serviceManager.isolateManager.selectedIsolate.value == null) {
      // Can't toggle breakpoints if we don't have an isolate.
      return;
    }
    // The VM doesn't support debugging for system isolates and will crash on
    // a failed assert in debug mode. Disable the toggle breakpoint
    // functionality for system isolates.
    if (serviceManager.isolateManager.selectedIsolate.value!.isSystemIsolate!) {
      return;
    }

    final bp = breakpointsWithLocation.value.firstWhereOrNull((bp) {
      return bp.scriptRef == script && bp.line == line;
    });

    if (bp != null) {
      await removeBreakpoint(bp.breakpoint);
    } else {
      try {
        await addBreakpoint(script.id!, line);
      } catch (_) {
        // ignore errors setting breakpoints
      }
    }
  }

  Future<void> setIsolatePauseMode(String mode) async {
    await _service!
        .setIsolatePauseMode(isolateRef!.id!, exceptionPauseMode: mode);
    _exceptionPauseMode.value = mode;
  }

  /// Flutter starting with '--start-paused'. All subsequent isolates, after
  /// the first isolate, are in a pauseStart state too.  If _resuming, then
  /// resume any future isolate created with pause start.
  Future<Success> _resumeIsolatePauseStart(Event event) {
    assert(event.kind == EventKind.kPauseStart);
    assert(_resuming.value);

    final id = event.isolate!.id!;
    _log.log('resume() $id');
    return _service!.resume(id);
  }

  void _handleDebugEvent(Event event) {
    _log.log('event: ${event.kind}');

    // We're resuming and another isolate has started in a paused state,
    // resume any pauseState isolates.
    if (_resuming.value &&
        event.isolate!.id != isolateRef?.id &&
        event.kind == EventKind.kPauseStart) {
      _resumeIsolatePauseStart(event);
    }

    if (event.isolate!.id != isolateRef?.id) return;

    _lastEvent = event;

    switch (event.kind) {
      case EventKind.kResume:
        _pause(false);
        break;
      case EventKind.kPauseStart:
      case EventKind.kPauseExit:
      case EventKind.kPauseBreakpoint:
      case EventKind.kPauseInterrupted:
      case EventKind.kPauseException:
      case EventKind.kPausePostRequest:
        // Any event we receive here indicates that any resume/step request has been
        // processed.
        _resuming.value = false;
        _pause(true, pauseEvent: event);
        break;
      // TODO(djshuckerow): switch the _breakpoints notifier to a 'ListNotifier'
      // that knows how to notify when performing a list edit operation.
      case EventKind.kBreakpointAdded:
        _breakpoints.value = [..._breakpoints.value!, event.breakpoint];

        // ignore: unawaited_futures
        _createBreakpointWithLocation(event.breakpoint).then((bp) {
          final list = [
            ..._breakpointsWithLocation.value,
            bp,
          ]..sort();

          _breakpointsWithLocation.value = list;
        });

        break;
      case EventKind.kBreakpointResolved:
        _breakpoints.value = [
          for (var b in _breakpoints.value!)
            if (b != event.breakpoint) b,
          event.breakpoint
        ];

        // ignore: unawaited_futures
        _createBreakpointWithLocation(event.breakpoint).then((bp) {
          final list = _breakpointsWithLocation.value.toList();
          // Remote the bp with the older, unresolved information from the list.
          list.removeWhere((breakpoint) => bp.breakpoint.id == bp.id);
          // Add the bp with the newer, resolved information.
          list.add(bp);
          list.sort();
          _breakpointsWithLocation.value = list;
        });

        break;

      case EventKind.kBreakpointRemoved:
        final breakpoint = event.breakpoint;

        // Update _selectedBreakpoint if necessary.
        if (_selectedBreakpoint.value?.breakpoint == breakpoint) {
          _selectedBreakpoint.value = null;
        }

        _breakpoints.value = [
          for (var b in _breakpoints.value!)
            if (b != breakpoint) b
        ];

        _breakpointsWithLocation.value = [
          for (var b in _breakpointsWithLocation.value)
            if (b.breakpoint != breakpoint) b
        ];

        break;
    }
  }

  void _handleIsolateEvent(Event event) {
    if (event.isolate!.id != isolateRef?.id) return;
    switch (event.kind) {
      case EventKind.kIsolateReload:
        _updateAfterIsolateReload(event);
        break;
    }
  }

  Future<List<ScriptRef>> _retrieveAndSortScripts(IsolateRef? ref) async {
    assert(isolateRef != null);
    final scriptList = await _service!.getScripts(isolateRef!.id!);
    // We filter out non-unique ScriptRefs here (dart-lang/sdk/issues/41661).
    final scriptRefs = Set.of(scriptList.scripts!).toList();
    scriptRefs.sort((a, b) {
      // We sort uppercase so that items like dart:foo sort before items like
      // dart:_foo.
      return a.uri!.toUpperCase().compareTo(b.uri!.toUpperCase());
    });
    return scriptRefs;
  }

  void _updateAfterIsolateReload(Event reloadEvent) async {
    // Generally this has the value 'success'; we update our data in any case.
    // ignore: unused_local_variable
    final status = reloadEvent.status;

    _clearAutocompleteCaches();
    // Refresh the list of scripts.
    final scriptRefs = await _retrieveAndSortScripts(isolateRef);
    for (var scriptRef in scriptRefs) {
      _uriToScriptMap[scriptRef.uri] = scriptRef;
    }

    final removedScripts =
        Set.of(_sortedScripts.value).difference(Set.of(scriptRefs));
    final addedScripts =
        Set.of(scriptRefs).difference(Set.of(_sortedScripts.value));

    _sortedScripts.value = scriptRefs;

    // TODO(devoncarew): Show a message in the logging view.

    // Show a toast.
    final count = removedScripts.length + addedScripts.length;
    messageBus.addEvent(BusEvent('toast',
        data: '${nf.format(count)} ${pluralize('script', count)} updated.'));

    // Update breakpoints.
    _updateBreakpointsAfterReload(removedScripts, addedScripts);

    // Redirect the current editor screen if necessary.
    if (removedScripts.contains(currentScriptRef.value)) {
      final uri = currentScriptRef.value!.uri;
      final newScriptRef =
          addedScripts.firstWhereOrNull((script) => script.uri == uri);

      if (newScriptRef != null) {
        // Display the script location.
        _populateScriptAndShowLocation(newScriptRef);
      }
    }
  }

  /// Jump to the given script.
  ///
  /// This method ensures that the source for the script is populated in our
  /// cache, in order to reduce flashing in the editor view.
  void _populateScriptAndShowLocation(ScriptRef scriptRef) {
    getScript(scriptRef)!.then((script) {
      showScriptLocation(ScriptLocation(scriptRef));
    });
  }

  void _updateBreakpointsAfterReload(
    Set<ScriptRef> removedScripts,
    Set<ScriptRef> addedScripts,
  ) {
    // TODO(devoncarew): We need to coordinate this with other debugger clients
    // as well as pause before re-setting the breakpoints.

    final breakpointsToRemove = <BreakpointAndSourcePosition>[];

    // Find all breakpoints set in files where we have newer versions of those
    // files.
    for (final scriptRef in removedScripts) {
      for (final bp in breakpointsWithLocation.value) {
        if (bp.scriptRef == scriptRef) {
          breakpointsToRemove.add(bp);
        }
      }
    }

    // Remove the breakpoints.
    for (final bp in breakpointsToRemove) {
      removeBreakpoint(bp.breakpoint);
    }

    // Add them back to the newer versions of those scripts.
    for (final scriptRef in addedScripts) {
      for (final bp in breakpointsToRemove) {
        if (scriptRef.uri == bp.scriptUri) {
          addBreakpoint(scriptRef.id!, bp.line!);
        }
      }
    }
  }

  final _hasTruncatedFrames = ValueNotifier<bool>(false);

  ValueListenable<bool> get hasTruncatedFrames => _hasTruncatedFrames;

  CancelableOperation<_StackInfo>? _getStackOperation;

  Future<void> _pause(bool paused, {Event? pauseEvent}) async {
    // TODO(jacobr): unify pause support with
    // serviceManager.isolateManager.selectedIsolateState.isPaused.value;
    // listening for changes there instead of having separate logic.
    await _getStackOperation?.cancel();
    _isPaused.value = paused;

    _log.log('_pause(running: ${!paused})');

    // Perform an early exit if we're not paused.
    if (!paused) {
      _populateFrameInfo([], truncated: false);
      return;
    }

    // Collecting frames for Dart web applications can be slow. At the potential
    // cost of a flicker in the stack view, display only the top frame
    // initially.
    // TODO(elliette): Find a better solution for this. Currently, this means
    // we fetch all variable objects twice (once in _getFullStack and once in
    // in_createStackFrameWithLocation).
    if (await serviceManager.connectedApp!.isDartWebApp) {
      _populateFrameInfo(
        [
          await _createStackFrameWithLocation(pauseEvent!.topFrame!),
        ],
        truncated: true,
      );
      unawaited(_getFullStack());
      return;
    }

    // We populate the first 12 frames; this ~roughly corresponds to the number
    // of visible stack frames.
    const initialFrameRequestCount = 12;

    _getStackOperation = CancelableOperation.fromFuture(_getStackInfo(
      limit: initialFrameRequestCount,
    ));
    final stackInfo = await _getStackOperation!.value;
    _populateFrameInfo(
      stackInfo.frames,
      truncated: stackInfo.truncated,
    );

    // In the background, populate the rest of the frames.
    if (stackInfo.truncated) {
      unawaited(_getFullStack());
    }
  }

  Future<_StackInfo> _getStackInfo({int? limit}) async {
    _log.log('getStack() with limit: $limit');
    final stack = await _service!.getStack(isolateRef!.id!, limit: limit);
    _log.log('getStack() completed (frames: ${stack.frames!.length})');

    final frames = _framesForCallStack(
      stack.frames,
      asyncCausalFrames: stack.asyncCausalFrames,
      reportedException: _lastEvent?.exception,
    )!;

    return _StackInfo(
      await Future.wait(frames.map(_createStackFrameWithLocation)),
      stack.truncated ?? false,
    );
  }

  void _populateFrameInfo(
    List<StackFrameAndSourcePosition> frames, {
    required final bool truncated,
  }) {
    _log.log('populated frame info');
    _stackFramesWithLocation.value = frames;
    _hasTruncatedFrames.value = truncated;
    if (frames.isEmpty) {
      selectStackFrame(null);
    } else {
      selectStackFrame(frames.first);
    }
  }

  Future<void> _getFullStack() async {
    await _getStackOperation?.cancel();
    _getStackOperation = CancelableOperation.fromFuture(_getStackInfo());
    final stackInfo = await _getStackOperation!.value;
    _populateFrameInfo(stackInfo.frames, truncated: stackInfo.truncated);
  }

  void _clearCaches() {
    _scriptCache.clear();
    _lastEvent = null;
    _breakPositionsMap.clear();
    _uriToScriptMap.clear();
    _clearAutocompleteCaches();
  }

  void _clearAutocompleteCaches() {
    _clazzCache.clear();
    libraryMemberAutocompleteCache.clear();
    libraryMemberAndImportsAutocompleteCache.clear();
  }

  /// Get the populated [Obj] object, given an [ObjRef].
  ///
  /// The return value can be one of [Obj] or [Sentinel].
  Future<Obj> getObject(ObjRef objRef) {
    return _service!.getObject(isolateRef!.id!, objRef.id!);
  }

  /// Return a cached [Script] for the given [ScriptRef], returning null
  /// if there is no cached [Script].
  Script? getScriptCached(ScriptRef? scriptRef) {
    return _scriptCache.getScriptCached(scriptRef);
  }

  /// Retrieve the [Script] for the given [ScriptRef].
  ///
  /// This caches the script lookup for future invocations.
  Future<Script>? getScript(ScriptRef scriptRef) {
    return _scriptCache.getScript(_service, isolateRef, scriptRef);
  }

  /// Return the [ScriptRef] at the given [uri].
  ScriptRef? scriptRefForUri(String uri) {
    return _uriToScriptMap[uri];
  }

  Future<void> _populateScripts(Isolate isolate) async {
    assert(isolate != null);
    final scriptRefs = await _retrieveAndSortScripts(isolateRef);
    _sortedScripts.value = scriptRefs;

    for (var scriptRef in scriptRefs) {
      _uriToScriptMap[scriptRef.uri] = scriptRef;
    }

    // Update the selected script.
    final mainScriptRef = scriptRefs.firstWhereOrNull((ref) {
      return ref.uri == isolate.rootLib!.uri;
    })!;

    // Display the script location.
    _populateScriptAndShowLocation(mainScriptRef);
  }

  Future<BreakpointAndSourcePosition> _createBreakpointWithLocation(
      Breakpoint? breakpoint) async {
    if (breakpoint!.resolved!) {
      final bp = BreakpointAndSourcePosition.create(breakpoint);
      return getScript(bp.scriptRef!)!.then((Script script) {
        final pos = SourcePosition.calculatePosition(script, bp.tokenPos);
        return BreakpointAndSourcePosition.create(breakpoint, pos);
      });
    } else {
      return BreakpointAndSourcePosition.create(breakpoint);
    }
  }

  Future<StackFrameAndSourcePosition> _createStackFrameWithLocation(
    Frame frame,
  ) async {
    final location = frame.location;
    if (location == null) {
      return StackFrameAndSourcePosition(frame);
    }

    final script = await getScript(location.script!)!;
    final position =
        SourcePosition.calculatePosition(script, location.tokenPos);
    return StackFrameAndSourcePosition(frame, position: position);
  }

  void selectBreakpoint(BreakpointAndSourcePosition bp) {
    _selectedBreakpoint.value = bp;

    if (bp.sourcePosition == null) {
      showScriptLocation(ScriptLocation(bp.scriptRef!));
    } else {
      showScriptLocation(
          ScriptLocation(bp.scriptRef!, location: bp.sourcePosition));
    }
  }

  void selectStackFrame(StackFrameAndSourcePosition? frame) {
    _selectedStackFrame.value = frame;

    if (frame != null) {
      _variables.value = _createVariablesForFrame(frame.frame);
    } else {
      _variables.value = [];
    }

    if (frame?.scriptRef != null) {
      showScriptLocation(
          ScriptLocation(frame!.scriptRef!, location: frame.position));
    }
  }

  List<DartObjectNode> _createVariablesForFrame(Frame frame) {
    // vars can be null for async frames.
    if (frame.vars == null) {
      return [];
    }

    final variables =
        frame.vars!.map((v) => DartObjectNode.create(v, isolateRef)).toList();
    variables
      ..forEach(buildVariablesTree)
      ..sort((a, b) => sortFieldsByName(a.name!, b.name!));
    return variables;
  }

  List<Frame>? _framesForCallStack(
    List<Frame>? stackFrames, {
    List<Frame>? asyncCausalFrames,
    InstanceRef? reportedException,
  }) {
    // Prefer asyncCausalFrames if they exist.
    List<Frame>? frames = asyncCausalFrames ?? stackFrames;

    // Include any reported exception as a variable in the first frame.
    if (reportedException != null && frames!.isNotEmpty) {
      final frame = frames.first;

      final newFrame = Frame(
        index: frame.index,
        function: frame.function,
        code: frame.code,
        location: frame.location,
        kind: frame.kind,
      );

      newFrame.vars = [
        BoundVariable(
          name: '<exception>',
          value: reportedException,
          scopeStartTokenPos: null,
          scopeEndTokenPos: null,
          declarationTokenPos: null,
        ),
        ...frame.vars ?? []
      ];

      frames = [newFrame, ...frames.sublist(1)];
    }

    return frames;
  }

  final Map<String?, List<SourcePosition>> _breakPositionsMap = {};

  /// Return the list of valid positions for breakpoints for a given script.
  Future<List<SourcePosition>?> getBreakablePositions(Script script) async {
    if (!_breakPositionsMap.containsKey(script.id)) {
      _breakPositionsMap[script.id] = await _getBreakablePositions(script);
    }

    return _breakPositionsMap[script.id];
  }

  Future<List<SourcePosition>> _getBreakablePositions(Script script) async {
    final report = await _service!.getSourceReport(
      isolateRef!.id!,
      [SourceReportKind.kPossibleBreakpoints],
      scriptId: script.id,
      forceCompile: true,
    );

    final positions = <SourcePosition>[];

    for (SourceReportRange range in report.ranges!) {
      if (range.possibleBreakpoints != null) {
        for (int tokenPos in range.possibleBreakpoints!) {
          positions.add(SourcePosition.calculatePosition(script, tokenPos));
        }
      }
    }

    return positions;
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
    if (search == null || search.isEmpty || parsedScript.value == null) {
      return [];
    }
    final matches = <SourceToken>[];
    final caseInsensitiveSearch = search.toLowerCase();

    final currentScript = parsedScript.value!;
    for (int i = 0; i < currentScript.lines.length; i++) {
      final line = currentScript.lines[i].toLowerCase();
      final matchesForLine = caseInsensitiveSearch.allMatches(line);
      if (matchesForLine.isNotEmpty) {
        matches.addAll(matchesForLine.map(
          (m) => SourceToken(
            position: SourcePosition(line: i, column: m.start),
            length: m.end - m.start,
          ),
        ));
      }
    }
    return matches;
  }
}

class ScriptCache {
  ScriptCache();

  Map<String?, Script> _scripts = {};
  final Map<String?, Future<Script>> _inProgress = {};

  /// Return a cached [Script] for the given [ScriptRef], returning null
  /// if there is no cached [Script].
  Script? getScriptCached(ScriptRef? scriptRef) {
    return _scripts[scriptRef?.id];
  }

  /// Retrieve the [Script] for the given [ScriptRef].
  ///
  /// This caches the script lookup for future invocations.
  Future<Script>? getScript(
      VmService? vmService, IsolateRef? isolateRef, ScriptRef scriptRef) {
    if (_scripts.containsKey(scriptRef.id)) {
      return Future.value(_scripts[scriptRef.id]);
    }

    if (_inProgress.containsKey(scriptRef.id)) {
      return _inProgress[scriptRef.id];
    }

    // We make a copy here as the future could complete after a clear()
    // operation is performed.
    final scripts = _scripts;

    final Future<Script> scriptFuture = vmService!
        .getObject(isolateRef!.id!, scriptRef.id!)
        .then((obj) => obj as Script);
    _inProgress[scriptRef.id] = scriptFuture;

    unawaited(scriptFuture.then((script) {
      scripts[scriptRef.id] = script;
    }));

    return scriptFuture;
  }

  void clear() {
    _scripts = {};
    _inProgress.clear();
  }
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

/// Store and manipulate the expression evaluation history.
class EvalHistory {
  var _historyPosition = -1;

  /// Get the expression evaluation history.
  List<String> get evalHistory => _evalHistory.toList();

  final _evalHistory = <String>[];

  /// Push a new entry onto the expression evaluation history.
  void pushEvalHistory(String expression) {
    if (_evalHistory.isNotEmpty && _evalHistory.last == expression) {
      return;
    }

    _evalHistory.add(expression);
    _historyPosition = -1;
  }

  bool get canNavigateUp {
    return _evalHistory.isNotEmpty && _historyPosition != 0;
  }

  void navigateUp() {
    if (_historyPosition == -1) {
      _historyPosition = _evalHistory.length - 1;
    } else if (_historyPosition > 0) {
      _historyPosition--;
    }
  }

  bool get canNavigateDown {
    return _evalHistory.isNotEmpty && _historyPosition != -1;
  }

  void navigateDown() {
    if (_historyPosition != -1) {
      _historyPosition++;
    }
    if (_historyPosition >= _evalHistory.length) {
      _historyPosition = -1;
    }
  }

  String? get currentText {
    return _historyPosition == -1 ? null : _evalHistory[_historyPosition];
  }
}

class _StackInfo {
  _StackInfo(this.frames, this.truncated);

  final List<StackFrameAndSourcePosition> frames;
  final bool truncated;
}

class ParsedScript {
  ParsedScript({
    required this.script,
    required this.highlighter,
    required this.executableLines,
  })  : assert(script != null),
        lines = (script.source?.split('\n') ?? const []).toList();

  final Script script;

  final SyntaxHighlighter highlighter;

  final Set<int> executableLines;

  final List<String> lines;

  int get lineCount => lines.length;
}
