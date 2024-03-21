// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dtd/dtd.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final _log = Logger('dtd_manager');

/// Manages a connection to the Dart Tooling Daemon.
class DTDManager {
  ValueListenable<DartToolingDaemon?> get connection => _connection;
  final ValueNotifier<DartToolingDaemon?> _connection =
      ValueNotifier<DartToolingDaemon?>(null);

  /// Whether the [DTDManager] is connected to a running instance of the DTD.
  bool get hasConnection => connection.value != null;

  /// The URI of the current DTD connection.
  Uri? get uri => _uri;
  Uri? _uri;

  /// Sets the Dart Tooling Daemon connection to point to [uri].
  ///
  /// Before connecting to [uri], if a current connection exists, then
  /// [disconnect] is called to close it.
  Future<void> connect(
    Uri uri, {
    void Function(Object, StackTrace?)? onError,
  }) async {
    await disconnect();

    try {
      _connection.value = await DartToolingDaemon.connect(uri);
      _uri = uri;
      _log.info('Successfully connected to DTD at: $uri');
    } catch (e, st) {
      onError?.call(e, st);
    }
  }

  /// Closes and unsets the Dart Tooling Daemon connection, if one is set.
  Future<void> disconnect() async {
    if (_connection.value != null) {
      await _connection.value!.close();
    }

    _connection.value = null;
    _uri = null;
  }

  Future<IDEWorkspaceRoots?> workspaceRoots({bool forceRefresh = false}) async {
    if (hasConnection) {
      if (_workspaceRoots != null && forceRefresh) {
        _workspaceRoots = null;
      }
      try {
        return _workspaceRoots ??=
            await _connection.value!.getIDEWorkspaceRoots();
      } catch (e) {
        _log.fine('Error fetching IDE workspaceRoots: $e');
        return null;
      }
    }
    return null;
  }

  IDEWorkspaceRoots? _workspaceRoots;
}
