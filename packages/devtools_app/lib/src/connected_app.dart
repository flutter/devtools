// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service/vm_service.dart';

import 'globals.dart';
import 'service_extensions.dart' as extensions;

const flutterLibraryUri = 'package:flutter/src/widgets/binding.dart';
const dartHtmlLibraryUri = 'dart:html';

class ConnectedApp {
  ConnectedApp();

  bool get appTypeKnown =>
      _isFlutterApp != null && _isProfileBuild != null && _isDartWebApp != null;

  // TODO(kenz): investigate if we can use `libraryUriAvailableNow` instead.
  Future<bool> get isFlutterApp async => _isFlutterApp ??=
      await serviceManager.libraryUriAvailable(flutterLibraryUri);

  bool get isFlutterAppNow {
    assert(_isFlutterApp != null);
    return _isFlutterApp;
  }

  bool _isFlutterApp;

  Future<bool> get isProfileBuild async {
    // If we have one isolate check if paused on start?
    final isolates = serviceManager.isolateManager.isolates;
    if (isolates.length == 1) {
      final isolate = await serviceManager.service.getIsolate(isolates[0].id);
      if (isolate.pauseEvent.kind == EventKind.kPauseStart) {
        // Application started with --start-paused, assume profile build is
        // false - debugging memory. Otherwise, _connectedToProfileBuild
        // waits forever when paused start.
        // TODO(terry): Revisit this assumption.
        _isProfileBuild = false;
        return _isProfileBuild;
      }
    }

    _isProfileBuild ??= await _connectedToProfileBuild();
    return _isProfileBuild;
  }

  bool get isProfileBuildNow {
    assert(_isProfileBuild != null);
    return _isProfileBuild;
  }

  bool _isProfileBuild;

  // TODO(kenz): investigate if we can use `libraryUriAvailableNow` instead.
  Future<bool> get isDartWebApp async => _isDartWebApp ??=
      await serviceManager.libraryUriAvailable(dartHtmlLibraryUri);

  bool get isDartWebAppNow {
    assert(_isDartWebApp != null);
    return _isDartWebApp;
  }

  bool _isDartWebApp;

  bool get isFlutterWebAppNow => isFlutterAppNow && isDartWebAppNow;

  bool get isDebugFlutterAppNow => isFlutterAppNow && !isProfileBuildNow;

  bool get isRunningOnDartVM => serviceManager.vm.name != 'ChromeDebugProxy';

  Future<bool> get isDartCliApp async =>
      isRunningOnDartVM && !(await isFlutterApp);

  bool get isDartCliAppNow => isRunningOnDartVM && !isFlutterAppNow;

  Future<bool> _connectedToProfileBuild() async {
    assert(serviceManager.isServiceAvailable);
    // Only flutter apps have profile and non-profile builds. If this changes in
    // the future (flutter web), we can modify this check.
    if (!isRunningOnDartVM || !await isFlutterApp) return false;

    await serviceManager.serviceExtensionManager.extensionStatesUpdated.future;

    // The debugAllowBanner extension is only available in debug builds
    final hasDebugExtension = serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(extensions.debugAllowBanner.extension);
    return !hasDebugExtension;
  }

  Future<void> initializeValues() async {
    await Future.wait([isFlutterApp, isProfileBuild, isDartWebApp]);
  }
}
