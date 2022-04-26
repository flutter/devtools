// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config_specific/import_export/import_export.dart';
import '../config_specific/logger/logger.dart' as logger;
import '../service/service_registrations.dart' as registrations;
import 'eval_on_dart_library.dart';
import 'globals.dart';
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
    return isFlutterNativeAppNow ? _flutterVersion : null;
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

    // No need to check the flutter version for Flutter web apps, as the
    // performance tools that consume [flutterVersionNow] are not available for
    // flutter web apps.
    if (isFlutterNativeAppNow) {
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
