// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../shared/globals.dart';
import '../shared/primitives/utils.dart';
import '../shared/server/server.dart' as server;

final _log = Logger('ExtensionService');

// TODO(https://github.com/flutter/devtools/issues/7594): detect extensions from
// globally activated pub packages.

class ExtensionService extends DisposableController
    with AutoDisposeControllerMixin {
  ExtensionService({this.fixedAppRoot, this.ignoreServiceConnection = false});

  /// The fixed (unchanging) root file:// URI for the application this
  /// [ExtensionService] will manage DevTools extensions for.
  ///
  /// When null, [_appRoot] will be calculated from the [serviceManager]'s
  /// currently connected app. See [_initAppRoot].
  final Uri? fixedAppRoot;

  /// Whether to ignore the VM service connection for the context of this
  /// service.
  final bool ignoreServiceConnection;

  /// The root file:// URI for the Dart / Flutter application this
  /// [ExtensionService] will manage DevTools extensions for.
  Uri? _appRoot;

  /// All the DevTools extensions, runtime and static, that are available for
  /// the connected application, regardless of whether they have been enabled or
  /// disabled by the user.
  ///
  /// This set of extensions will include one version of a DevTools extension
  /// per package and will exclude any duplicates that have been marked as
  /// ignored in [_maybeIgnoreExtensions].
  ValueListenable<List<DevToolsExtensionConfig>> get availableExtensions =>
      _availableExtensions;
  final _availableExtensions = ValueNotifier<List<DevToolsExtensionConfig>>([]);

  /// DevTools extensions that are visible in their own DevTools screen (i.e.
  /// extensions that have not been manually disabled by the user).
  ValueListenable<List<DevToolsExtensionConfig>> get visibleExtensions =>
      _visibleExtensions;
  final _visibleExtensions = ValueNotifier<List<DevToolsExtensionConfig>>([]);

  /// DevTools extensions available in the user's project that do not require a
  /// running application.
  ///
  /// The user's project roots are detected from the Dart Tooling Daemon.
  /// Extensions are then derived from the `package_config.json` files contained
  /// in each of these project roots.
  ///
  /// Any static extensions that match a detected runtime extension will be
  /// ignored to prevent duplicates.
  @visibleForTesting
  var staticExtensions = <DevToolsExtensionConfig>[];

  /// DevTools extensions available for the connected VM service.
  ///
  /// These extensions are derived from the `package_config.json` file contained
  /// in the package root of the main isolate's root library.
  @visibleForTesting
  var runtimeExtensions = <DevToolsExtensionConfig>[];

  /// The set of extensions that have been ignored due to being a duplicate of
  /// some kind.
  ///
  /// An extension may be a duplicate if it was detected in both the set of
  /// runtime and static extensions, or if it is an older version of an existing
  /// extension.
  ///
  /// Ignored extensions will not be shown to the user, but their enablement
  /// states will still be updated for changes to their matching extension's
  /// state (the matching extension that is not ignored).
  final _ignoredStaticExtensionsByHashCode = <int>{};

  /// Returns the [ValueListenable] that stores the [ExtensionEnabledState] for
  /// the DevTools Extension with [extensionName].
  ValueListenable<ExtensionEnabledState> enabledStateListenable(
    String extensionName,
  ) {
    return _extensionEnabledStates.putIfAbsent(
      extensionName.toLowerCase(),
      () => ValueNotifier<ExtensionEnabledState>(
        ExtensionEnabledState.none,
      ),
    );
  }

  /// Whether extensions are actively being refreshed by the DevTools server.
  ValueListenable<bool> get refreshInProgress => _refreshInProgress;
  final _refreshInProgress = ValueNotifier(false);

  final _extensionEnabledStates =
      <String, ValueNotifier<ExtensionEnabledState>>{};

  Future<void> initialize() async {
    await _refresh();
    cancelListeners();

    // We only need to add VM service manager related listeners when we are
    // interacting with the currently connected app (i.e. when
    // [fixedAppRootUri] is null).
    if (fixedAppRoot == null && !ignoreServiceConnection) {
      addAutoDisposeListener(
        serviceConnection.serviceManager.connectedState,
        () async {
          await _refresh();
        },
      );

      // TODO(https://github.com/flutter/flutter/issues/134470): refresh on
      // hot reload and hot restart events instead.
      addAutoDisposeListener(
        serviceConnection.serviceManager.isolateManager.mainIsolate,
        () async {
          await _refresh();
        },
      );
    }

    addAutoDisposeListener(
      preferences.devToolsExtensions.showOnlyEnabledExtensions,
      () async {
        await _refreshExtensionEnabledStates();
      },
    );

    // TODO(kenz): we should also refresh the available extensions on some event
    // from the analysis server that is watching the
    // .dart_tool/package_config.json file for changes.
  }

  Future<void> _refresh() async {
    _reset();

    _appRoot = null;
    if (fixedAppRoot != null) {
      _appRoot = fixedAppRoot;
    } else if (!ignoreServiceConnection) {
      _appRoot = await _connectedAppRoot();
    }

    // TODO(kenz): gracefully handle app connections / disconnects when there
    // are already static extensions in use. The current code resets everything
    // when connection states change or hot restarts occur.

    _refreshInProgress.value = true;
    final allExtensions = await server.refreshAvailableExtensions(_appRoot);
    runtimeExtensions =
        allExtensions.where((e) => !e.detectedFromStaticContext).toList();
    staticExtensions =
        allExtensions.where((e) => e.detectedFromStaticContext).toList();
    _maybeIgnoreExtensions(connectedToApp: _appRoot != null);

    _availableExtensions.value = [
      ...runtimeExtensions,
      ...staticExtensions.where((ext) => !isExtensionIgnored(ext)),
    ]..sort();
    await _refreshExtensionEnabledStates();
    _refreshInProgress.value = false;
  }

  void _maybeIgnoreExtensions({required bool connectedToApp}) {
    // TODO(kenz): consider handling duplicates in a way that gives the user a
    // choice of which version they want to use.
    _deduplicateStaticExtensions();
    _deduplicateStaticExtensionsWithRuntimeExtensions();

    // Some extensions detected from a static context may actually require a
    // running application.
    for (final ext in staticExtensions) {
      if (!connectedToApp && ext.requiresConnection) {
        ignoreExtension(ext);
      }
    }
  }

  /// De-duplicates static extensions from other static extensions by ignoring
  /// all that are not the latest version when there are duplicates.
  void _deduplicateStaticExtensions() {
    final deduped = <String>{};
    for (final staticExtension in staticExtensions) {
      if (deduped.contains(staticExtension.name)) continue;
      deduped.add(staticExtension.name);

      final duplicates = staticExtensions
          .where((e) => e != staticExtension && e.name == staticExtension.name);
      var latest = staticExtension;
      for (final duplicate in duplicates) {
        final currentLatest = takeLatestExtension(latest, duplicate);
        if (latest != currentLatest) {
          _log.fine(
            'ignoring duplicate static extension ${duplicate.name}, '
            '${duplicate.devtoolsOptionsUri}',
          );
          ignoreExtension(latest);
          ignoreExtension(currentLatest, false);
          latest = currentLatest;
        }
      }
    }
  }

  // De-duplicates unignored static extensions from runtime extensions by
  // ignoring the static extension when there is a duplicate.
  void _deduplicateStaticExtensionsWithRuntimeExtensions() {
    for (final staticExtension
        in staticExtensions.where((ext) => !isExtensionIgnored(ext))) {
      // TODO(kenz): do we need to match on something other than name? Names
      // _should_ be unique since they match a pub package name, but this may
      // not always be true for extensions that are not published on pub or
      // extensions that do not follow best practices for naming.
      final isRuntimeDuplicate = runtimeExtensions
          .containsWhere((ext) => ext.name == staticExtension.name);
      if (isRuntimeDuplicate) {
        _log.fine(
          'ignoring runtime extension duplicate (static) '
          '${staticExtension.name}, ${staticExtension.devtoolsOptionsUri}',
        );
        ignoreExtension(staticExtension);
      }
    }
  }

  Future<void> _refreshExtensionEnabledStates() async {
    final onlyIncludeEnabled =
        preferences.devToolsExtensions.showOnlyEnabledExtensions.value;

    final visible = <DevToolsExtensionConfig>[];
    for (final extension in _availableExtensions.value) {
      final stateFromOptionsFile = await server.extensionEnabledState(
        devtoolsOptionsFileUri: extension.devtoolsOptionsUri,
        extensionName: extension.name,
      );
      final stateNotifier = _extensionEnabledStates.putIfAbsent(
        extension.name,
        () => ValueNotifier<ExtensionEnabledState>(stateFromOptionsFile),
      );
      stateNotifier.value = stateFromOptionsFile;

      final shouldIncludeInVisible = onlyIncludeEnabled
          ? stateFromOptionsFile == ExtensionEnabledState.enabled
          : stateFromOptionsFile != ExtensionEnabledState.disabled;
      if (shouldIncludeInVisible) {
        visible.add(extension);
      }
    }

    _log.fine(
      'visible extensions after refreshing - ${visible.map((e) => e.name).toList()}',
    );

    // [_visibleExtensions] should be set last so that all extension states in
    // [_extensionEnabledStates] are updated by the time we notify listeners of
    // [visibleExtensions]. It is not necessary to sort [visible] because
    // [_availableExtensions] is already sorted.
    _visibleExtensions.value = visible;
  }

  /// Sets the enabled state for [extension] and any currently ignored
  /// duplicates of [extension].
  Future<void> setExtensionEnabledState(
    DevToolsExtensionConfig extension, {
    required bool enable,
  }) async {
    // Set the enabled state for all matching extensions, even if some are
    // marked as ignored due to being a duplicate. This ensures that
    // devtools_options.yaml files are kept in sync across the project.
    final allMatchingExtensions = [
      ...runtimeExtensions,
      ...staticExtensions,
    ].where((e) => e.name == extension.name);
    await Future.wait([
      for (final ext in allMatchingExtensions)
        server.extensionEnabledState(
          devtoolsOptionsFileUri: ext.devtoolsOptionsUri,
          extensionName: ext.name,
          enable: enable,
        ),
    ]);
    await _refreshExtensionEnabledStates();
  }

  /// Marks this extension configuration as ignored or unignored based on the
  /// value of [ignore].
  ///
  /// An extension may be ignored if it is a duplicate or if it is an older
  /// version of an existing extension, for example.
  void ignoreExtension(DevToolsExtensionConfig ext, [bool ignore = true]) {
    ignore
        ? _ignoredStaticExtensionsByHashCode.add(identityHashCode(ext))
        : _ignoredStaticExtensionsByHashCode.remove(identityHashCode(ext));
  }

  /// Whether this extension configuration should be ignored.
  ///
  /// An extension may be ignored if it is a duplicate or if it is an older
  /// version of an existing extension, for example.
  bool isExtensionIgnored(DevToolsExtensionConfig ext) {
    return _ignoredStaticExtensionsByHashCode.contains(identityHashCode(ext));
  }

  void _reset() {
    _appRoot = null;
    runtimeExtensions.clear();
    staticExtensions.clear();
    _ignoredStaticExtensionsByHashCode.clear();

    _availableExtensions.value = [];
    _visibleExtensions.value = [];
    _extensionEnabledStates.clear();
    _refreshInProgress.value = false;
  }
}

Future<Uri?> _connectedAppRoot() async {
  final packageUriString =
      await serviceConnection.rootPackageDirectoryForMainIsolate();
  if (packageUriString == null) return null;
  return Uri.parse(packageUriString);
}

/// Compares the versions of extension configurations [a] and [b] and returns
/// the extension configuration with the latest version, following semantic
/// versioning rules.
@visibleForTesting
DevToolsExtensionConfig takeLatestExtension(
  DevToolsExtensionConfig a,
  DevToolsExtensionConfig b,
) {
  bool exceptionParsingA = false;
  bool exceptionParsingB = false;
  SemanticVersion? versionA;
  SemanticVersion? versionB;
  try {
    versionA = SemanticVersion.parse(a.version);
  } catch (_) {
    exceptionParsingA = true;
  }

  try {
    versionB = SemanticVersion.parse(b.version);
  } catch (_) {
    exceptionParsingB = true;
  }

  if (exceptionParsingA || exceptionParsingB) {
    if (exceptionParsingA) {
      return b;
    }
    return a;
  }

  final versionCompare = versionA!.compareTo(versionB!);
  return versionCompare >= 0 ? a : b;
}
