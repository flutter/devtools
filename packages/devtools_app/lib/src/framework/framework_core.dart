// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:html_shim/html.dart' hide Screen;

import '../../devtools.dart' as devtools show version;
import '../config_specific/logger.dart';
import '../core/message_bus.dart';
import '../globals.dart';
import '../service.dart';
import '../service_manager.dart';
import '../ui/theme.dart' as theme;
import '../vm_service_wrapper.dart';

typedef ErrorReporter = void Function(String title, dynamic error);

class FrameworkCore {
  static void init() {
    // Print the version number at startup.
    log('DevTools version ${devtools.version}.');

    final uri = Uri.parse(window.location.toString());
    theme.initializeTheme(uri.queryParameters['theme']);

    _setGlobals();
  }

  static void _setGlobals() {
    setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    setGlobal(MessageBus, MessageBus());
  }

  /// Returns true if we're able to connect to a device and false otherwise.
  static Future<bool> initVmService({
    Uri explicitUri,
    ErrorReporter errorReporter,
  }) async {
    final Uri uri = explicitUri ?? _getUriFromQuerystring();

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
          return false;
        }
      } catch (e) {
        errorReporter('Unable to connect to VM service at $uri', e);
        return false;
      }
    } else {
      return false;
    }
  }

  /// Gets a VM Service URI from the querystring (in preference from the 'uri'
  /// value, but otherwise from 'port').
  static Uri _getUriFromQuerystring() {
    if (window.location.search.isEmpty) {
      return null;
    }

    final queryParams = Uri.parse(window.location.toString()).queryParameters;

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
