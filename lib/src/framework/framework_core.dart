// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Screen;

import '../core/message_bus.dart';
import '../globals.dart';
import '../service.dart';
import '../service_manager.dart';
import '../vm_service_wrapper.dart';

class FrameworkCore {
  static void init() {
    _setServiceConnectionManager();
  }

  static void _setServiceConnectionManager() {
    setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    setGlobal(MessageBus, MessageBus());
  }

  static void initVmService(
    void errorReporter(String title, dynamic error),
  ) async {
    int port;

    // Identify the port so that we can connect to the VM service.
    if (window.location.search.isNotEmpty) {
      final Uri uri = Uri.parse(window.location.toString());
      final String portStr = uri.queryParameters['port'];
      if (portStr != null) {
        port = int.tryParse(portStr);
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
        }
      } catch (e) {
        errorReporter('Unable to connect to app on port $port', e);
      }
    }
  }
}
