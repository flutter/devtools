// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../service/vm_service_wrapper.dart';
import '../globals.dart';

class ScriptManager extends DisposableController
    with AutoDisposeControllerMixin {
  ScriptManager() {
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      if (serviceConnection.serviceManager.connectedState.value.connected) {
        if (serviceConnection.serviceManager.service == _lastService) return;
        _lastService = serviceConnection.serviceManager.service;
        _scriptCache.clear();
      }
    });
    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.selectedIsolate,
      () {
        _scriptCache.clear();
      },
    );
  }

  /// Return the sorted list of ScriptRefs active in the current isolate.
  ValueListenable<List<ScriptRef>> get sortedScripts => _sortedScripts;

  final _sortedScripts = ValueNotifier<List<ScriptRef>>([]);

  VmServiceWrapper get _service => serviceConnection.serviceManager.service!;
  VmServiceWrapper? _lastService;

  IsolateRef get _currentIsolate =>
      serviceConnection.serviceManager.isolateManager.selectedIsolate.value!;

  final _scriptCache = _ScriptCache();

  /// Refreshes the current set of scripts, updating [sortedScripts]. Returns
  /// the updated value of [sortedScripts].
  Future<List<ScriptRef>> retrieveAndSortScripts(IsolateRef isolateRef) async {
    final scriptList = await _service.getScripts(isolateRef.id!);
    // We filter out non-unique ScriptRefs here (dart-lang/sdk/issues/41661).
    final scriptRefs = Set.of(scriptList.scripts!).toList();
    scriptRefs.sort((a, b) {
      // We sort uppercase so that items like dart:foo sort before items like
      // dart:_foo.
      return a.uri!.toUpperCase().compareTo(b.uri!.toUpperCase());
    });
    _sortedScripts.value = scriptRefs;
    return scriptRefs;
  }

  ScriptRef? scriptRefForUri(String? uri) {
    return _sortedScripts.value.firstWhereOrNull(
      (element) => element.uri != null && element.uri == uri,
    );
  }

  /// Return a cached [Script] for the given [ScriptRef], returning null
  /// if there is no cached [Script].
  Script? getScriptCached(ScriptRef scriptRef) {
    return _scriptCache.getScriptCached(scriptRef);
  }

  /// Retrieve the [Script] for the given [ScriptRef].
  ///
  /// This caches the script lookup for future invocations.
  Future<Script> getScript(ScriptRef scriptRef) {
    return _scriptCache.getScript(_service, _currentIsolate, scriptRef);
  }

  Script? getScriptByUri(String uri) {
    return _scriptCache.getScriptByUri(uri);
  }
}

class _ScriptCache {
  _ScriptCache();

  final _scripts = <String, Script>{};
  final _uriToScript = <String, Script>{};
  final _inProgress = <String, Future<Script>>{};

  /// Return a cached [Script] for the given [ScriptRef], returning null
  /// if there is no cached [Script].
  Script? getScriptCached(ScriptRef scriptRef) {
    return _scripts[scriptRef.id];
  }

  Script? getScriptByUri(String uri) {
    return _uriToScript[uri];
  }

  /// Retrieve the [Script] for the given [ScriptRef].
  ///
  /// This caches the script lookup for future invocations.
  Future<Script> getScript(
    VmService vmService,
    IsolateRef isolateRef,
    ScriptRef scriptRef,
  ) {
    final scriptId = scriptRef.id!;
    final script = _scripts[scriptId];
    if (script != null) {
      return Future.value(script);
    }

    if (_inProgress.containsKey(scriptId)) {
      return _inProgress[scriptId]!;
    }

    // We make a copy here as the future could complete after a clear()
    // operation is performed.
    final scripts = _scripts;

    final Future<Script> scriptFuture = vmService
        .getObject(isolateRef.id!, scriptId)
        .then((obj) => obj as Script);
    _inProgress[scriptId] = scriptFuture;

    unawaited(
      scriptFuture.then((script) {
        scripts[scriptId] = script;
        _uriToScript[script.uri!] = script;
      }),
    );

    return scriptFuture;
  }

  void clear() {
    _scripts.clear();
    _inProgress.clear();
  }
}
