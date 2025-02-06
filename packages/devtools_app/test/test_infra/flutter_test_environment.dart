// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:io';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/config_specific/framework_initialize/_framework_initialize_desktop.dart';
import 'package:devtools_app/src/shared/primitives/message_bus.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:path/path.dart' as p;

import 'flutter_test_driver.dart';

typedef FlutterDriverFactory =
    FlutterTestDriver Function(Directory testAppDirectory);

/// The default [FlutterDriverFactory] method. Runs a normal flutter app.
FlutterRunTestDriver defaultFlutterRunDriver(Directory appDir) =>
    FlutterRunTestDriver(appDir);

final defaultFlutterExecutable = Platform.isWindows ? 'flutter.bat' : 'flutter';

class FlutterTestEnvironment {
  FlutterTestEnvironment(
    this._runConfig, {
    String testAppDirectory = 'test/test_infra/fixtures/flutter_app',
    bool useTempDirectory = false,
    FlutterDriverFactory? flutterDriverFactory,
  }) : _testAppDirectory = testAppDirectory,
       _flutterDriverFactory = flutterDriverFactory ?? defaultFlutterRunDriver,
       _flutterExe = _parseFlutterExeFromEnv() {
    if (useTempDirectory) {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'flutter_test_temp',
      );
      _tempTestAppDirectory = tempDirectory.path;
      _copyToTempDirectory(testAppDirectory, tempDirectory);
    }
  }

  static String _parseFlutterExeFromEnv() {
    const flutterExe = String.fromEnvironment('FLUTTER_CMD');
    return flutterExe.isNotEmpty ? flutterExe : defaultFlutterExecutable;
  }

  FlutterRunConfiguration _runConfig;
  FlutterRunTestDriver? _flutter;
  FlutterRunTestDriver? get flutter => _flutter;
  late VmServiceWrapper _service;
  VmServiceWrapper get service => _service;

  /// Path relative to the `devtools_app` dir for the test fixture.
  String get testAppDirectory => _tempTestAppDirectory ?? _testAppDirectory;

  final String _testAppDirectory;

  String? _tempTestAppDirectory;

  /// A factory method which can return a [FlutterRunTestDriver] for a test
  /// fixture directory.
  final FlutterDriverFactory _flutterDriverFactory;

  /// The Flutter executable to use for this test environment.
  ///
  /// This executable can be specified using the --dart-define flag
  /// (e.g. `flutter test --dart-define=FLUTTER_CMD=path/to/flutter/bin/flutter
  /// test/my_test.dart`).
  final String _flutterExe;

  // This function will be called after we have ran the Flutter app and the
  // vmService is opened.
  Future<void> Function()? _afterNewSetup;
  set afterNewSetup(Future<void> Function() f) => _afterNewSetup = f;

  // This function will be called for every call to [setupEnvironment], even
  // when the setup is not forced or triggered by a new FlutterRunConfiguration.
  Future<void> Function()? _afterEverySetup;
  set afterEverySetup(Future<void> Function() f) => _afterEverySetup = f;

  // The function will be called before the each tear down, including those that
  // skip work due to not being forced. This usually means for each individual
  // test, but it will also run as part of a final forced tear down so should
  // be tolerable to being called twice after a single test.
  Future<void> Function()? _beforeEveryTearDown;
  set beforeEveryTearDown(Future<void> Function() f) =>
      _beforeEveryTearDown = f;

  // The function will be called before the final forced teardown at the end
  // of the test suite (which will then stop the Flutter app).
  Future<void> Function()? _beforeFinalTearDown;
  set beforeFinalTearDown(Future<void> Function() f) =>
      _beforeFinalTearDown = f;

  bool _needsSetup = true;

  Completer<bool>? _setupInProgress;

  // Switch this flag to false to debug issues with non-atomic test behavior.
  bool reuseTestEnvironment = true;

  PreferencesController? _preferencesController;

  Future<void> setupEnvironment({
    bool force = false,
    FlutterRunConfiguration? config,
  }) async {
    final setupInProgress = _setupInProgress;
    if (setupInProgress != null && !setupInProgress.isCompleted) {
      await setupInProgress.future;
    }
    // Setting up the environment is slow so we reuse the existing environment
    // when possible.
    if (force ||
        _needsSetup ||
        !reuseTestEnvironment ||
        _isNewRunConfig(config)) {
      _setupInProgress = Completer();
      try {
        // If we already have a running test device, stop it before setting up a
        // new one.
        if (_flutter != null) await tearDownEnvironment(force: true);

        // Update the run configuration if we have a new one.
        if (_isNewRunConfig(config)) _runConfig = config!;

        _flutter =
            _flutterDriverFactory(Directory(testAppDirectory))
                as FlutterRunTestDriver?;
        await _flutter!.run(
          flutterExecutable: _flutterExe,
          runConfig: _runConfig,
        );

        _service = _flutter!.vmService!;

        setGlobal(
          DevToolsEnvironmentParameters,
          ExternalDevToolsEnvironmentParameters(),
        );
        setGlobal(IdeTheme, IdeTheme());
        setGlobal(Storage, FlutterDesktopStorage());
        setGlobal(ServiceConnectionManager, ServiceConnectionManager());
        setGlobal(OfflineDataController, OfflineDataController());
        setGlobal(NotificationService, NotificationService());

        final preferencesController = PreferencesController();
        _preferencesController = preferencesController;
        setGlobal(PreferencesController, preferencesController);
        setGlobal(
          DevToolsEnvironmentParameters,
          ExternalDevToolsEnvironmentParameters(),
        );
        setGlobal(MessageBus, MessageBus());
        setGlobal(ScriptManager, ScriptManager());
        setGlobal(BreakpointManager, BreakpointManager());
        setGlobal(ExtensionService, ExtensionService());
        setGlobal(DTDManager, DTDManager());

        // Clear out VM service calls from the test driver.
        _service.clearVmServiceCalls();

        await serviceConnection.serviceManager.vmServiceOpened(
          _service,
          onClosed: Completer<void>().future,
        );
        await _preferencesController!.init();

        _needsSetup = false;
      } finally {
        _setupInProgress!.complete(!_needsSetup);
      }

      if (_afterNewSetup != null) await _afterNewSetup!();
    }
    if (_afterEverySetup != null) await _afterEverySetup!();
  }

  Future<void> tearDownEnvironment({bool force = false}) async {
    if (_needsSetup) {
      // _needsSetup=true means we've never run setup code or already cleaned up
      return;
    }

    if (_beforeEveryTearDown != null) await _beforeEveryTearDown!();

    if (!force && reuseTestEnvironment) {
      // Skip actually tearing down for better test performance.
      return;
    }

    if (_beforeFinalTearDown != null) await _beforeFinalTearDown!();

    await serviceConnection.serviceManager.manuallyDisconnect();

    await _service.allFuturesCompleted.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        throw 'Timed out waiting for futures to complete during teardown. '
            '${_service.activeFutures.length} futures remained:\n\n'
            '  ${_service.activeFutures.map((tf) => tf.name).join('\n  ')}';
      },
    );
    await _flutter!.stop();
    _preferencesController?.dispose();
    _preferencesController = null;

    _flutter = null;

    _needsSetup = true;
  }

  void finalTeardown() {
    // Delete the temporary directory created for the test suite.
    if (_tempTestAppDirectory != null) {
      final tempDirectory = Directory(_tempTestAppDirectory!);
      if (tempDirectory.existsSync()) {
        Directory(_tempTestAppDirectory!).deleteSync(recursive: true);
      }
    }
  }

  bool _isNewRunConfig(FlutterRunConfiguration? config) {
    return config != null && config != _runConfig;
  }

  void _copyToTempDirectory(String directoryPath, Directory tempDirectory) {
    if (!Directory(directoryPath).existsSync()) return;

    if (!tempDirectory.existsSync()) {
      tempDirectory.createSync(recursive: true);
    }

    for (final entity in Directory(directoryPath).listSync()) {
      final copyTo = p.join(
        tempDirectory.path,
        p.relative(entity.path, from: directoryPath),
      );
      if (entity is File) {
        entity.copySync(copyTo);
      } else if (entity is Directory) {
        _copyToTempDirectory(entity.path, Directory(copyTo));
      }
    }
  }
}
