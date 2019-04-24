// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:devtools/src/globals.dart';
import 'package:devtools/src/service_manager.dart';
import 'package:devtools/src/utils.dart';
import 'package:devtools/src/vm_service_wrapper.dart';

import 'flutter_test_driver.dart';

final flutterVersion = Platform.environment['FLUTTER_VERSION'];

class FlutterTestEnvironment {
  FlutterTestEnvironment(
    this._runConfig, {
    this.testAppDirectory = '../../fixtures/flutter_app',
  });

  FlutterRunConfiguration _runConfig;
  FlutterRunConfiguration get runConfig => _runConfig;
  final String testAppDirectory;
  FlutterRunTestDriver _flutter;
  FlutterRunTestDriver get flutter => _flutter;
  VmServiceWrapper _service;
  VmServiceWrapper get service => _service;

  // This function will be called after we have ran the Flutter app and the
  // vmService is opened.
  VoidAsyncFunction _afterNewSetup;
  set afterNewSetup(VoidAsyncFunction f) => _afterNewSetup = f;

  // This function will be called for every call to [setupEnvironment], even
  // when the setup is not forced or triggered by a new FlutterRunConfiguration.
  VoidAsyncFunction _afterEverySetup;
  set afterEverySetup(VoidAsyncFunction f) => _afterEverySetup = f;

  // The function will be called before tearing down the test and stopping the
  // Flutter app.
  VoidAsyncFunction _beforeTearDown;
  set beforeTearDown(VoidAsyncFunction f) => _beforeTearDown = f;

  bool _needsSetup = true;

  // Switch this flag to false to debug issues with non-atomic test behavior.
  bool reuseTestEnvironment = true;

  Future<void> setupEnvironment({
    bool force = false,
    FlutterRunConfiguration config,
  }) async {
    // Setting up the environment is slow so we reuse the existing environment
    // when possible.
    if (force ||
        _needsSetup ||
        !reuseTestEnvironment ||
        _isNewRunConfig(config)) {
      // If we already have a running test device, stop it before setting up a
      // new one.
      if (_flutter != null) await tearDownEnvironment(force: true);

      // Update the run configuration if we have a new one.
      if (_isNewRunConfig(config)) _runConfig = config;

      _needsSetup = false;

      _flutter = FlutterRunTestDriver(Directory(testAppDirectory));
      await _flutter.run(runConfig: _runConfig);

      _service = _flutter.vmService;
      setGlobal(ServiceConnectionManager, ServiceConnectionManager());
      await serviceManager.vmServiceOpened(_service,
          onClosed: Completer().future);

      if (_afterNewSetup != null) await _afterNewSetup();
    }
    if (_afterEverySetup != null) await _afterEverySetup();
  }

  Future<void> tearDownEnvironment({bool force = false}) async {
    if (_needsSetup) {
      // _needsSetup=true means we've never run setup code or already cleaned up
      return;
    }
    if (!force && reuseTestEnvironment) {
      // Skip actually tearing down for better test performance.
      return;
    }
    if (_beforeTearDown != null) await _beforeTearDown();

    await _service.allFuturesCompleted.timeout(const Duration(seconds: 20),
        onTimeout: () {
      throw 'Timed out waiting for futures to complete during teardown. '
          '${_service.activeFutures.length} futures remained:\n\n'
          '  ${_service.activeFutures.map((tf) => tf.name).join('\n  ')}';
    });
    await _flutter.stop();
    _flutter = null;

    _needsSetup = true;
  }

  bool _isNewRunConfig(FlutterRunConfiguration config) {
    return config != null && config != _runConfig;
  }
}
