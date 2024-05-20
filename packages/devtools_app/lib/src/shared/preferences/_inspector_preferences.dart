// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'preferences.dart';

enum InspectorDetailsViewType {
  layoutExplorer(nameOverride: 'Layout Explorer'),
  widgetDetailsTree(nameOverride: 'Widget Details Tree');

  const InspectorDetailsViewType({String? nameOverride})
      : _nameOverride = nameOverride;

  final String? _nameOverride;

  String get key => _nameOverride ?? name;
}

class InspectorPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  ValueListenable<bool> get hoverEvalModeEnabled => _hoverEvalMode;
  ValueListenable<InspectorDetailsViewType> get defaultDetailsView =>
      _defaultDetailsView;
  ListValueNotifier<String> get pubRootDirectories => _pubRootDirectories;
  ValueListenable<bool> get isRefreshingPubRootDirectories =>
      _pubRootDirectoriesAreBusy;
  InspectorServiceBase? get _inspectorService =>
      serviceConnection.inspectorService;

  final _hoverEvalMode = ValueNotifier<bool>(false);
  final _pubRootDirectories = ListValueNotifier<String>([]);
  final _pubRootDirectoriesAreBusy = ValueNotifier<bool>(false);
  final _busyCounter = ValueNotifier<int>(0);
  final _defaultDetailsView = ValueNotifier<InspectorDetailsViewType>(
    InspectorDetailsViewType.layoutExplorer,
  );

  static const _hoverEvalModeStorageId = 'inspector.hoverEvalMode';
  static const _defaultDetailsViewStorageId =
      'inspector.defaultDetailsViewType';
  static const _customPubRootDirectoriesStoragePrefix =
      'inspector.customPubRootDirectories';
  String? _mainScriptDir;
  bool _checkedFlutterPubRoot = false;

  Future<void> _updateMainScriptRef() async {
    final rootLibUriString =
        (await serviceConnection.serviceManager.tryToDetectMainRootInfo())
            ?.library;
    final rootLibUri = Uri.parse(rootLibUriString ?? '');
    final directorySegments =
        rootLibUri.pathSegments.sublist(0, rootLibUri.pathSegments.length - 1);
    final rootLibDirectory = rootLibUri.replace(
      pathSegments: directorySegments,
    );
    _mainScriptDir = rootLibDirectory.path;
  }

  Future<void> init() async {
    await _initHoverEvalMode();
    // TODO(jacobr): consider initializing this first as it is not blocking.
    _initPubRootDirectories();
    await _initDefaultInspectorDetailsView();
  }

  Future<void> _initHoverEvalMode() async {
    await _updateHoverEvalMode();

    addAutoDisposeListener(_hoverEvalMode, () {
      storage.setValue(
        _hoverEvalModeStorageId,
        _hoverEvalMode.value.toString(),
      );
    });
  }

  Future<void> _updateHoverEvalMode() async {
    String? hoverEvalModeEnabledValue =
        await storage.getValue(_hoverEvalModeStorageId);

    hoverEvalModeEnabledValue ??=
        (_inspectorService?.hoverEvalModeEnabledByDefault ?? false).toString();
    setHoverEvalMode(hoverEvalModeEnabledValue == 'true');
  }

  Future<void> _initDefaultInspectorDetailsView() async {
    await _updateInspectorDetailsViewSelection();

    addAutoDisposeListener(_defaultDetailsView, () {
      storage.setValue(
        _defaultDetailsViewStorageId,
        _defaultDetailsView.value.name.toString(),
      );
    });
  }

  Future<void> _updateInspectorDetailsViewSelection() async {
    final inspectorDetailsView =
        await storage.getValue(_defaultDetailsViewStorageId);

    if (inspectorDetailsView != null) {
      _defaultDetailsView.value = InspectorDetailsViewType.values
          .firstWhere((e) => e.name.toString() == inspectorDetailsView);
    }
  }

  void _initPubRootDirectories() {
    addAutoDisposeListener(
      serviceConnection.serviceManager.connectedState,
      () async {
        if (serviceConnection.serviceManager.connectedState.value.connected) {
          await handleConnectionToNewService();
        } else {
          _handleConnectionClosed();
        }
      },
    );
    addAutoDisposeListener(_busyCounter, () {
      _pubRootDirectoriesAreBusy.value = _busyCounter.value != 0;
    });
    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.mainIsolate,
      () {
        if (_mainScriptDir != null &&
            serviceConnection.serviceManager.isolateManager.mainIsolate.value !=
                null) {
          final debuggerState =
              serviceConnection.serviceManager.isolateManager.mainIsolateState;

          if (debuggerState?.isPaused.value == false) {
            // the isolate is already unpaused, we can try to load
            // the directories
            unawaited(preferences.inspector.loadPubRootDirectories());
          } else {
            late void Function() pausedListener;

            pausedListener = () {
              if (debuggerState?.isPaused.value == false) {
                unawaited(preferences.inspector.loadPubRootDirectories());

                debuggerState?.isPaused.removeListener(pausedListener);
              }
            };

            // The isolate is still paused, listen for when it becomes unpaused.
            addAutoDisposeListener(debuggerState?.isPaused, pausedListener);
          }
        }
      },
    );
  }

  void _handleConnectionClosed() {
    _mainScriptDir = null;
    _pubRootDirectories.clear();
  }

  @visibleForTesting
  Future<void> handleConnectionToNewService() async {
    _checkedFlutterPubRoot = false;
    await _updateMainScriptRef();
    await _updateHoverEvalMode();
    await loadPubRootDirectories();
    await _updateInspectorDetailsViewSelection();
  }

  Future<void> loadPubRootDirectories() async {
    await _pubRootDirectoryBusyTracker(() async {
      await addPubRootDirectories(await _determinePubRootDirectories());
      await _refreshPubRootDirectoriesFromService();
    });
  }

  Future<List<String>> _determinePubRootDirectories() async {
    final cachedDirectories = await readCachedPubRootDirectories();
    final inferredDirectory = await _inferPubRootDirectory();

    if (inferredDirectory == null) return cachedDirectories;
    return {inferredDirectory, ...cachedDirectories}.toList();
  }

  @visibleForTesting
  Future<List<String>> readCachedPubRootDirectories() async {
    final cachedDirectoriesJson =
        await storage.getValue(_customPubRootStorageId());
    if (cachedDirectoriesJson == null) return <String>[];
    final cachedDirectories = List<String>.from(
      jsonDecode(cachedDirectoriesJson),
    );

    // Remove the Flutter pub root directory if it was accidentally cached.
    // See:
    // - https://github.com/flutter/devtools/issues/6882
    // - https://github.com/flutter/devtools/issues/6841
    if (!_checkedFlutterPubRoot && cachedDirectories.any(_isFlutterPubRoot)) {
      // Set [_checkedFlutterPubRoot] to true to avoid an infinite loop on the
      // next call to [removePubRootDirectories]:
      _checkedFlutterPubRoot = true;
      final flutterPubRootDirectories =
          cachedDirectories.where(_isFlutterPubRoot).toList();
      await removePubRootDirectories(flutterPubRootDirectories);
      cachedDirectories.removeWhere(_isFlutterPubRoot);
    }

    return cachedDirectories;
  }

  bool _isFlutterPubRoot(String directory) =>
      directory.endsWith('packages/flutter');

  /// As we aren't running from an IDE, we don't know exactly what the pub root
  /// directories are for the current project so we make a best guess based on
  /// the root library for the main isolate.
  Future<String?> _inferPubRootDirectory() async {
    final fileUriString =
        await serviceConnection.mainIsolateRootLibraryUriAsString();
    if (fileUriString == null) {
      return null;
    }
    // TODO(jacobr): Once https://github.com/flutter/flutter/issues/26615 is
    // fixed we will be able to use package: paths. Temporarily all tools
    // tracking widget locations will need to support both path formats.
    // TODO(jacobr): use the list of loaded scripts to determine the appropriate
    // package root directory given that the root script of this project is in
    // this directory rather than guessing based on url structure.
    final parts = fileUriString.split('/');
    String? pubRootDirectory;
    // For google3, we grab the top-level directory in the google3 directory
    // (e.g. /education), or the top-level directory in third_party (e.g.
    // /third_party/dart):
    if (isGoogle3Path(parts)) {
      pubRootDirectory = _pubRootDirectoryForGoogle3(parts);
    } else {
      final parts = fileUriString.split('/');

      for (int i = parts.length - 1; i >= 0; i--) {
        final part = parts[i];
        if (part == 'lib' || part == 'web') {
          pubRootDirectory = parts.sublist(0, i).join('/');
          break;
        }

        if (part == 'packages') {
          pubRootDirectory = parts.sublist(0, i + 1).join('/');
          break;
        }
      }
    }
    pubRootDirectory ??= (parts..removeLast()).join('/');
    // Make sure the root directory ends with /, otherwise we will patch with
    // other directories that start the same.
    pubRootDirectory = pubRootDirectory.endsWith('/')
        ? pubRootDirectory
        : '$pubRootDirectory/';
    return pubRootDirectory;
  }

  String? _pubRootDirectoryForGoogle3(List<String> pathParts) {
    final strippedParts = stripGoogle3(pathParts);
    if (strippedParts.isEmpty) return null;

    final topLevelDirectory = strippedParts.first;
    if (topLevelDirectory == _thirdPartyPathSegment &&
        strippedParts.length >= 2) {
      return '/${strippedParts.sublist(0, 2).join('/')}';
    } else {
      return '/${strippedParts.first}';
    }
  }

  Future<void> _cachePubRootDirectories(
    List<String> pubRootDirectories,
  ) async {
    final cachedDirectories = await readCachedPubRootDirectories();
    await storage.setValue(
      _customPubRootStorageId(),
      jsonEncode([
        ...cachedDirectories,
        ...pubRootDirectories,
      ]),
    );
  }

  Future<void> _uncachePubRootDirectories(
    List<String> pubRootDirectories,
  ) async {
    final directoriesToCache = (await readCachedPubRootDirectories())
        .where((dir) => !pubRootDirectories.contains(dir))
        .toList();
    await storage.setValue(
      _customPubRootStorageId(),
      jsonEncode(directoriesToCache),
    );
  }

  Future<void> addPubRootDirectories(
    List<String> pubRootDirectories, {
    bool shouldCache = false,
  }) async {
    // TODO(https://github.com/flutter/devtools/issues/4380):
    // Add validation to EditableList Input.
    // Directories of just / will break the inspector tree local package checks.
    pubRootDirectories.removeWhere(
      (element) => RegExp('^[/\\s]*\$').firstMatch(element) != null,
    );

    if (!serviceConnection.serviceManager.hasConnection) return;
    await _pubRootDirectoryBusyTracker(() async {
      final localInspectorService = _inspectorService;
      if (localInspectorService is! InspectorService) return;

      await localInspectorService.addPubRootDirectories(pubRootDirectories);
      if (shouldCache) {
        await _cachePubRootDirectories(pubRootDirectories);
      }
      await _refreshPubRootDirectoriesFromService();
    });
  }

  Future<void> removePubRootDirectories(
    List<String> pubRootDirectories,
  ) async {
    if (!serviceConnection.serviceManager.hasConnection) return;
    await _pubRootDirectoryBusyTracker(() async {
      final localInspectorService = _inspectorService;
      if (localInspectorService is! InspectorService) return;

      await localInspectorService.removePubRootDirectories(pubRootDirectories);
      await _uncachePubRootDirectories(pubRootDirectories);
      await _refreshPubRootDirectoriesFromService();
    });
  }

  Future<void> _refreshPubRootDirectoriesFromService() async {
    await _pubRootDirectoryBusyTracker(() async {
      final localInspectorService = _inspectorService;
      if (localInspectorService is! InspectorService) return;

      final freshPubRootDirectories =
          await localInspectorService.getPubRootDirectories();
      if (freshPubRootDirectories != null) {
        final newSet = Set<String>.of(freshPubRootDirectories);
        final oldSet = Set<String>.of(_pubRootDirectories.value);
        final directoriesToAdd = newSet.difference(oldSet);
        final directoriesToRemove = oldSet.difference(newSet);

        _pubRootDirectories
          ..removeAll(directoriesToRemove)
          ..addAll(directoriesToAdd);
      }
    });
  }

  String _customPubRootStorageId() {
    assert(_mainScriptDir != null);
    final packageId = _mainScriptDir ?? '_fallback';
    return '${_customPubRootDirectoriesStoragePrefix}_$packageId';
  }

  Future<void> _pubRootDirectoryBusyTracker(
    Future<void> Function() callback,
  ) async {
    try {
      _busyCounter.value++;
      await callback();
    } finally {
      _busyCounter.value--;
    }
  }

  /// Change the value for the hover eval mode setting.
  void setHoverEvalMode(bool enableHoverEvalMode) {
    _hoverEvalMode.value = enableHoverEvalMode;
  }

  void setDefaultInspectorDetailsView(InspectorDetailsViewType value) {
    _defaultDetailsView.value = value;
  }
}
