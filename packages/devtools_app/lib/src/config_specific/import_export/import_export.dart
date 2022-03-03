// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../devtools.dart';
import '../../primitives/utils.dart';
import '../../screens/performance/performance_model.dart';
import '../../screens/performance/performance_screen.dart';
import '../../shared/connected_app.dart';
import '../../shared/globals.dart';
import '../../shared/notifications.dart';
import '_export_stub.dart'
    if (dart.library.html) '_export_web.dart'
    if (dart.library.io) '_export_desktop.dart';

const devToolsSnapshotKey = 'devToolsSnapshot';
const activeScreenIdKey = 'activeScreenId';
const devToolsVersionKey = 'devtoolsVersion';
const connectedAppKey = 'connectedApp';
const isFlutterAppKey = 'isFlutterApp';
const isProfileBuildKey = 'isProfileBuild';
const isDartWebAppKey = 'isDartWebApp';
const isRunningOnDartVMKey = 'isRunningOnDartVM';
const flutterVersionKey = 'flutterVersion';
const nonDevToolsFileMessage = 'The imported file is not a Dart DevTools file.'
    ' At this time, DevTools only supports importing files that were originally'
    ' exported from DevTools.';

String attemptingToImportMessage(String devToolsScreen) {
  return 'Attempting to import file for screen with id "$devToolsScreen".';
}

String successfulExportMessage(String exportedFile) {
  return 'Successfully exported $exportedFile to ~/Downloads directory';
}

// TODO(kenz): we should support a file picker import for desktop.
class ImportController {
  ImportController(
    this._notifications,
    this._pushSnapshotScreenForImport,
  );

  static const repeatImportTimeBufferMs = 500;

  final void Function(String screenId) _pushSnapshotScreenForImport;

  final NotificationService? _notifications;

  DateTime? previousImportTime;

  // TODO(kenz): improve error handling here or in snapshot_screen.dart.
  void importData(DevToolsJsonFile jsonFile) {
    final json = jsonFile.data;

    // Do not allow two different imports within 500 ms of each other. This is a
    // workaround for the fact that we get two drop events for the same file.
    final now = DateTime.now();
    if (previousImportTime != null &&
        (now.millisecondsSinceEpoch -
                    previousImportTime!.millisecondsSinceEpoch)
                .abs() <
            repeatImportTimeBufferMs) {
      return;
    }
    previousImportTime = now;

    final isDevToolsSnapshot =
        json is Map<String, dynamic> && json[devToolsSnapshotKey] == true;
    if (!isDevToolsSnapshot) {
      _notifications!.push(nonDevToolsFileMessage);
      return;
    }

    final devToolsSnapshot = json as Map<String, dynamic>;
    // TODO(kenz): support imports for more than one screen at a time.
    final activeScreenId = devToolsSnapshot[activeScreenIdKey];
    offlineController
      ..enterOfflineMode()
      ..offlineDataJson = devToolsSnapshot;
    serviceManager.connectedApp =
        OfflineConnectedApp.parse(devToolsSnapshot[connectedAppKey]);
    _notifications!.push(attemptingToImportMessage(activeScreenId));
    _pushSnapshotScreenForImport(activeScreenId);
  }
}

abstract class ExportController {
  factory ExportController() {
    return createExportController();
  }

  const ExportController.impl();

  String generateFileName() {
    final now = DateTime.now();
    final timestamp =
        '${now.year}_${now.month}_${now.day}-${now.microsecondsSinceEpoch}';
    return 'dart_devtools_$timestamp.json';
  }

  /// Downloads a JSON file with [contents] and returns the name of the
  /// downloaded file.
  String downloadFile(String contents);

  String encode(String activeScreenId, Map<String, dynamic> contents) {
    final _contents = {
      devToolsSnapshotKey: true,
      activeScreenIdKey: activeScreenId,
      devToolsVersionKey: version,
      connectedAppKey: {
        isFlutterAppKey: serviceManager.connectedApp!.isFlutterAppNow,
        isProfileBuildKey: serviceManager.connectedApp!.isProfileBuildNow,
        isDartWebAppKey: serviceManager.connectedApp!.isDartWebAppNow,
        isRunningOnDartVMKey: serviceManager.connectedApp!.isRunningOnDartVM,
      },
      if (serviceManager.connectedApp!.flutterVersionNow != null)
        flutterVersionKey:
            serviceManager.connectedApp!.flutterVersionNow!.version,
    };
    // This is a workaround to guarantee that DevTools exports are compatible
    // with other trace viewers (catapult, perfetto, chrome://tracing), which
    // require a top level field named "traceEvents".
    if (activeScreenId == PerformanceScreen.id) {
      final traceEvents = List<Map<String, dynamic>>.from(
          contents[PerformanceData.traceEventsKey]);
      _contents[PerformanceData.traceEventsKey] = traceEvents;
      contents.remove(PerformanceData.traceEventsKey);
    }
    return jsonEncode(_contents..addAll({activeScreenId: contents}));
  }
}

class OfflineModeController {
  ValueListenable<bool> get offlineMode => _offlineMode;

  final _offlineMode = ValueNotifier(false);

  Map<String, dynamic> offlineDataJson = {};

  /// Stores the [ConnectedApp] instance temporarily while switching between
  /// offline and online modes.
  ConnectedApp? _previousConnectedApp;

  bool shouldLoadOfflineData(String screenId) {
    return _offlineMode.value &&
        offlineDataJson.isNotEmpty &&
        offlineDataJson[screenId] != null;
  }

  void enterOfflineMode() {
    _previousConnectedApp = serviceManager.connectedApp;
    _offlineMode.value = true;
  }

  void exitOfflineMode() {
    serviceManager.connectedApp = _previousConnectedApp;
    _offlineMode.value = false;
  }
}
