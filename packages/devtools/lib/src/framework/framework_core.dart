// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Screen;

import '../../devtools.dart' as devtools show version;
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
    print('DevTools version ${devtools.version}.');

    final Uri uri = Uri.parse(window.location.toString());
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
    var uri = explicitUri ?? _getUriFromQuerystring();

    if (uri != null) {
      final Completer<Null> finishedCompleter = Completer<Null>();

      // Map the URI (which may be Observatory web app) to a WebSocket URI for
      // the VM service.
      uri = _convertToWsUri(uri);

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

  /// Map the URI (which may already be Observatory web app) to a WebSocket URI
  /// for the VM service. If the URI is already a VM Service WebSocket URI it
  /// will not be modified.
  static Uri _convertToWsUri(Uri uri) {
    final isSecure = uri.isScheme('wss') || uri.isScheme('https');
    final scheme = isSecure ? 'wss' : 'ws';

    final path = uri.path.endsWith('/ws')
        ? uri.path
        : (uri.path.endsWith('/') ? '${uri.path}ws' : '${uri.path}/ws');

    return uri.replace(scheme: scheme, path: path);
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
              uri.isScheme('https'))) {
        return uri;
      }
    }

    // Otherwise try the legacy port oprtion. Here we assume ws:/localhost and
    // do not support tokens.
    final port = int.tryParse(queryParams['port'] ?? '');
    if (port != null) {
      return Uri.parse('ws://localhost:$port/ws');
    }

    return null;
  }
}
