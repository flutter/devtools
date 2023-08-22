// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:logging/logging.dart';

import 'eval_on_dart_library.dart';
import 'flutter_version.dart';
import 'service_manager.dart';

final _log = Logger('connected_app');

const flutterLibraryUri = 'package:flutter/src/widgets/binding.dart';
const dartHtmlLibraryUri = 'dart:html';

class ConnectedApp {
  ConnectedApp(this.serviceManager);

  static const isFlutterAppKey = 'isFlutterApp';
  static const isProfileBuildKey = 'isProfileBuild';
  static const isDartWebAppKey = 'isDartWebApp';
  static const isRunningOnDartVMKey = 'isRunningOnDartVM';
  static const operatingSystemKey = 'operatingSystem';
  static const flutterVersionKey = 'flutterVersion';

  final ServiceManager? serviceManager;

  Completer<bool> initialized = Completer();

  bool get connectedAppInitialized =>
      _isFlutterApp != null &&
      (_isFlutterApp == false ||
          _isDartWebApp == true ||
          _flutterVersion != null) &&
      _isProfileBuild != null &&
      _isDartWebApp != null &&
      _operatingSystem != null;

  static const unknownOS = 'unknown_OS';

  String get operatingSystem => _operatingSystem!;
  String? _operatingSystem;

  // TODO(kenz): investigate if we can use `libraryUriAvailableNow` instead.
  Future<bool> get isFlutterApp async => _isFlutterApp ??=
      await serviceManager!.libraryUriAvailable(flutterLibraryUri);

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
      await serviceManager!.libraryUriAvailable(dartHtmlLibraryUri);

  bool? get isDartWebAppNow {
    assert(_isDartWebApp != null);
    return _isDartWebApp!;
  }

  bool? _isDartWebApp;

  bool get isFlutterWebAppNow => isFlutterAppNow! && isDartWebAppNow!;

  bool get isFlutterNativeAppNow => isFlutterAppNow! && !isDartWebAppNow!;

  bool get isDebugFlutterAppNow => isFlutterAppNow! && !isProfileBuildNow!;

  bool? get isRunningOnDartVM => serviceManager!.vm!.name != 'ChromeDebugProxy';

  Future<bool> get isDartCliApp async =>
      isRunningOnDartVM! && !(await isFlutterApp);

  bool get isDartCliAppNow => isRunningOnDartVM! && !isFlutterAppNow!;

  Future<bool> _connectedToProfileBuild() async {
    // If Dart or Flutter web, assume profile is false.
    if (!isRunningOnDartVM!) {
      return false;
    }

    // If eval works we're not a profile build.
    final io = EvalOnDartLibrary(
      'dart:io',
      serviceManager!.service!,
      serviceManager: serviceManager!,
    );
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
    assert(serviceConnectionManager.isServiceAvailable);
    // Only flutter apps have profile and non-profile builds. If this changes in
    // the future (flutter web), we can modify this check.
    if (!isRunningOnDartVM || !await isFlutterApp) return false;

    await serviceConnectionManager.serviceExtensionManager.extensionStatesUpdated.future;

    // The debugAllowBanner extension is only available in debug builds
    final hasDebugExtension = serviceConnectionManager.serviceExtensionManager
        .isServiceExtensionAvailable(extensions.debugAllowBanner.extension);
    return !hasDebugExtension;
    */
  }

  Future<void> initializeValues({void Function()? onComplete}) async {
    await Future.wait([isFlutterApp, isProfileBuild, isDartWebApp]);

    _operatingSystem = serviceManager!.vm!.operatingSystem ?? unknownOS;

    if (isFlutterAppNow!) {
      final flutterVersionServiceListenable = serviceManager!
          .registeredServiceListenable(flutterVersionService.service);
      void Function() listener;
      flutterVersionServiceListenable.addListener(
        listener = () async {
          final registered = flutterVersionServiceListenable.value;
          if (registered) {
            _flutterVersionCompleter.complete(
              FlutterVersion.parse(
                (await serviceManager!.flutterVersion).json!,
              ),
            );
          }
        },
      );

      _flutterVersion = await _flutterVersionCompleter.future.timeout(
        _flutterVersionTimeout,
        onTimeout: () {
          _log.info(
            'Timed out trying to fetch flutter version from '
            '`ConnectedApp.initializeValues`.',
          );
          return Future<FlutterVersion?>.value();
        },
      );
      flutterVersionServiceListenable.removeListener(listener);
    }
    onComplete?.call();
    initialized.complete(true);
  }

  Map<String, Object?> toJson() => {
        isFlutterAppKey: isFlutterAppNow,
        isProfileBuildKey: isProfileBuildNow,
        isDartWebAppKey: isDartWebAppNow,
        isRunningOnDartVMKey: isRunningOnDartVM,
        operatingSystemKey: operatingSystem,
        if (flutterVersionNow != null)
          flutterVersionKey: flutterVersionNow!.version,
      };
}
