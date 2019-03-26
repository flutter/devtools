// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart';

import 'eval_on_dart_library.dart';
import 'globals.dart';

const flutterLibraryUri = 'package:flutter/src/widgets/binding.dart';
const flutterWebLibraryUri = 'package:flutter_web/src/widgets/binding.dart';

Future<bool> isFlutterApp() async {
  final EvalOnDartLibrary flutterLibrary = EvalOnDartLibrary(
    [flutterLibraryUri],
    serviceManager.service,
  );

  try {
    await flutterLibrary.libraryRef;
  } on LibraryNotFound catch (_) {
    return false;
  }
  return true;
}

Future<bool> isFlutterWebApp() async {
  // TODO(kenzie): fix this if screens should still be disabled when flutter
  // merges with flutter_web.
  final EvalOnDartLibrary flutterWebLibrary = EvalOnDartLibrary(
    [flutterWebLibraryUri],
    serviceManager.service,
  );

  try {
    await flutterWebLibrary.libraryRef;
  } on LibraryNotFound catch (_) {
    return false;
  }
  return true;
}

Future<bool> isProfileBuild() async {
  // Flutter web apps do not have profile and non-profile builds. If this
  // changes in the future, we can remove this check.
  final _isFlutterWebApp = await isFlutterWebApp();
  if (_isFlutterWebApp) return false;

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
  } on RPCError catch (e) {
    return true;
  }
}
