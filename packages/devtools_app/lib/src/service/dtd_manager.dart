// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dtd/dtd.dart';
import 'package:flutter/foundation.dart';

import '../framework/app_error_handling.dart';
import '../shared/globals.dart';

/// Manages a connection to the Dart Tooling Daemon.
class DTDManager {
  ValueListenable<DTDConnection?> get connection => _connection;
  final ValueNotifier<DTDConnection?> _connection =
      ValueNotifier<DTDConnection?>(null);

  /// Sets the Dart Tooling Daemon connection to point to [uri].
  ///
  /// Before connecting to [uri], if a current connection exists, then
  /// [disconnect] is called to close it.
  Future<void> connect(Uri uri) async {
    await disconnect();

    try {
      _connection.value = await DartToolingDaemon.connect(uri);
    } catch (e, st) {
      notificationService.pushError(
        'Failed to connect to the Dart Tooling Daemon',
        isReportable: false,
      );
      reportError(
        e,
        errorType: 'Dart Tooling Daemon connection failed.',
        stack: st,
      );
    }
  }

  /// Closes and unsets the Dart Tooling Daemon connection, if one is set.
  Future<void> disconnect() async {
    if (_connection.value != null) {
      await _connection.value!.close();
    }

    _connection.value = null;
  }
}
