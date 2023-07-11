// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:logging/logging.dart';

import '../../devtools.dart' as devtools show version;
import '../screens/debugger/breakpoint_manager.dart';
import '../service/service.dart';
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
  }

  static void init() {
    // Print the version number at startup.
    _log.info('DevTools version ${devtools.version}.');
  }

  /// Returns true if we're able to connect to a device and false otherwise.
  static Future<bool> initVmService(
    String url, {
    Uri? explicitUri,
    required ErrorReporter errorReporter,
    bool logException = true,
  }) async {
    if (serviceManager.hasConnection) {
      // TODO(https://github.com/flutter/devtools/issues/1568): why do we call
      // this multiple times?
      return true;
    }

    final Uri? uri = explicitUri ?? getServiceUriFromQueryString(url);
    if (uri != null) {
      final finishedCompleter = Completer<void>();

      try {
        final VmServiceWrapper service = await connect(uri, finishedCompleter);

        await serviceManager.vmServiceOpened(
          service,
          onClosed: finishedCompleter.future,
        );
        breakpointManager.initialize();
        return true;
      } catch (e, st) {
        if (logException) {
          _log.shout(e, e, st);
        }
        errorReporter('Unable to connect to VM service at $uri: $e', e);
        return false;
      }
    } else {
      // Don't report an error here because we do not have a URI to connect to.
      return false;
    }
  }
}
