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
    int explicitPort,
    ErrorReporter errorReporter,
  }) async {
    int port = explicitPort;

    // Identify the port so that we can connect to the VM service.
    if (port == null) {
      if (window.location.search.isNotEmpty) {
        final Uri uri = Uri.parse(window.location.toString());
        final String portStr = uri.queryParameters['port'];
        if (portStr != null) {
          port = int.tryParse(portStr);
        }
      }
    }

    if (port != null) {
      final Completer<Null> finishedCompleter = Completer<Null>();

      try {
        final VmServiceWrapper service =
            await connect('localhost', port, finishedCompleter);
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
        errorReporter('Unable to connect to app on port $port', e);
        return false;
      }
    } else {
      return false;
    }
  }
}
