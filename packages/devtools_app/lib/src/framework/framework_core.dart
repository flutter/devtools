// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_shared/service.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';

import '../../devtools.dart' as devtools show version;
import '../extensions/extension_service.dart';
import '../screens/debugger/breakpoint_manager.dart';
import '../service/service_manager.dart';
import '../service/vm_service_wrapper.dart';
import '../shared/banner_messages.dart';
import '../shared/console/eval/eval_service.dart';
import '../shared/framework_controller.dart';
import '../shared/globals.dart';
import '../shared/notifications.dart';
import '../shared/offline_mode.dart';
import '../shared/primitives/message_bus.dart';
import '../shared/primitives/utils.dart';
import '../shared/scripts/script_manager.dart';
import '../shared/survey.dart';

typedef ErrorReporter = void Function(String title, Object error);

final _log = Logger('framework_core');

// TODO(jacobr): refactor this class to not use static members.
// ignore: avoid_classes_with_only_static_members
class FrameworkCore {
  static void initGlobals() {
    setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    setGlobal(MessageBus, MessageBus());
    setGlobal(FrameworkController, FrameworkController());
    setGlobal(SurveyService, SurveyService());
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(ScriptManager, ScriptManager());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BannerMessagesController, BannerMessagesController());
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(EvalService, EvalService());
    setGlobal(ExtensionService, ExtensionService());
  }

  static void init() {
    // Print the version number at startup.
    _log.info('DevTools version ${devtools.version}.');
  }

  static bool vmServiceConnectionInProgress = false;

  /// Returns true if we're able to connect to a device and false otherwise.
  static Future<bool> initVmService(
    String url, {
    required String serviceUriAsString,
    ErrorReporter? errorReporter = _defaultErrorReporter,
    bool logException = true,
  }) async {
    if (serviceConnection.serviceManager.hasConnection) {
      // TODO(https://github.com/flutter/devtools/issues/1568): why do we call
      // this multiple times?
      return true;
    }

    final normalizedUri = normalizeVmServiceUri(serviceUriAsString);
    final Uri? uri = normalizedUri ?? getServiceUriFromQueryString(url);
    if (uri != null) {
      vmServiceConnectionInProgress = true;
      final finishedCompleter = Completer<void>();

      try {
        final VmServiceWrapper service = await connect<VmServiceWrapper>(
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
        breakpointManager.initialize();
        return true;
      } catch (e, st) {
        if (logException) {
          _log.shout(e, e, st);
        }
        errorReporter!('Unable to connect to VM service at $uri: $e', e);
        return false;
      } finally {
        vmServiceConnectionInProgress = false;
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
