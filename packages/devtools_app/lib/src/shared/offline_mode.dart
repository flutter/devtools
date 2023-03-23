// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'config_specific/import_export/import_export.dart';
import 'connected_app.dart';
import 'globals.dart';
import 'primitives/auto_dispose.dart';

class OfflineModeController {
  bool get isOffline => _offlineMode.value;

  ValueListenable<bool> get offlineMode => _offlineMode;

  final _offlineMode = ValueNotifier<bool>(false);

  var offlineDataJson = <String, dynamic>{};

  /// Stores the [ConnectedApp] instance temporarily while switching between
  /// offline and online modes.
  ConnectedApp? previousConnectedApp;

  bool shouldLoadOfflineData(String screenId) {
    return _offlineMode.value &&
        offlineDataJson.isNotEmpty &&
        offlineDataJson[screenId] != null;
  }

  void enterOfflineMode() {
    previousConnectedApp = serviceManager.connectedApp;
    _offlineMode.value = true;
  }

  void exitOfflineMode() {
    serviceManager.connectedApp = previousConnectedApp;
    _offlineMode.value = false;
    offlineDataJson.clear();
    previousConnectedApp = null;
  }
}

mixin OfflineScreenControllerMixin<T> on AutoDisposeControllerMixin {
  final _exportController = ExportController();

  ValueListenable<bool> get loadingOfflineData => _loadingOfflineData;
  final _loadingOfflineData = ValueNotifier<bool>(false);

  /// Returns an [OfflineScreenData] object with the data that should be
  /// included in the offline data snapshot for this screen.
  OfflineScreenData screenDataForExport();

  /// Defines how the offline data for this screen should be processed and set.
  ///
  /// Each screen controller that mixes in [OfflineScreenControllerMixin] is
  /// responsible for setting up the data models and feeding the data to the
  /// screen for offline viewing - that should occur in this method.
  FutureOr<void> processOfflineData(T offlineData);

  Future<void> loadOfflineData(T offlineData) async {
    _loadingOfflineData.value = true;
    await processOfflineData(offlineData);
    _loadingOfflineData.value = false;
  }

  /// Exports the current screen data to a .json file.
  void exportData() {
    final encodedData = _exportController.encode(screenDataForExport().json);
    _exportController.downloadFile(encodedData);
  }
}

class OfflineScreenData {
  OfflineScreenData({required this.screenId, required this.data});

  final String screenId;

  final Map<String, Object?> data;

  Map<String, Object?> get json => {
        DevToolsExportKeys.activeScreenId.name: screenId,
        ...data,
      };
}
