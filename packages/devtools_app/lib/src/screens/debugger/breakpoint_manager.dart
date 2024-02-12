// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../service/vm_service_wrapper.dart';
import '../../shared/diagnostics/primitives/source_location.dart';
import '../../shared/globals.dart';
import 'debugger_model.dart';

class BreakpointManager with DisposerMixin {
  BreakpointManager({this.initialSwitchToIsolate = true});

  final bool initialSwitchToIsolate;

  VmServiceWrapper get _service => serviceConnection.serviceManager.service!;

  final _breakPositionsMap = <String, List<SourcePosition>>{};

  ValueListenable<List<Breakpoint>> get breakpoints => _breakpoints;
  final _breakpoints = ValueNotifier<List<Breakpoint>>([]);

  ValueListenable<List<BreakpointAndSourcePosition>>
      get breakpointsWithLocation => _breakpointsWithLocation;
  final _breakpointsWithLocation =
      ValueNotifier<List<BreakpointAndSourcePosition>>([]);

  IsolateRef? _isolateRef;

  String get _isolateRefId => _isolateRef?.id ?? '';

  final _previousIsolateBreakpoints = <BreakpointAndSourcePosition>[];

  Future<void> initialize() async {
    final isolate =
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value;
    if (initialSwitchToIsolate && isolate != null) {
      await switchToIsolate(
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value,
      );
    }

    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.selectedIsolate,
      () async {
        await switchToIsolate(
          serviceConnection.serviceManager.isolateManager.selectedIsolate.value,
        );
      },
    );
    autoDisposeStreamSubscription(
      _service.onDebugEvent.listen(_handleDebugEvent),
    );
    autoDisposeStreamSubscription(
      _service.onIsolateEvent.listen(_handleIsolateEvent),
    );
  }

  Future<void> switchToIsolate(IsolateRef? isolateRef) async {
    _isolateRef = isolateRef;

    if (isolateRef == null) {
      _saveAndClearCurrentBreakpoints();
      return;
    }

    final breakpointsForIsolate =
        await _getBreakpointsForIsolate(_isolateRefId);
    if (breakpointsForIsolate.isNotEmpty) {
      await _establishBreakpointsForIsolate(
        breakpoints: breakpointsForIsolate,
        isolateId: _isolateRefId,
      );
    } else {
      await _reestablishBreakpointsForIsolate(isolateRef);
    }
  }

  void clearCache() {
    _breakPositionsMap.clear();
    _breakpoints.value = [];
    _breakpointsWithLocation.value = [];
  }

  Future<void> clearBreakpoints() async {
    final breakpoints = _breakpoints.value.toList();
    await Future.forEach(breakpoints, (Breakpoint breakpoint) {
      return removeBreakpoint(breakpoint);
    });
  }

  Future<Breakpoint> addBreakpoint(String scriptId, int line) =>
      _service.addBreakpoint(_isolateRefId, scriptId, line);

  Future<void> removeBreakpoint(Breakpoint breakpoint) =>
      _service.removeBreakpoint(_isolateRefId, breakpoint.id!);

  Future<void> toggleBreakpoint(ScriptRef script, int line) async {
    final selectedIsolate =
        serviceConnection.serviceManager.isolateManager.selectedIsolate.value;
    if (selectedIsolate == null) {
      // Can't toggle breakpoints if we don't have an isolate.
      return;
    }
    // The VM doesn't support debugging for system isolates and will crash on
    // a failed assert in debug mode. Disable the toggle breakpoint
    // functionality for system isolates.
    if (selectedIsolate.isSystemIsolate!) {
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

  void _saveAndClearCurrentBreakpoints() {
    _previousIsolateBreakpoints
      ..clear()
      ..addAll(_breakpointsWithLocation.value);
    _breakpoints.value.clear();
    _breakpointsWithLocation.value.clear();
  }

  void _updateAfterIsolateReload(
    Event _,
  ) async {
    // TODO(devoncarew): We need to coordinate this with other debugger clients
    // as well as pause before re-setting the breakpoints.
    // Refresh the list of scripts.
    final previousScriptRefs = scriptManager.sortedScripts.value;
    final currentScriptRefs =
        await scriptManager.retrieveAndSortScripts(_isolateRef!);
    final removedScripts = Set<ScriptRef>.of(previousScriptRefs)
        .difference(Set<ScriptRef>.of(currentScriptRefs));
    final addedScripts = Set<ScriptRef>.of(currentScriptRefs)
        .difference(Set<ScriptRef>.of(previousScriptRefs));
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

    await Future.wait([
      // Remove the breakpoints.
      for (final bp in breakpointsToRemove) removeBreakpoint(bp.breakpoint),
      // Add them back to the newer versions of those scripts.
      for (final scriptRef in addedScripts) ...[
        for (final bp in breakpointsToRemove)
          if (scriptRef.uri == bp.scriptUri)
            addBreakpoint(scriptRef.id!, bp.line!),
      ],
    ]);
  }

  Future<List<Breakpoint>> _getBreakpointsForIsolate(String isolateId) async {
    final isolate = await _service.getIsolate(isolateId);
    if (isolate.id != _isolateRefId) {
      // Current request is obsolete.
      return [];
    }

    return isolate.breakpoints ?? [];
  }

  Future<void> _establishBreakpointsForIsolate({
    required List<Breakpoint> breakpoints,
    required String isolateId,
  }) async {
    _breakpoints.value = breakpoints;
    // Build _breakpointsWithLocation from _breakpoints.
    await Future.wait(
      _breakpoints.value.map(breakpointManager.createBreakpointWithLocation),
    ).then((list) {
      if (isolateId != _isolateRefId) {
        // Current request is obsolete.
        return;
      }
      _breakpointsWithLocation.value = list.toList()..sort();
    });
  }

  Future<void> _reestablishBreakpointsForIsolate(
    IsolateRef isolateRef,
  ) async {
    final scriptUriToRef = await _getNewScriptRefsForOldBreakpoints(
      oldBreakpoints: _previousIsolateBreakpoints,
      isolateRef: isolateRef,
    );

    for (final breakpoint in _previousIsolateBreakpoints) {
      final newScriptRef = scriptUriToRef[breakpoint.scriptUri];
      final breakpointLine = breakpoint.line;

      if (newScriptRef?.id != null && breakpointLine != null) {
        await addBreakpoint(newScriptRef!.id!, breakpointLine);
      }
    }
  }

  Future<Map<String, ScriptRef>> _getNewScriptRefsForOldBreakpoints({
    required List<BreakpointAndSourcePosition> oldBreakpoints,
    required IsolateRef isolateRef,
  }) async {
    final bpScriptUris = oldBreakpoints.fold(
      <String>{},
      (scriptSet, breakpoint) {
        final scriptUri = breakpoint.scriptUri;
        if (scriptUri != null) {
          scriptSet.add(scriptUri);
        }
        return scriptSet;
      },
    );

    final newScripts = await scriptManager.retrieveAndSortScripts(isolateRef);
    final scriptUriToRef =
        newScripts.fold(<String, ScriptRef>{}, (scriptMap, script) {
      final scriptUri = script.uri;
      if (scriptUri != null && bpScriptUris.contains(scriptUri)) {
        scriptMap[scriptUri] = script;
      }
      return scriptMap;
    });

    return scriptUriToRef;
  }

  /// Return the list of valid positions for breakpoints for a given script.
  Future<List<SourcePosition>> getBreakablePositions(
    IsolateRef? isolateRef,
    Script script,
  ) async {
    final key = script.id;
    if (key == null) return [];
    if (!_breakPositionsMap.containsKey(key)) {
      _breakPositionsMap[key] =
          await _getBreakablePositions(isolateRef, script);
    }

    return _breakPositionsMap[key] ?? [];
  }

  Future<List<SourcePosition>> _getBreakablePositions(
    IsolateRef? isolateRef,
    Script script,
  ) async {
    final report = await _service.getSourceReport(
      isolateRef?.id ?? '',
      [SourceReportKind.kPossibleBreakpoints],
      scriptId: script.id,
      forceCompile: true,
    );

    final positions = <SourcePosition>[];

    for (SourceReportRange range in report.ranges!) {
      final possibleBreakpoints = range.possibleBreakpoints;
      if (possibleBreakpoints != null) {
        for (int tokenPos in possibleBreakpoints) {
          positions.add(SourcePosition.calculatePosition(script, tokenPos));
        }
      }
    }

    return positions;
  }

  Future<BreakpointAndSourcePosition> createBreakpointWithLocation(
    Breakpoint breakpoint,
  ) async {
    if (breakpoint.resolved!) {
      final bp = BreakpointAndSourcePosition.create(breakpoint);
      return scriptManager.getScript(bp.scriptRef!).then((Script script) {
        final pos = SourcePosition.calculatePosition(script, bp.tokenPos!);
        return BreakpointAndSourcePosition.create(breakpoint, pos);
      });
    } else {
      return BreakpointAndSourcePosition.create(breakpoint);
    }
  }

  void _handleIsolateEvent(Event event) {
    final eventId = event.isolate?.id;
    if (eventId != _isolateRefId) return;
    switch (event.kind) {
      case EventKind.kIsolateReload:
        _updateAfterIsolateReload(event);
        break;
    }
  }

  Future<void> _handleDebugEvent(Event event) async {
    if (event.isolate!.id != _isolateRefId) return;

    switch (event.kind) {
      // TODO(djshuckerow): switch the _breakpoints notifier to a 'ListNotifier'
      // that knows how to notify when performing a list edit operation.
      case EventKind.kBreakpointAdded:
        final breakpoint = event.breakpoint!;
        _breakpoints.value = [..._breakpoints.value, breakpoint];

        await breakpointManager
            .createBreakpointWithLocation(breakpoint)
            .then((bp) {
          final list = [
            ..._breakpointsWithLocation.value,
            bp,
          ]..sort();
          _breakpointsWithLocation.value = list;
        });

        break;
      case EventKind.kBreakpointResolved:
        final breakpoint = event.breakpoint!;
        _breakpoints.value = [
          for (var b in _breakpoints.value)
            if (b != event.breakpoint) b,
          breakpoint,
        ];

        await breakpointManager
            .createBreakpointWithLocation(breakpoint)
            .then((bp) {
          final list = _breakpointsWithLocation.value;
          // Remove the bp with the older, unresolved information from the list.
          list.removeWhere((breakpoint) => breakpoint.id == bp.id);
          // Add the bp with the newer, resolved information.
          list.add(bp);
          list.sort();
          _breakpointsWithLocation.value = list;
        });

        break;

      case EventKind.kBreakpointRemoved:
        final breakpoint = event.breakpoint;

        _breakpoints.value = [
          for (var b in _breakpoints.value)
            if (b != breakpoint) b,
        ];

        _breakpointsWithLocation.value = [
          for (var b in _breakpointsWithLocation.value)
            if (b.breakpoint != breakpoint) b,
        ];

        break;
    }
  }
}
