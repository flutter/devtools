// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import 'config_specific/import_export/import_export.dart';
import 'globals.dart';
import 'routing.dart';

class OfflineModeController {
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

  void enterOfflineMode({required ConnectedApp offlineApp}) {
    previousConnectedApp = serviceConnection.serviceManager.connectedApp;
    serviceConnection.serviceManager.connectedApp = offlineApp;
    _offlineMode.value = true;
  }

  void exitOfflineMode() {
    serviceConnection.serviceManager.connectedApp = previousConnectedApp;
    _offlineMode.value = false;
    offlineDataJson.clear();
    previousConnectedApp = null;
  }
}

/// This mixin adds offline functionality to a screen.
///
/// For offline mode, the screen controller should add this mixin,
/// implement its abstract methods.
///
/// To detect if the app is in offline mode, check `offlineController.offlineMode.value`.
///
/// To detect if offline data are available check the value of the
/// global `offlineController.shouldLoadOfflineData(...)`
/// in the controller constructor.
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

  /// Adds a listener that will prepare the screen's current data for offline
  /// viewing after an app disconnect.
  ///
  /// This is in preparation for the user clicking the 'Review History' button
  /// from the disconnect screen.
  void initReviewHistoryOnDisconnectListener() {
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      final connectionState =
          serviceConnection.serviceManager.connectedState.value;
      if (!connectionState.connected &&
          !connectionState.userInitiatedConnectionState) {
        final currentScreenData = screenDataForExport();
        // Only store data for the current page. We can change this in the
        // future if we support offline imports for more than once screen at a
        // time.
        if (DevToolsRouterDelegate.currentPage == currentScreenData.screenId) {
          final previouslyConnectedApp = offlineController.previousConnectedApp;
          final offlineData = _exportController.generateDataForExport(
            offlineScreenData: currentScreenData.json,
            connectedApp: previouslyConnectedApp,
          );
          offlineController.offlineDataJson = offlineData;
        }
      }
    });
  }
}

class OfflineScreenData {
  OfflineScreenData({required this.screenId, required this.data});

  final String screenId;

  final Map<String, Object?> data;

  Map<String, Object?> get json => {
        DevToolsExportKeys.activeScreenId.name: screenId,
        screenId: data,
      };
}
