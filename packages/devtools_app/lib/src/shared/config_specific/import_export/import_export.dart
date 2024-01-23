// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app_shared/service.dart';
import 'package:intl/intl.dart';

import '../../../../devtools.dart';
import '../../globals.dart';
import '../../primitives/simple_items.dart';
import '../../primitives/utils.dart';
import '../../screen.dart';
import '_export_desktop.dart' if (dart.library.js_interop) '_export_web.dart';

const nonDevToolsFileMessage = 'The imported file is not a Dart DevTools file.'
    ' At this time, DevTools only supports importing files that were originally'
    ' exported from DevTools.';

String attemptingToImportMessage(String devToolsScreen) {
  return 'Attempting to import file for screen with id "$devToolsScreen".';
}

String successfulExportMessage(String exportedFile) {
  return 'Successfully exported $exportedFile to ~/Downloads directory';
}

enum DevToolsExportKeys {
  devToolsSnapshot,
  devToolsVersion,
  connectedApp,
  activeScreenId,
}

class ImportController {
  ImportController(
    this._pushSnapshotScreenForImport,
  );

  static const repeatImportTimeBufferMs = 500;

  final void Function(String screenId) _pushSnapshotScreenForImport;

  DateTime? previousImportTime;

  // TODO(kenz): improve error handling here or in snapshot_screen.dart.
  void importData(DevToolsJsonFile jsonFile, {String? expectedScreenId}) {
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

    final json = jsonFile.data;
    final isDevToolsSnapshot = json is Map<String, dynamic> &&
        json[DevToolsExportKeys.devToolsSnapshot.name] == true;
    if (!isDevToolsSnapshot) {
      notificationService.push(nonDevToolsFileMessage);
      return;
    }

    final devToolsSnapshot = json;
    // TODO(kenz): support imports for more than one screen at a time.
    final activeScreenId =
        devToolsSnapshot[DevToolsExportKeys.activeScreenId.name];
    if (expectedScreenId != null && activeScreenId != expectedScreenId) {
      notificationService.push(
        'Expected a data file for screen \'$expectedScreenId\' but received one'
        ' for screen \'$activeScreenId\'. Please open a file for screen \'$expectedScreenId\'.',
      );
      return;
    }

    final connectedApp =
        (devToolsSnapshot[DevToolsExportKeys.connectedApp.name] ??
                <String, Object>{})
            .cast<String, Object>();
    offlineController
      ..enterOfflineMode(offlineApp: OfflineConnectedApp.parse(connectedApp))
      ..offlineDataJson = devToolsSnapshot;
    notificationService.push(attemptingToImportMessage(activeScreenId));
    _pushSnapshotScreenForImport(activeScreenId);
  }
}

enum ExportFileType {
  json,
  csv,
  yaml;

  @override
  String toString() => name;
}

abstract class ExportController {
  factory ExportController() {
    return createExportController();
  }

  const ExportController.impl();

  static String generateFileName({
    String prefix = 'dart_devtools',
    String postfix = '',
    required ExportFileType type,
    DateTime? time,
  }) {
    time ??= DateTime.now();
    final timestamp = DateFormat('yyyy-MM-dd_HH:mm:ss.SSS').format(time);
    return '${prefix}_$timestamp$postfix.$type';
  }

  /// Downloads a file with [contents]
  /// and pushes notification about success if [notify] is true.
  String downloadFile(
    String content, {
    String? fileName,
    ExportFileType type = ExportFileType.json,
    bool notify = true,
  }) {
    fileName ??= ExportController.generateFileName(type: type);
    saveFile(
      content: content,
      fileName: fileName,
    );
    notificationService.push(successfulExportMessage(fileName));
    return fileName;
  }

  /// Saves [content] to the [fileName].
  void saveFile({
    required String content,
    required String fileName,
  });

  Map<String, dynamic> generateDataForExport({
    required Map<String, dynamic> offlineScreenData,
    ConnectedApp? connectedApp,
  }) {
    final contents = {
      DevToolsExportKeys.devToolsSnapshot.name: true,
      DevToolsExportKeys.devToolsVersion.name: version,
      DevToolsExportKeys.connectedApp.name: connectedApp?.toJson() ??
          serviceConnection.serviceManager.connectedApp!.toJson(),
      ...offlineScreenData,
    };
    final activeScreenId = contents[DevToolsExportKeys.activeScreenId.name];

    // This is a workaround to guarantee that DevTools exports are compatible
    // with other trace viewers (catapult, perfetto, chrome://tracing), which
    // require a top level field named "traceEvents".
    if (activeScreenId == ScreenMetaData.performance.id) {
      final activeScreen =
          (contents[activeScreenId] as Map).cast<String, Object?>();
      final traceEvents =
          List.of((activeScreen[traceEventsFieldName] as List).cast<Object?>());
      contents[traceEventsFieldName] = traceEvents;
      activeScreen.remove(traceEventsFieldName);
    }
    return contents;
  }

  String encode(Map<String, dynamic> offlineScreenData) {
    final data = generateDataForExport(offlineScreenData: offlineScreenData);
    return jsonEncode(data);
  }
}
