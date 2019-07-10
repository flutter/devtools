// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart';

import 'globals.dart';

const flutterLibraryUri = 'package:flutter/src/widgets/binding.dart';
const flutterWebLibraryUri = 'package:flutter_web/src/widgets/binding.dart';

class ConnectedApp {
  ConnectedApp();

  Future<bool> get isFlutterApp async =>
      _isFlutterApp ?? await _libraryUriAvailable(flutterLibraryUri);

  bool _isFlutterApp;

  // TODO(kenzie): change this if screens should still be disabled when
  // flutter merges with flutter_web. See
  // https://github.com/flutter/devtools/issues/466.
  Future<bool> get isFlutterWebApp async =>
      _isFlutterWebApp ?? await _libraryUriAvailable(flutterWebLibraryUri);

  bool _isFlutterWebApp;

  Future<bool> get isProfileBuild async =>
      _isProfileBuild ?? await _connectedToProfileBuild();

  bool _isProfileBuild;

  Future<bool> get isAnyFlutterApp async =>
      await isFlutterApp || await isFlutterWebApp;

  Future<bool> _connectedToProfileBuild() async {
    assert(serviceManager.serviceAvailable.isCompleted);

    // Flutter web apps and CLI apps do not have profile and non-profile builds.
    // If this changes in the future (flutter web), we can modify this check.
    if (!await isFlutterApp) return false;

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
        .contains(uri);
  }
}
