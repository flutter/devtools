// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Screen;

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
  }

  static void initVmService(
      void errorReporter(String title, dynamic error)) async {
    // Identify port so that we can connect the VmService.
    int port;
    if (window.location.search.isNotEmpty) {
      final Uri uri = Uri.parse(window.location.toString());
      final String portStr = uri.queryParameters['port'];
      if (portStr != null) {
        port = int.tryParse(portStr);
      }
    }
    port ??= 8100;

    final Completer<Null> finishedCompleter = Completer<Null>();

    try {
      final VmServiceWrapper service =
          await connect('localhost', port, finishedCompleter);
      if (serviceManager != null) {
        await serviceManager.vmServiceOpened(service, finishedCompleter.future);
      }
    } catch (e) {
      errorReporter('Unable to connect to service on port $port', e);
    }
  }
}
