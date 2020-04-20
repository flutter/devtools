// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import '../../../../devtools.dart';
import '../../../flutter/notifications.dart';
import '../../../globals.dart';
import '../../../timeline/flutter/timeline_model.dart';
import '../../../timeline/flutter/timeline_screen.dart';
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

// TODO(kenz): we should support a file picker import for desktop.
class ImportController {
  ImportController(
    this._notifications,
    this._pushSnapshotScreenForImport,
  );

  final void Function(String screenId) _pushSnapshotScreenForImport;

  final NotificationService _notifications;

  bool importing = false;

  // TODO(kenz): improve error handling here or in snapshot_screen.dart.
  void importData(Map<String, dynamic> json) {
    if (importing) return;
    importing = true;

    final isDevToolsSnapshot = json[devToolsSnapshotKey];
    if (isDevToolsSnapshot == null || !isDevToolsSnapshot) {
      _notifications.push(nonDevToolsFileMessage);
      importing = false;
      return;
    }

    // TODO(kenz): support imports for more than one screen at a time.
    final activeScreenId = json[activeScreenIdKey];
    offlineDataJson = json;
    _notifications.push(attemptingToImportMessage(activeScreenId));
    _pushSnapshotScreenForImport(activeScreenId);

    importing = false;
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
