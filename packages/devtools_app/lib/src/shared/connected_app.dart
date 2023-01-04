// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../service/service_registrations.dart' as registrations;
import 'config_specific/import_export/import_export.dart';
import 'config_specific/logger/logger.dart' as logger;
import 'console/primitives/eval_history.dart';
import 'eval_on_dart_library.dart';
import 'globals.dart';
import 'object_tree.dart';
import 'primitives/auto_dispose.dart';
import 'title.dart';
import 'version.dart';

const flutterLibraryUri = 'package:flutter/src/widgets/binding.dart';
const dartHtmlLibraryUri = 'dart:html';

class ConnectedApp {
  ConnectedApp();

  Completer<bool> initialized = Completer();

  bool get connectedAppInitialized =>
      _isFlutterApp != null &&
      (_isFlutterApp == false ||
          _isDartWebApp == true ||
          _flutterVersion != null) &&
      _isProfileBuild != null &&
      _isDartWebApp != null;

  // TODO(kenz): investigate if we can use `libraryUriAvailableNow` instead.
  Future<bool> get isFlutterApp async => _isFlutterApp ??=
      await serviceManager.libraryUriAvailable(flutterLibraryUri);

  bool? get isFlutterAppNow {
    assert(_isFlutterApp != null);
    return _isFlutterApp == true;
  }

  bool? _isFlutterApp;

  FlutterVersion? get flutterVersionNow {
    return isFlutterAppNow! ? _flutterVersion : null;
  }

  FlutterVersion? _flutterVersion;

  final _flutterVersionCompleter = Completer<FlutterVersion?>();

  static const _flutterVersionTimeout = Duration(seconds: 3);

  Future<bool> get isProfileBuild async {
    _isProfileBuild ??= await _connectedToProfileBuild();
    return _isProfileBuild!;
  }

  bool? get isProfileBuildNow {
    assert(_isProfileBuild != null);
    return _isProfileBuild!;
  }

  bool? _isProfileBuild;

  // TODO(kenz): investigate if we can use `libraryUriAvailableNow` instead.
  Future<bool> get isDartWebApp async => _isDartWebApp ??=
      await serviceManager.libraryUriAvailable(dartHtmlLibraryUri);

  bool? get isDartWebAppNow {
    assert(_isDartWebApp != null);
    return _isDartWebApp!;
  }

  bool? _isDartWebApp;

  bool get isFlutterWebAppNow => isFlutterAppNow! && isDartWebAppNow!;

  bool get isFlutterNativeAppNow => isFlutterAppNow! && !isDartWebAppNow!;

  bool get isDebugFlutterAppNow => isFlutterAppNow! && !isProfileBuildNow!;

  bool? get isRunningOnDartVM => serviceManager.vm!.name != 'ChromeDebugProxy';

  Future<bool> get isDartCliApp async =>
      isRunningOnDartVM! && !(await isFlutterApp);

  bool get isDartCliAppNow => isRunningOnDartVM! && !isFlutterAppNow!;

  Future<bool> _connectedToProfileBuild() async {
    // If Dart or Flutter web, assume profile is false.
    if (!isRunningOnDartVM!) {
      return false;
    }

    // If eval works we're not a profile build.
    final io = EvalOnDartLibrary('dart:io', serviceManager.service!);
    // Do not log the error if this eval fails - we expect it to fail for a
    // profile build.
    final value = await io.eval(
      'Platform.isAndroid',
      isAlive: null,
      shouldLogError: false,
    );
    return !(value?.kind == 'Bool');

    // TODO(terry): Disabled below code, it will hang if flutter run --start-paused
    //              see issue https://github.com/flutter/devtools/issues/2082.
    //              Currently, if eval (see above) doesn't work then we're
    //              running in Profile mode.
    /*
    assert(serviceManager.isServiceAvailable);
    // Only flutter apps have profile and non-profile builds. If this changes in
    // the future (flutter web), we can modify this check.
    if (!isRunningOnDartVM || !await isFlutterApp) return false;

    await serviceManager.serviceExtensionManager.extensionStatesUpdated.future;

    // The debugAllowBanner extension is only available in debug builds
    final hasDebugExtension = serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(extensions.debugAllowBanner.extension);
    return !hasDebugExtension;
    */
  }

