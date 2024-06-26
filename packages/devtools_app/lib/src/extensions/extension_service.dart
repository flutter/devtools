// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../shared/globals.dart';
import '../shared/primitives/utils.dart';
import '../shared/server/server.dart' as server;
import 'extension_service_helpers.dart';

final _log = Logger('ExtensionService');

// TODO(https://github.com/flutter/devtools/issues/7594): detect extensions from
// globally activated pub packages.

/// Data pattern containing a [List] of available extensions and a [List] of
/// visible extensions.
typedef DevToolsExtensionsGroup = ({
  /// All the DevTools extensions, runtime and static, that are available for
  /// the connected application, regardless of whether they have been enabled or
  /// disabled by the user.
  ///
  /// This set of extensions will include one version of a DevTools extension
  /// per package and will exclude any duplicates that have been marked as
  /// ignored in [_maybeIgnoreExtensions].
  List<DevToolsExtensionConfig> availableExtensions,

  /// DevTools extensions that are visible in their own DevTools screen (i.e.
  /// extensions that have not been manually disabled by the user).
  List<DevToolsExtensionConfig> visibleExtensions,
});

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

  /// A listenable for the current set of DevTools extensions.
  ///
  /// The [DevToolsExtensionsGroup] contains both the List of available
  /// extensions and the List of visible extensions. These values are updated
  /// in tandem in the common case, so storing them as a group saves listeners
  /// from having to listen to two separate notifiers.
  ValueListenable<DevToolsExtensionsGroup> get currentExtensions =>
      _currentExtensions;
  final _currentExtensions = ValueNotifier<DevToolsExtensionsGroup>(
    (
      availableExtensions: <DevToolsExtensionConfig>[],
      visibleExtensions: <DevToolsExtensionConfig>[],
    ),
  );

  /// All the DevTools extensions, runtime and static, that are available for
  /// the connected application, regardless of whether they have been enabled or
  /// disabled by the user.
  ///
  /// This set of extensions will include one version of a DevTools extension
  /// per package and will exclude any duplicates that have been marked as
  /// ignored in [_maybeIgnoreExtensions].
  List<DevToolsExtensionConfig> get availableExtensions =>
      _currentExtensions.value.availableExtensions;

  /// DevTools extensions that are visible in their own DevTools screen (i.e.
  /// extensions that have not been manually disabled by the user).
  List<DevToolsExtensionConfig> get visibleExtensions =>
      _currentExtensions.value.visibleExtensions;

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
        await _refreshExtensionEnabledStates(
          availableExtensions: _currentExtensions.value.availableExtensions,
        );
      },
    );

    // TODO(kenz): we should also refresh the available extensions on some event
    // from the analysis server that is watching the
    // .dart_tool/package_config.json file for changes.
  }

  Future<void> _refresh() async {
    _log.fine('refreshing the ExtensionService');
    _reset();

    _appRoot = null;
    if (fixedAppRoot != null) {
      _appRoot = fixedAppRoot;
    } else if (!ignoreServiceConnection &&
        serviceConnection.serviceManager.connectedState.value.connected &&
        serviceConnection.serviceManager.isolateManager.mainIsolate.value !=
            null) {
      _appRoot = await serviceConnection.serviceManager
          .connectedAppPackageRoot(dtdManager);
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

    // TODO(kenz): consider handling duplicates in a way that gives the user a
    // choice of which version they want to use.
    _deduplicateStaticExtensions();
    _deduplicateStaticExtensionsWithRuntimeExtensions();

    final available = [
      ...runtimeExtensions,
      ...staticExtensions.where((ext) => !isExtensionIgnored(ext)),
    ]..sort();
    await _refreshExtensionEnabledStates(availableExtensions: available);
    _refreshInProgress.value = false;
  }

  /// De-duplicates static extensions from other static extensions by ignoring
  /// all that are not the latest version when there are duplicates.
  void _deduplicateStaticExtensions() {
    deduplicateExtensionsAndTakeLatest(
      staticExtensions,
      onSetIgnored: setExtensionIgnored,
      logger: _log,
      extensionType: 'static',
    );
  }

  // De-duplicates unignored static extensions from runtime extensions by
  // ignoring the static extension when there is a duplicate.
  void _deduplicateStaticExtensionsWithRuntimeExtensions() {
    if (runtimeExtensions.isEmpty) return;
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
          'ignoring duplicate static extension ${staticExtension.identifier} '
          'at ${staticExtension.devtoolsOptionsUri} in favor of a matching '
          'runtime extension.',
        );
        setExtensionIgnored(staticExtension, ignore: true);
      }
    }
  }

  Future<void> _refreshExtensionEnabledStates({
    required List<DevToolsExtensionConfig> availableExtensions,
  }) async {
    final onlyIncludeEnabled =
        preferences.devToolsExtensions.showOnlyEnabledExtensions.value;

    final visible = <DevToolsExtensionConfig>[];
    for (final extension in availableExtensions) {
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

    // It is not necessary to sort [visible] because [availableExtensions] is
    // already sorted.
    _currentExtensions.value = (
      availableExtensions: availableExtensions,
      visibleExtensions: visible,
    );
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
    await _refreshExtensionEnabledStates(
      availableExtensions: _currentExtensions.value.availableExtensions,
    );
  }

  /// Marks this extension configuration as ignored or unignored based on the
  /// value of [ignore].
  ///
  /// An extension may be ignored if it is a duplicate or if it is an older
  /// version of an existing extension, for example.
  @visibleForTesting
  void setExtensionIgnored(
    DevToolsExtensionConfig ext, {
    required bool ignore,
  }) {
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
    _log.fine('resetting the ExtensionService');
    _appRoot = null;
    runtimeExtensions.clear();
    staticExtensions.clear();
    _ignoredStaticExtensionsByHashCode.clear();
    _currentExtensions.value = (
      availableExtensions: <DevToolsExtensionConfig>[],
      visibleExtensions: <DevToolsExtensionConfig>[],
    );
    _extensionEnabledStates.clear();
    _refreshInProgress.value = false;
  }

  @override
  void dispose() {
    for (final notifier in _extensionEnabledStates.values) {
      notifier.dispose();
    }
    _currentExtensions.dispose();
    _refreshInProgress.dispose();
    super.dispose();
  }
}
