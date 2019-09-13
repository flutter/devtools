// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service/vm_service.dart';

import 'globals.dart';

const flutterLibraryUri = 'package:flutter/src/widgets/binding.dart';
const flutterWebLibraryUri = 'package:flutter_web/src/widgets/binding.dart';
const dartHtmlLibraryUri = 'package:html_shim/html.dart';

class ConnectedApp {
  ConnectedApp();

  Future<bool> get isFlutterApp async =>
      _isFlutterApp ??= await _libraryUriAvailable(flutterLibraryUri);
  bool _isFlutterApp;

  Future<bool> get isPackageFlutterWeb async =>
      _isPackageFlutterWeb ??= await _libraryUriAvailable(flutterWebLibraryUri);
  bool _isPackageFlutterWeb;

  Future<bool> get isProfileBuild async =>
      _isProfileBuild ??= await _connectedToProfileBuild();
  bool _isProfileBuild;

  Future<bool> get isAnyFlutterApp async =>
      await isFlutterApp || await isPackageFlutterWeb;

  Future<bool> get isDartWebApp async =>
      _isDartWebApp ??= await _libraryUriAvailable(dartHtmlLibraryUri);
  bool _isDartWebApp;

  bool get isRunningOnDartVM => serviceManager.vm.name != 'ChromeDebugProxy';

  Future<bool> _connectedToProfileBuild() async {
    assert(serviceManager.serviceAvailable.isCompleted);
    // Only flutter apps have profile and non-profile builds. If this changes in
    // the future (flutter web), we can modify this check.
    if (!isRunningOnDartVM || !await isFlutterApp) return false;

    try {
      final Isolate isolate = await serviceManager.service
          .getIsolate(serviceManager.isolateManager.isolates.first.id);
      // This evaluate statement will throw an error in a profile build.
      await serviceManager.service.evaluate(
        isolate.id,
        isolate.rootLib.id,
        '1+1',
      );
      // If we reach this return statement, no error was thrown and this is not
      // a profile build.
      return false;
    } on RPCError catch (_) {
      return true;
    }
  }

  Future<bool> _libraryUriAvailable(String uri) async {
    assert(serviceManager.serviceAvailable.isCompleted);
    await serviceManager.isolateManager.selectedIsolateAvailable.future;

    return serviceManager.isolateManager.selectedIsolateLibraries
        .map((ref) => ref.uri)
        .toList()
        .any((u) => u.startsWith(uri));
  }
}
