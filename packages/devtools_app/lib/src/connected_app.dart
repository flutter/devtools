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

  bool get appTypeKnown => _appTypeKnown;
  bool _appTypeKnown = false;

  FutureOr<bool> get isFlutterApp async {
    _isFlutterApp ??= await _libraryUriAvailable(flutterLibraryUri);
    _updateAppTypeKnown();
    return _isFlutterApp;
  }

  bool get isFlutterAppRaw {
    assert(_isFlutterApp != null);
    return _isFlutterApp;
  }

  bool _isFlutterApp;

  FutureOr<bool> get isProfileBuild async {
    _isProfileBuild ??= await _connectedToProfileBuild();
    _updateAppTypeKnown();
    return _isProfileBuild;
  }

  bool get isProfileBuildRaw {
    assert(_isProfileBuild != null);
    return _isProfileBuild;
  }

  bool _isProfileBuild;

  FutureOr<bool> get isDartWebApp async {
    _isDartWebApp ??= await _libraryUriAvailable(dartHtmlLibraryUri);
    _updateAppTypeKnown();
    return _isDartWebApp;
  }

  bool get isDartWebAppRaw {
    assert(_isDartWebApp != null);
    return _isDartWebApp;
  }

  bool _isDartWebApp;

  void _updateAppTypeKnown() {
    _appTypeKnown = _isFlutterApp != null &&
        _isProfileBuild != null &&
        _isDartWebApp != null;
  }

  bool get isRunningOnDartVM => serviceManager.vm.name != 'ChromeDebugProxy';

  FutureOr<bool> get isDartCliApp async =>
      isRunningOnDartVM && !(await isFlutterApp);

  bool get isDartCliAppRaw => isRunningOnDartVM && !isFlutterAppRaw;

  Future<bool> _connectedToProfileBuild() async {
    assert(serviceManager.serviceAvailable.isCompleted);
    // Only flutter apps have profile and non-profile builds. If this changes in
    // the future (flutter web), we can modify this check.
    if (!isRunningOnDartVM || !await isFlutterApp) return false;

    await serviceManager.serviceExtensionManager.extensionStatesUpdated.future;

    // The debugAllowBanner extension is only available in debug builds.
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
    await isFlutterApp;
    await isProfileBuild;
    await isDartWebApp;
    _appTypeKnown = true;
  }
}