  Future<void> initializeValues() async {
    await Future.wait([isFlutterApp, isProfileBuild, isDartWebApp]);

    if (isFlutterAppNow!) {
      final flutterVersionServiceListenable = serviceManager
          .registeredServiceListenable(registrations.flutterVersion.service);
      VoidCallback listener;
      flutterVersionServiceListenable.addListener(
        listener = () async {
          final registered = flutterVersionServiceListenable.value;
          if (registered) {
            _flutterVersionCompleter.complete(
              FlutterVersion.parse(
                (await serviceManager.flutterVersion).json!,
              ),
            );
          }
        },
      );

      _flutterVersion = await _flutterVersionCompleter.future.timeout(
        _flutterVersionTimeout,
        onTimeout: () {
          logger.log(
            'Timed out trying to fetch flutter version from '
            '`ConnectedApp.initializeValues`.',
          );
          return Future<FlutterVersion?>.value();
        },
      );
      flutterVersionServiceListenable.removeListener(listener);
    }
    generateDevToolsTitle();
    initialized.complete(true);
  }
}

/// Extension methods for the [ConnectedApp] class.
///
/// Using extension methods makes testing easier, as we do not have to mock
/// these methods.
extension ConnectedAppExtension on ConnectedApp {
  String get display {
    final identifiers = <String>[];
    if (isFlutterAppNow!) {
      identifiers.addAll([
        'Flutter',
        isFlutterWebAppNow ? 'web' : 'native',
        isProfileBuildNow! ? '(profile build)' : '(debug build)',
      ]);
    } else {
      identifiers.addAll(['Dart', isDartWebAppNow! ? 'web' : 'CLI']);
    }
    return identifiers.join(' ');
  }
}

class OfflineConnectedApp extends ConnectedApp {
  OfflineConnectedApp({
    this.isFlutterAppNow,
    this.isProfileBuildNow,
    this.isDartWebAppNow,
    this.isRunningOnDartVM,
  });

  factory OfflineConnectedApp.parse(Map<String, Object>? json) {
    if (json == null) return OfflineConnectedApp();
    return OfflineConnectedApp(
      isFlutterAppNow: json[isFlutterAppKey] as bool?,
      isProfileBuildNow: json[isProfileBuildKey] as bool?,
      isDartWebAppNow: json[isDartWebAppKey] as bool?,
      isRunningOnDartVM: json[isRunningOnDartVMKey] as bool?,
    );
  }

  @override
  final bool? isFlutterAppNow;

  @override
  final bool? isProfileBuildNow;

  @override
  final bool? isDartWebAppNow;

  @override
  final bool? isRunningOnDartVM;
}

class AutocompleteCache {
  final classes = <ClassRef, Class>{};

  /// Cache of autocomplete matches for a library for code written within that
  /// library.
  ///
  /// This cache includes autocompletes from all libraries imported and exported
  /// by the library as well as all private autocompletes for the library.
  final libraryMemberAndImportsAutocomplete =
      <LibraryRef, Future<Set<String?>>>{};

  /// Cache of autocomplete matches to show for a library when that library is
  /// imported.
  ///
  /// This cache includes autocompletes from libraries exported by the library
  /// but does not include autocompletes for libraries imported by this library.
  final libraryMemberAutocomplete = <LibraryRef, Future<Set<String?>>>{};

  void _clear() {
    classes.clear();
    libraryMemberAndImportsAutocomplete.clear();
    libraryMemberAutocomplete.clear();
  }
}

class AppState extends DisposableController with AutoDisposeControllerMixin {
  AppState(ValueListenable<IsolateRef?> isolateRef) {
    addAutoDisposeListener(isolateRef, () => cache._clear());
  }

  // TODO(polina-c): add explanation for variables.
  ValueListenable<List<DartObjectNode>> get variables => _variables;
  final _variables = ValueNotifier<List<DartObjectNode>>([]);
  void setVariables(List<DartObjectNode> value) => _variables.value = value;

  ValueListenable<bool> get isPaused => _isPaused;
  final _isPaused = ValueNotifier<bool>(false);

  /// This setter should be invoked only by debugger.
  void setPausedOnBreakpoint(bool value) => _isPaused.value = value;

  ValueListenable<Frame?> get currentFrame => _currentFrame;
  final _currentFrame = ValueNotifier<Frame?>(null);
  void setCurrentFrame(Frame? value) => _currentFrame.value = value;

  final EvalHistory evalHistory = EvalHistory();

  final cache = AutocompleteCache();

  @override
  void dispose() {
    _variables.dispose();
    _isPaused.dispose();
    _currentFrame.dispose();
    super.dispose();
  }
}
