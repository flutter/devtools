// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../../devtools.dart' as devtools show version;
import '../config_specific/import_export/import_export.dart';
import '../config_specific/logger/logger.dart';
import '../primitives/message_bus.dart';
import '../primitives/utils.dart';
import '../scripts/script_manager.dart';
import '../service/service.dart';
import '../service/service_manager.dart';
import '../service/vm_service_wrapper.dart';
import '../shared/framework_controller.dart';
import '../shared/globals.dart';
import '../shared/survey.dart';

typedef ErrorReporter = void Function(String title, dynamic error);

// ignore: avoid_classes_with_only_static_members
class FrameworkCore {
  static void initGlobals() {
    setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    setGlobal(MessageBus, MessageBus());
    setGlobal(FrameworkController, FrameworkController());
    setGlobal(SurveyService, SurveyService());
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(ScriptManager, ScriptManager());
  }

  static void init() {
    // Print the version number at startup.
    log('DevTools version ${devtools.version}.');
  }

  /// Returns true if we're able to connect to a device and false otherwise.
  static Future<bool> initVmService(
    String url, {
    Uri? explicitUri,
    required ErrorReporter errorReporter,
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
        return true;
      } catch (e, st) {
        log('$e\n$st', LogLevel.error);

        errorReporter('Unable to connect to VM service at $uri: $e', e);
        return false;
      }
    } else {
      // Don't report an error here because we do not have a URI to connect to.
      return false;
    }
  }
}
