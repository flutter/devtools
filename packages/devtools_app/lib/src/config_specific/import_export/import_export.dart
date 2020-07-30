// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import '../../../devtools.dart';
import '../../globals.dart';
import '../../notifications.dart';
import '../../timeline/timeline_model.dart';
import '../../timeline/timeline_screen.dart';
import '../../utils.dart';
import '_export_stub.dart'
    if (dart.library.html) '_export_web.dart'
    if (dart.library.io) '_export_desktop.dart';

const devToolsSnapshotKey = 'devToolsSnapshot';
const activeScreenIdKey = 'activeScreenId';
const devToolsVersionKey = 'devtoolsVersion';
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

  final NotificationService _notifications;

  DateTime previousImportTime;

  // TODO(kenz): improve error handling here or in snapshot_screen.dart.
  void importData(DevToolsJsonFile jsonFile) {
    final json = jsonFile.data;

    // Do not allow two different imports within 500 ms of each other. This is a
    // workaround for the fact that we get two drop events for the same file.
    final now = DateTime.now();
    if (previousImportTime != null &&
        (now.millisecondsSinceEpoch - previousImportTime.millisecondsSinceEpoch)
                .abs() <
            repeatImportTimeBufferMs) {
      return;
    }
    previousImportTime = now;

    final isDevToolsSnapshot =
        json is Map<String, dynamic> && json[devToolsSnapshotKey] == true;
    if (!isDevToolsSnapshot) {
      _notifications.push(nonDevToolsFileMessage);
      return;
    }

    final devToolsSnapshot = json as Map<String, dynamic>;
    // TODO(kenz): support imports for more than one screen at a time.
    final activeScreenId = devToolsSnapshot[activeScreenIdKey];
    offlineDataJson = devToolsSnapshot;
    _notifications.push(attemptingToImportMessage(activeScreenId));
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
    };
    // This is a workaround to guarantee that DevTools exports are compatible
    // with other trace viewers (catapult, perfetto, chrome://tracing), which
    // require a top level field named "traceEvents".
    if (activeScreenId == TimelineScreen.id) {
      final traceEvents = List<Map<String, dynamic>>.from(
          contents[TimelineData.traceEventsKey]);
      _contents[TimelineData.traceEventsKey] = traceEvents;
      contents.remove(TimelineData.traceEventsKey);
    }
    return jsonEncode(_contents..addAll({activeScreenId: contents}));
  }
}
