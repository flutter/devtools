// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_shared/service.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';

import '../extensions/extension_service.dart';
import '../screens/debugger/breakpoint_manager.dart';
import '../service/service_manager.dart';
import '../service/vm_service_wrapper.dart';
import '../shared/banner_messages.dart';
import '../shared/config_specific/framework_initialize/framework_initialize.dart';
import '../shared/console/eval/eval_service.dart';
import '../shared/framework_controller.dart';
import '../shared/globals.dart';
import '../shared/notifications.dart';
import '../shared/offline_data.dart';
import '../shared/preferences/preferences.dart';
import '../shared/primitives/message_bus.dart';
import '../shared/scripts/script_manager.dart';
import '../shared/server/server.dart' as server;
import '../shared/survey.dart';
import '../shared/utils.dart';
import 'app_error_handling.dart';

typedef ErrorReporter = void Function(String title, Object error);

final _log = Logger('framework_core');

// ignore: avoid_classes_with_only_static_members, intentional grouping of static methods.
abstract class FrameworkCore {
  /// Initializes the DevTools framework, which includes setting up global
  /// variables, local storage, preferences, and initializing framework level
  /// managers like the Dart Tooling Daemon manager and the DevTools extensions
  /// service.
  static Future<void> init() async {
    _initGlobals();

    await initializePlatform();

    // Print the version number at startup.
    _log.info('DevTools version $devToolsVersion.');

    await _initDTDConnection();

    final preferences = PreferencesController();
    // Wait for preferences to load before rendering the app to avoid a flash of
    // content with the incorrect theme.
    await preferences.init();

    // This must be called after the DTD connection has been initialized and after
    // preferences have been initialized.
    await extensionService.initialize();
  }

  /// Disposes framework level services and managers.
  ///
  /// Any service or manager that is initialized in [init] should be disposed
  /// here. This method is called from the [DevToolsAppState.dispose] lifecycle
  /// method.
  static void dispose() {
    extensionService.dispose();
    preferences.dispose();
    unawaited(dtdManager.dispose());
  }

  static void _initGlobals() {
    setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    setGlobal(MessageBus, MessageBus());
    setGlobal(FrameworkController, FrameworkController());
    setGlobal(SurveyService, SurveyService());
    setGlobal(OfflineDataController, OfflineDataController());
    setGlobal(ScriptManager, ScriptManager());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BannerMessagesController, BannerMessagesController());
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(EvalService, EvalService());
    setGlobal(ExtensionService, ExtensionService());
    setGlobal(IdeTheme, getIdeTheme());
    setGlobal(DTDManager, DTDManager());
  }

  static bool initializationInProgress = false;

  /// Returns true if we're able to connect to a device and false otherwise.
  static Future<bool> initVmService({
    required String serviceUriAsString,
    ErrorReporter? errorReporter = _defaultErrorReporter,
    bool logException = true,
  }) async {
    if (serviceConnection.serviceManager.hasConnection) {
      // TODO(https://github.com/flutter/devtools/issues/1568): why do we call
      // this multiple times?
      return true;
    }

    final uri = normalizeVmServiceUri(serviceUriAsString);
    if (uri != null) {
      initializationInProgress = true;
      final finishedCompleter = Completer<void>();

      try {
        final service = await connect<VmServiceWrapper>(
          uri: uri,
          finishedCompleter: finishedCompleter,
          serviceFactory: ({
            // ignore: avoid-dynamic, mirrors types of [VmServiceFactory].
            required Stream<dynamic> /*String|List<int>*/ inStream,
            required void Function(String message) writeMessage,
            Log? log,
            DisposeHandler? disposeHandler,
            Future? streamClosed,
            String? wsUri,
            bool trackFutures = false,
          }) =>
              VmServiceWrapper.defaultFactory(
            inStream: inStream,
            writeMessage: writeMessage,
            log: log,
            disposeHandler: disposeHandler,
            streamClosed: streamClosed,
            wsUri: wsUri,
            trackFutures: integrationTestMode,
          ),
        );

        await serviceConnection.serviceManager.vmServiceOpened(
          service,
          onClosed: finishedCompleter.future,
        );
        await breakpointManager.initialize();
        return true;
      } catch (e, st) {
        if (logException) {
          _log.shout(e, e, st);
        }
        errorReporter!('Unable to connect to VM service at $uri: $e', e);
        return false;
      } finally {
        initializationInProgress = false;
      }
    } else {
      // Don't report an error here because we do not have a URI to connect to.
      return false;
    }
  }

  static void _defaultErrorReporter(String title, Object error) {
    notificationService.pushError(
      '$title, $error',
      isReportable: false,
    );
  }
}

Future<void> _initDTDConnection() async {
  try {
    // Get the dtdUri from the devtools server
    final dtdUri = await server.getDtdUri();

    if (dtdUri != null) {
      await dtdManager.connect(
        dtdUri,
        onError: (e, st) {
          notificationService.pushError(
            'Failed to connect to the Dart Tooling Daemon',
            isReportable: false,
          );
          reportError(
            e,
            errorType: 'Dart Tooling Daemon connection failed.',
            stack: st,
          );
        },
      );
    } else {
      _log.info('No DTD uri provided from the server during initialization.');
    }
  } catch (e, st) {
    // Dtd failing to connect does not interfere with devtools starting up so
    // catch any errors and report them.
    reportError(
      e,
      errorType: 'Failed to initialize the DTD connection.',
      stack: st,
    );
  }
}
