// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'globals.dart';
import 'service_extensions.dart' as extensions;

const flutterLibraryUri = 'package:flutter/src/widgets/binding.dart';
const dartHtmlLibraryUri = 'dart:html';

class ConnectedApp {
  ConnectedApp();

  bool get appTypeKnown =>
      _isFlutterApp != null && _isProfileBuild != null && _isDartWebApp != null;

  Future<bool> get isFlutterApp async =>
      _isFlutterApp ??= await _libraryUriAvailable(flutterLibraryUri);

  bool get isFlutterAppNow {
    assert(_isFlutterApp != null);
    return _isFlutterApp;
  }

  bool _isFlutterApp;

  Future<bool> get isProfileBuild async =>
      _isProfileBuild ??= await _connectedToProfileBuild();

  bool get isProfileBuildNow {
    assert(_isProfileBuild != null);
    return _isProfileBuild;
  }

  bool _isProfileBuild;

  Future<bool> get isDartWebApp async =>
      _isDartWebApp ??= await _libraryUriAvailable(dartHtmlLibraryUri);

  bool get isDartWebAppNow {
    assert(_isDartWebApp != null);
    return _isDartWebApp;
  }

  bool _isDartWebApp;

  bool get isRunningOnDartVM => serviceManager.vm.name != 'ChromeDebugProxy';

  Future<bool> get isDartCliApp async =>
      isRunningOnDartVM && !(await isFlutterApp);

  bool get isDartCliAppNow => isRunningOnDartVM && !isFlutterAppNow;

  Future<bool> _connectedToProfileBuild() async {
    assert(serviceManager.serviceAvailable.isCompleted);
    // Only flutter apps have profile and non-profile builds. If this changes in
    // the future (flutter web), we can modify this check.
    if (!isRunningOnDartVM || !await isFlutterApp) return false;

    await serviceManager.serviceExtensionManager.extensionStatesUpdated.future;

    // The debugAllowBanner extension is only available in debug builds
    final hasDebugExtension = serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(extensions.debugAllowBanner.extension);
    return !hasDebugExtension;
  }

  Future<bool> _libraryUriAvailable(String uri) async {
    assert(serviceManager.serviceAvailable.isCompleted);
    await serviceManager.isolateManager.selectedIsolateAvailable.future;
    return serviceManager.isolateManager.selectedIsolateLibraries
        .map((ref) => ref.uri)
        .toList()
        .any((u) => u.startsWith(uri));
  }

  Future<void> initializeValues() async {
    await Future.wait([isFlutterApp, isProfileBuild, isDartWebApp]);
  }
}
