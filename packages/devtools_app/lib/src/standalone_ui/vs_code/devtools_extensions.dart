// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../extensions/extension_service.dart';
import '../../extensions/extension_service_helpers.dart';
import '../../service/editor/api_classes.dart';
import '../../shared/globals.dart';

final _devToolsExtensionsLog = Logger('Flutter Sidebar - DevTools Extensions');

class SidebarDevToolsExtensionsController extends DisposableController
    with AutoDisposeControllerMixin {
  /// Stores the project roots that we have looked up extensions for.
  ///
  /// The original extensions lookup for the IDE workspace searches all of the
  /// project roots as determined by DTD. To ensure we have looked up extensions
  /// for each debug session, we use this set check the existence of the debug
  /// session's project root URI. By checking whether we've already detected
  /// extensions for a debug session root before performing another lookup, we
  /// can avoid unnecessary work.
  var _searchedProjectRoots = <Uri>{};

  /// Active [ExtensionService] for the sidebar view.
  ///
  /// There will be an [ExtensionService] responsible for detecting extensions
  /// for the entire workspace, and there may be additional [ExtensionService]s
  /// for each debug session that has a project root URI outside of the IDE
  /// workspace (unlikely, but possible).
  ///
  /// [ExtensionService]s are indexed by a nullable URI, which will either be
  /// null for the service that detects extensions for the entire workspace,
  /// or will be the project root URI for any debug session whose root is not
  /// contained within the workspace.
  ///
  /// The keys for this map match the keys used for [_extensionsByRootUri] and
  ///  [_listenersByRootUri].
  final _extensionServiceByRootUri = <Uri?, ExtensionService>{};

  /// DevTools extensions available for each [ExtensionService] in
  /// [_extensionServiceByRootUri].
  ///
  /// Each [List] of extensions is indexed by a nullable URI, which will either
  /// be null for the extensions that were detected for the entire workspace, or
  /// will be the project root URI for any debug session whose root is not
  /// contained within the workspace.
  ///
  /// The keys for this map match the keys used for [_extensionServiceByRootUri]
  /// and [_listenersByRootUri].
  final _extensionsByRootUri = <Uri?, List<DevToolsExtensionConfig>>{};

  /// Listeners added for each [ExtensionService] in
  /// [_extensionServiceByRootUri].
  ///
  /// Each [List] of listeners is indexed by a nullable URI, which will either
  /// be null for the listeners that were added to the [ExtensionService] for
  /// the entire workspace, or will be the project root URI for any debug
  /// session whose root is not contained within the workspace.
  ///
  /// The keys for this map match the keys used for [_extensionServiceByRootUri]
  /// and [_extensionsByRootUri].
  final _listenersByRootUri = <Uri?, List<VoidCallback>>{};

  /// Extensions that will be shown in the DevTools Extensions sidebar section.
  ///
  /// These are composed of any extensions detected from the static context of
  /// the workspace, as well as any detected from active debug sessions.
  /// Extensions from [_extensionsById] are de-duplicated in
  /// [_deduplicateAndUpdate].
  ValueListenable<List<DevToolsExtensionConfig>> get uniqueExtensions =>
      _uniqueExtensions;
  final _uniqueExtensions =
      ValueNotifier<List<DevToolsExtensionConfig>>(<DevToolsExtensionConfig>[]);

  /// The set of extension hashcodes that have been ignored due to being a
  /// duplicate of some kind.
  ///
  /// This set will contain identity hash codes for [DevToolsExtensionConfig]
  /// objects that are in [_extensionsById], but not in [_uniqueExtensions].
  final _ignoredExtensionsByHashCode = <int>{};

  /// The current set of debug sessions available in the editor.
  late Map<String, EditorDebugSession> _debugSessions;

  Future<void> init(Map<String, EditorDebugSession> debugSessions) async {
    _debugSessions = debugSessions;
    await _initExtensionsForWorkspace();
    await _initExtensionsForDebugSessions();
  }

  Future<void> updateForDebugSessions(
    Map<String, EditorDebugSession> newDebugSessions,
  ) async {
    // Cleanup state for debug sessions that are no longer available.
    final removed =
        _debugSessions.keys.toSet().difference(newDebugSessions.keys.toSet());
    for (final sessionId in removed) {
      final session = _debugSessions[sessionId]!;
      final rootFileUri = session.projectRootFileUri;
      if (rootFileUri != null) {
        _shutdownServiceByRootUri(rootFileUri);
      }
    }

    await _initExtensionsForDebugSessions();
  }

  Future<void> _initExtensionsForWorkspace() async {
    if (dtdManager.hasConnection) {
      _searchedProjectRoots = Set.of(
        (await dtdManager.connection.value!.getProjectRoots(
              depth: staticExtensionsSearchDepth,
            ))
                .uris ??
            <Uri>[],
      );
    }
    // Pass a null project root URI to initialize the set of extensions
    // available for the entire workspace.
    await _detectExtensions(null);
  }

  Future<void> _initExtensionsForDebugSessions() async {
    for (final debugSession in _debugSessions.values) {
      final fileUri = debugSession.projectRootFileUri;
      if (fileUri != null && !_searchedProjectRoots.contains(fileUri)) {
        _searchedProjectRoots.add(fileUri);
        await _detectExtensions(fileUri);
      }
    }
  }

  void _shutdownServiceByRootUri(Uri? projectRootUri) {
    _searchedProjectRoots.remove(projectRootUri);
    _extensionServiceByRootUri.remove(projectRootUri)?.dispose();
    _extensionsByRootUri.remove(projectRootUri);
    (_listenersByRootUri.remove(projectRootUri) ?? []).forEach(cancelListener);
  }

  // TODO(kenz): support a way to update the extensions when there is a relevant
  // update to the IDE workspace or to a debug session. The set of available
  // extensions could change if a user adds / removes a directory to / from
  // their IDE workspace, and generally anytime the pub solve for a project in
  // the workspace or for a debug session changes. We will likely need some
  // watch event from the IDE or analysis server to signal when any
  // package_config.json file in the workspace changes.
  Future<void> _detectExtensions(Uri? projectRootUri) async {
    final extensionService = projectRootUri == null
        ?
        // A null [projectRootUri] indicates that this is an extensions lookup
        // for the entire workspace, not a debug session with a fixed root URI.
        ExtensionService(ignoreServiceConnection: true)
        : ExtensionService(
            fixedAppRoot: projectRootUri,
            ignoreServiceConnection: true,
          );

    assert(
      !_extensionServiceByRootUri.containsKey(projectRootUri),
      'The initialization for the ExtensionService for root uri '
      '$projectRootUri should only happen once.',
    );
    _extensionServiceByRootUri[projectRootUri] = extensionService;

    await extensionService.initialize();
    _extensionsByRootUri[projectRootUri] = extensionService.visibleExtensions;

    void listener() {
      _extensionsByRootUri[projectRootUri] = extensionService.visibleExtensions;
      _deduplicateAndUpdate();
    }

    addAutoDisposeListener(extensionService.currentExtensions, listener);
    _listenersByRootUri
        .putIfAbsent(projectRootUri, () => <VoidCallback>[])
        .add(listener);
  }

  void _deduplicateAndUpdate() {
    final allExtensions = _extensionsByRootUri.values.fold(
      <DevToolsExtensionConfig>[],
      (all, extensionList) => all..addAll(extensionList),
    );

    _ignoredExtensionsByHashCode.clear();
    deduplicateExtensionsAndTakeLatest(
      allExtensions,
      onSetIgnored: (DevToolsExtensionConfig ext, {required bool ignore}) {
        ignore
            ? _ignoredExtensionsByHashCode.add(identityHashCode(ext))
            : _ignoredExtensionsByHashCode.remove(identityHashCode(ext));
      },
      logger: _devToolsExtensionsLog,
      extensionType: 'all',
    );

    final deduped = allExtensions
        .where(
          (ext) =>
              !_ignoredExtensionsByHashCode.contains(identityHashCode(ext)),
        )
        .toList();
    _uniqueExtensions.value = deduped..sort();
  }

  @override
  void dispose() {
    for (final e in _extensionServiceByRootUri.values) {
      e.dispose();
    }
    _extensionServiceByRootUri.clear();
    _extensionsByRootUri.clear();
    _listenersByRootUri.clear();
    _ignoredExtensionsByHashCode.clear();
    _uniqueExtensions.dispose();
    super.dispose();
  }
}

extension on EditorDebugSession {
  Uri? get projectRootFileUri {
    final rootPath = projectRootPath;
    if (rootPath == null) return null;

    // This file path might be a Windows path but because this code runs in
    // the web, Uri.file() will not handle it correctly.
    //
    // Since all paths are absolute, assume that if the path contains `\` and
    // not `/` then it's Windows.
    final isWindows = rootPath.contains(r'\') && !rootPath.contains(r'/');
    final fileUri = Uri.file(rootPath, windows: isWindows);
    assert(fileUri.isScheme('file'));
    return fileUri;
  }
}
