// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';

import '../../devtools.dart' as devtools show version;
import '../config_specific/logger/logger.dart';
import '../core/message_bus.dart';
import '../framework_controller.dart';
import '../globals.dart';
import '../service.dart';
import '../service_manager.dart';
import '../survey.dart';
import '../vm_service_wrapper.dart';

typedef ErrorReporter = void Function(String title, dynamic error);

class FrameworkCore {
  static void initGlobals() {
    setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    setGlobal(MessageBus, MessageBus());
    setGlobal(FrameworkController, FrameworkController());
    setGlobal(SurveyService, SurveyService());
  }

  static void init({String url}) {
    // Print the version number at startup.
    log('DevTools version ${devtools.version}.');
  }

  /// Returns true if we're able to connect to a device and false otherwise.
  static Future<bool> initVmService(
    String url, {
    Uri explicitUri,
    @required ErrorReporter errorReporter,
  }) async {
    if (serviceManager.hasConnection) {
      // TODO(https://github.com/flutter/devtools/issues/1568): why do we call
      // this multiple times?
      return true;
    }

    final Uri uri = explicitUri ?? _getUriFromQuerystring(url);
    if (uri != null) {
      final finishedCompleter = Completer<void>();

      try {
        final VmServiceWrapper service = await connect(uri, finishedCompleter);
        if (serviceManager != null) {
          await serviceManager.vmServiceOpened(
            service,
            onClosed: finishedCompleter.future,
          );
          return true;
        } else {
          errorReporter('Unable to connect to VM service at $uri', null);
          return false;
        }
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

  /// Gets a VM Service URI from the querystring (in preference from the 'uri'
  /// value, but otherwise from 'port').
  static Uri _getUriFromQuerystring(String location) {
    if (location == null) {
      return null;
    }

    final queryParams = Uri.parse(location).queryParameters;

    // First try to use uri.
    if (queryParams['uri'] != null) {
      final uri = Uri.tryParse(queryParams['uri']);

      // Lots of things are considered valid URIs (including empty strings
      // and single letters) since they can be relative, so we need to do some
      // extra checks.
      if (uri != null &&
          uri.isAbsolute &&
          (uri.isScheme('ws') ||
              uri.isScheme('wss') ||
              uri.isScheme('http') ||
              uri.isScheme('https') ||
              uri.isScheme('sse') ||
              uri.isScheme('sses'))) {
        return uri;
      }
    }

    // Otherwise try the legacy port option. Here we assume ws:/localhost and
    // do not support tokens.
    final port = int.tryParse(queryParams['port'] ?? '');
    if (port != null) {
      return Uri.parse('ws://localhost:$port/ws');
    }

    return null;
  }
}
