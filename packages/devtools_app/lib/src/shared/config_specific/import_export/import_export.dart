// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../devtools.dart';
import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as gac;
import '../../common_widgets.dart';
import '../../file_import.dart';
import '../../globals.dart';
import '../../primitives/simple_items.dart';
import '../../primitives/utils.dart';
import '../../screen.dart';
import '_export_stub.dart'
    if (dart.library.js_interop) '_export_web.dart'
    if (dart.library.io) '_export_desktop.dart';

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

// TODO(kenz): we should support a file picker import for desktop.
class ImportController {
  ImportController(
    this._pushSnapshotScreenForImport,
  );

  static const repeatImportTimeBufferMs = 500;

  final void Function(String screenId) _pushSnapshotScreenForImport;

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
  String toString() {
    switch (this) {
      case json:
        return 'json';
      case csv:
        return 'csv';
      case yaml:
        return 'yaml';
      default:
        throw UnimplementedError('Unable to convert $this to a string');
    }
  }
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
      final traceEvents = List<Map<String, dynamic>>.from(
        contents[activeScreenId][traceEventsFieldName],
      );
      contents[traceEventsFieldName] = traceEvents;
      contents[activeScreenId].remove(traceEventsFieldName);
    }
    return contents;
  }

  String encode(Map<String, dynamic> offlineScreenData) {
    final data = generateDataForExport(offlineScreenData: offlineScreenData);
    return jsonEncode(data);
  }
}

class ImportToolbarAction extends ScaffoldAction {
  ImportToolbarAction({super.key, Color? color})
      : super(
          icon: Icons.upload_rounded,
          tooltip: 'Load data for viewing in DevTools.',
          color: color,
          onPressed: (context) => unawaited(_importFile(context)),
        );

  static Future<void> _importFile(BuildContext context) async {
    ga.select(
      gac.devToolsMain,
      gac.importFile,
    );
    final DevToolsJsonFile? importedFile = await importFileFromPicker(
      acceptedTypes: ['json'],
    );

    if (importedFile != null) {
      // ignore: use_build_context_synchronously, by design
      Provider.of<ImportController>(context, listen: false)
          .importData(importedFile);
    }
  }
}
