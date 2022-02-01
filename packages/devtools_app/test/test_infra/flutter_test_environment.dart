// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io';

import 'package:devtools_app/devtools_app.dart';

import 'flutter_test_driver.dart';

final flutterVersion = Platform.environment['FLUTTER_VERSION'];

typedef FlutterDriverFactory = FlutterTestDriver Function(
    Directory testAppDirectory);

/// The default [FlutterDriverFactory] method. Runs a normal flutter app.
FlutterRunTestDriver defaultFlutterRunDriver(Directory appDir) =>
    FlutterRunTestDriver(appDir);

final defaultFlutterExecutable = Platform.isWindows ? 'flutter.bat' : 'flutter';

class FlutterTestEnvironment {
  FlutterTestEnvironment(
    this._runConfig, {
    this.testAppDirectory = 'test/fixtures/flutter_app',
    FlutterDriverFactory flutterDriverFactory,
  })  : _flutterDriverFactory = flutterDriverFactory ?? defaultFlutterRunDriver,
        _flutterBranch = _parseFlutterBranchFromEnv();

  static String _parseFlutterBranchFromEnv() {
    const flutterBranch = String.fromEnvironment('FLUTTER_BRANCH');
    return flutterBranch.isNotEmpty ? flutterBranch : null;
  }

  FlutterRunConfiguration _runConfig;
  FlutterRunConfiguration get runConfig => _runConfig;
  FlutterRunTestDriver _flutter;
  FlutterRunTestDriver get flutter => _flutter;
  VmServiceWrapper _service;
  VmServiceWrapper get service => _service;

  /// Path relative to the `devtools_app` dir for the test fixture.
  final String testAppDirectory;

  /// A factory method which can return a [FlutterRunTestDriver] for a test
  /// fixture directory.
  final FlutterDriverFactory _flutterDriverFactory;

  /// The Flutter branch to use for this test environment.
  ///
  /// This channel can be specified using the --dart-define flag
  /// (e.g. flutter test --dart-define=FLUTTER_BRANCH=master test/my_test.dart)
  final String _flutterBranch;

  /// The temporary directory that will hold the flutter sdk checkout at branch
  /// [_flutterBranch].
  ///
  /// If [_flutterBranch] is null, this will be null also.
  Directory tmpFlutterDirectory;

  // This function will be called after we have ran the Flutter app and the
  // vmService is opened.
  Future<void> Function() _afterNewSetup;
  set afterNewSetup(Future<void> Function() f) => _afterNewSetup = f;

  // This function will be called for every call to [setupEnvironment], even
  // when the setup is not forced or triggered by a new FlutterRunConfiguration.
  Future<void> Function() _afterEverySetup;
  set afterEverySetup(Future<void> Function() f) => _afterEverySetup = f;

  // The function will be called before the each tear down, including those that
  // skip work due to not being forced. This usually means for each individual
  // test, but it will also run as part of a final forced tear down so should
  // be tolerable to being called twice after a single test.
  Future<void> Function() _beforeEveryTearDown;
  set beforeEveryTearDown(Future<void> Function() f) =>
      _beforeEveryTearDown = f;

  // The function will be called before the final forced teardown at the end
  // of the test suite (which will then stop the Flutter app).
  Future<void> Function() _beforeFinalTearDown;
  set beforeFinalTearDown(Future<void> Function() f) =>
      _beforeFinalTearDown = f;

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

      var flutterExecutable = defaultFlutterExecutable;

      if (_flutterBranch != null) {
        // Create a temproary location to store the new flutter SDK.
        tmpFlutterDirectory =
            Directory('${Directory.systemTemp.path}/flutter-sdk-tmp')
              ..createSync();

        print('Cloning the Flutter $_flutterBranch branch...');
        final gitCloneProcess = await Process.start(
          'git',
          [
            'clone',
            'https://github.com/flutter/flutter.git',
            '--branch',
            '$_flutterBranch',
          ],
          workingDirectory: tmpFlutterDirectory.path,
        );
        await gitCloneProcess.exitCode;

        flutterExecutable = '${tmpFlutterDirectory.path}/flutter/bin/flutter';
      }

      _flutter = _flutterDriverFactory(Directory(testAppDirectory));
      await _flutter.run(
        flutterExecutable: flutterExecutable,
        runConfig: _runConfig,
      );

      _service = _flutter.vmService;
      final preferencesController = PreferencesController();
      await preferencesController.init();
      setGlobal(ServiceConnectionManager, ServiceConnectionManager());
      setGlobal(PreferencesController, preferencesController);
      setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());

      // Clear out VM service calls from the test driver.
      // ignore: invalid_use_of_visible_for_testing_member
      _service.clearVmServiceCalls();

      await serviceManager.vmServiceOpened(
        _service,
        onClosed: Completer().future,
      );

      if (_afterNewSetup != null) await _afterNewSetup();
    }
    if (_afterEverySetup != null) await _afterEverySetup();
  }

  Future<void> tearDownEnvironment({bool force = false}) async {
    if (_needsSetup) {
      // _needsSetup=true means we've never run setup code or already cleaned up
      return;
    }

    if (_beforeEveryTearDown != null) await _beforeEveryTearDown();

    if (!force && reuseTestEnvironment) {
      // Skip actually tearing down for better test performance.
      return;
    }

    if (_beforeFinalTearDown != null) await _beforeFinalTearDown();

    serviceManager.manuallyDisconnect();

    await _service.allFuturesCompleted.timeout(const Duration(seconds: 20),
        onTimeout: () {
      throw 'Timed out waiting for futures to complete during teardown. '
          '${_service.activeFutures.length} futures remained:\n\n'
          '  ${_service.activeFutures.map((tf) => tf.name).join('\n  ')}';
    });
    await _flutter.stop();

    // Delete the temporary flutter directory used for this test environment, if
    // on exists.
    tmpFlutterDirectory?.deleteSync(recursive: true);

    _flutter = null;

    _needsSetup = true;
  }

  bool _isNewRunConfig(FlutterRunConfiguration config) {
    return config != null && config != _runConfig;
  }
}
