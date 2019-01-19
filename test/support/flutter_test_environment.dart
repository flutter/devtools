// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:devtools/globals.dart';
import 'package:devtools/service_manager.dart';
import 'package:devtools/utils.dart';
import 'package:devtools/vm_service_wrapper.dart';

import 'flutter_test_driver.dart';

/// Switch this flag to false to debug issues with non-atomic test behavior.
bool reuseTestEnvironment = true;

class FlutterTestEnvironment {
  FlutterTestEnvironment(this._runConfig);

  FlutterRunConfiguration _runConfig;
  FlutterRunTestDriver _flutter;
  FlutterRunTestDriver get flutter => _flutter;
  VmServiceWrapper _service;
  VmServiceWrapper get service => _service;

  // This function will be called before creating and running the Flutter app.
  VoidAsyncFunction _beforeSetup;
  set beforeSetup(VoidAsyncFunction f) => _beforeSetup = f;

  // This function will be called after we have ran the Flutter app and the
  // vmService is opened.
  VoidAsyncFunction _afterSetup;
  set afterSetup(VoidAsyncFunction f) => _afterSetup = f;

  // The function will be called before tearing down the test and stopping the
  // Flutter app.
  VoidAsyncFunction _beforeTearDown;
  set beforeTearDown(VoidAsyncFunction f) => _beforeTearDown = f;

  bool _needsSetup = true;

  Future<void> setupEnvironment({bool force = false}) async {
    if (!force && !_needsSetup && reuseTestEnvironment) {
      // Setting up the environment is slow so we reuse the existing environment
      // when possible.
      return;
    }
    if (_beforeSetup != null) await _beforeSetup();

    _flutter = FlutterRunTestDriver(Directory('test/fixtures/flutter_app'));
    await _flutter.run(
      withDebugger: _runConfig.withDebugger,
      pauseOnExceptions: _runConfig.pauseOnExceptions,
      trackWidgetCreation: _runConfig.trackWidgetCreation,
    );

    _service = _flutter.vmService;
    setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    await serviceManager.vmServiceOpened(_service, Completer().future);

    if (_afterSetup != null) await _afterSetup();

    _needsSetup = false;
  }

  Future<void> tearDownEnvironment({bool force = false}) async {
    if (!force && reuseTestEnvironment) {
      // Skip actually tearing down for better test performance.
      return;
    }
    if (_beforeSetup != null) await _beforeTearDown();

    await _service.allFuturesCompleted.future;
    await _flutter.stop();

    _needsSetup = true;
  }
}
