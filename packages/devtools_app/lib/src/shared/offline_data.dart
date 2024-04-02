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

/// Controller that manages offline mode for DevTools.
///
/// This class will be instantiated once and set as a global [offlineDataController]
/// that can be accessed from anywhere in DevTools.
class OfflineDataController {
  /// Whether DevTools is in offline mode.
  ///
  /// We consider DevTools to show offline data whenever there is data
  /// that was previously saved from DevTools.
  ///
  /// The value of [showingOfflineData] is independent of the DevTools connection
  /// status. DevTools can be in offline mode both when connected to an app when
  /// disconnected from an app.
  ValueListenable<bool> get showingOfflineData => _showingOfflineData;
  final _showingOfflineData = ValueNotifier<bool>(false);

  /// The current offline data as raw JSON.
  ///
  /// This value is set from [ImportController.importData] when offline data is
  /// imported to DevTools.
  var offlineDataJson = <String, dynamic>{};

  /// Stores the [ConnectedApp] instance temporarily while switching between
  /// offline and online modes.
  ///
  /// We store this because the [serviceManager] is a global manager and expects
  /// only one connected app. So we swap out the online connected app with the
  /// offline app data while in offline mode.
  ConnectedApp? previousConnectedApp;

  /// Whether DevTools should load offline data for [screenId].
  bool shouldLoadOfflineData(String screenId) {
    return _showingOfflineData.value &&
        offlineDataJson.isNotEmpty &&
        offlineDataJson[screenId] != null;
  }

  void startShowingOfflineData({required ConnectedApp offlineApp}) {
    previousConnectedApp = serviceConnection.serviceManager.connectedApp;
    serviceConnection.serviceManager.connectedApp = offlineApp;
    _showingOfflineData.value = true;
  }

  void stopShowingOfflineData() {
    serviceConnection.serviceManager.connectedApp = previousConnectedApp;
    _showingOfflineData.value = false;
    offlineDataJson.clear();
    previousConnectedApp = null;
  }
}

/// Mixin that provides offline support for a DevTools screen controller.
///
/// The [Screen] that is associated with this controller must have
/// [Screen.worksOffline] set to true in order to enable offline support for the
/// screen.
///
/// Check [OfflineDataController.showingOfflineData] in controller constructor.
/// If it is true, the screen should ignore the connected application and just show
/// the offline data.
///
/// Example:
///
/// class MyScreenController with OfflineScreenControllerMixin<MyScreenData> {
///   MyScreenController() {
///     init();
///   }
///
///   void init() {
///     if (offlineDataController.showingOfflineData.value) {
///       await maybeLoadOfflineData(
///         ScreenMetaData.myScreen.id,
///         createData: (json) => MyScreenData.parse(json),
///         shouldLoad: (data) => data.isNotEmpty,
///       );
///     } else {
///       // Do screen initialization for connected application.
///     }
///   }
///
///   // Override the abstract methods from [OfflineScreenControllerMixin].
///
///   @override
///   OfflineScreenData prepareOfflineScreenData() => OfflineScreenData(
///     screenId: ScreenMetaData.myScreen.id,
///     data: {} // The data for this screen as a serializable JSON object.
///   );
///
///   @override
///   FutureOr<void> processOfflineData(MyScreenData offlineData) async {
///     // Set up the all the data models and notifiers that feed MyScreen's UI.
///   }
/// }
///
/// ...
///
/// Then in the DevTools [ScreenMetaData] enum, set 'worksOffline' to true.
///
/// enum ScreenMetaData {
///   ...
///   myScreen(
///     ...
///     worksOffline: true,
///   ),
/// }
mixin OfflineScreenControllerMixin<T> on AutoDisposeControllerMixin {
  final _exportController = ExportController();

  /// Whether this controller is actively loading offline data.
  ///
  /// It is likely that a screen will want to show a loading indicator in place
  /// of its normal UI while this value is true.
  ValueListenable<bool> get loadingOfflineData => _loadingOfflineData;
  final _loadingOfflineData = ValueNotifier<bool>(false);

  /// Returns an [OfflineScreenData] object with the data that should be
  /// included in the offline data snapshot for this screen.
  OfflineScreenData prepareOfflineScreenData();

  /// Defines how the offline data for this screen should be processed and set.
  ///
  /// Each screen controller that mixes in [OfflineScreenControllerMixin] is
  /// responsible for setting up the data models and feeding the data to the
  /// screen for offline viewing - that should occur in this method.
  FutureOr<void> processOfflineData(T offlineData);

  /// Loads offline data for [screenId] when available, and when the
  /// [shouldLoad] condition is met.
  ///
  /// Screen controllers that mix in [OfflineScreenControllerMixin] should call
  /// this during their initialization when DevTools is in offline mode, defined
  /// by [OfflineDataController.showingOfflineData].
  @protected
  Future<void> maybeLoadOfflineData(
    String screenId, {
    required T Function(Map<String, Object?> json) createData,
    required bool Function(T data) shouldLoad,
  }) async {
    if (offlineDataController.shouldLoadOfflineData(screenId)) {
      final json = Map<String, Object?>.from(
        offlineDataController.offlineDataJson[screenId],
      );
      final screenData = createData(json);
      if (shouldLoad(screenData)) {
        await _loadOfflineData(screenData);
      }
    }
  }

  Future<void> _loadOfflineData(T offlineData) async {
    _loadingOfflineData.value = true;
    await processOfflineData(offlineData);
    _loadingOfflineData.value = false;
  }

  /// Exports the current screen data to a .json file and downloads the file to
  /// the user's Downloads directory.
  void exportData() {
    final encodedData =
        _exportController.encode(prepareOfflineScreenData().json);
    _exportController.downloadFile(encodedData);
  }

  /// Adds a listener that will prepare the screen's current data for offline
  /// viewing after an app disconnect.
  ///
  /// This is in preparation for the user clicking the 'Review History' button
  /// from the disconnect screen.
  ///
  /// For screens that support the disconnect experience, which is a screen that
  /// allows you to view historical data from before the app was disconnected
  /// even after we lose connection to the device, this should be called in the
  /// controller's initialization.
  void initReviewHistoryOnDisconnectListener() {
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      final connectionState =
          serviceConnection.serviceManager.connectedState.value;
      if (!connectionState.connected &&
          !connectionState.userInitiatedConnectionState) {
        final currentScreenData = prepareOfflineScreenData();
        // Only store data for the current page. We can change this in the
        // future if we support offline imports for more than once screen at a
        // time.
        if (DevToolsRouterDelegate.currentPage == currentScreenData.screenId) {
          final previouslyConnectedApp =
              offlineDataController.previousConnectedApp;
          final offlineData = _exportController.generateDataForExport(
            offlineScreenData: currentScreenData.json,
            connectedApp: previouslyConnectedApp,
          );
          offlineDataController.offlineDataJson = offlineData;
        }
      }
    });
  }
}

/// Stores data for a screen that will be used to create a DevTools data export.
class OfflineScreenData {
  OfflineScreenData({required this.screenId, required this.data});

  /// The screen id that this data is associated with.
  final String screenId;

  /// The JSON serializable data for the screen.
  ///
  /// This data will be encoded as JSON and written to a file when data is
  /// exported from DevTools. This means that the values in [data] must be
  /// primitive types that can be encoded as JSON.
  final Map<String, Object?> data;

  Map<String, Object?> get json => {
        DevToolsExportKeys.activeScreenId.name: screenId,
        screenId: data,
      };
}
