// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../flutter/notifications.dart';
import '../../../timeline/flutter/timeline_model.dart';
import '../../../timeline/flutter/timeline_screen.dart';
import '_export_stub.dart'
    if (dart.library.html) '_export_web.dart'
    if (dart.library.io) '_export_desktop.dart';

const nonDevToolsFileMessage = 'The imported file is not a Dart DevTools file.'
    ' At this time, DevTools only supports importing files that were originally'
    ' exported from DevTools.';

String attemptingToImportMessage(String devToolsScreen) {
  return 'Attempting to import file for screen with id "$devToolsScreen".';
}

const emptyTimelineMessage = 'Imported file does not contain timeline data.';

// TODO(kenz): we should support a file picker import for desktop.
class ImportController {
  ImportController(
    this._notifications,
    this._pushSnapshotScreenForImport,
  );

  final void Function(String screenId, Object data)
      _pushSnapshotScreenForImport;

  final NotificationService _notifications;

  bool importing = false;

  void importData(Map<String, dynamic> json) {
    if (importing) return;
    importing = true;

    final devToolsScreen = json['dartDevToolsScreen'];
    if (devToolsScreen == null) {
      _notifications.push(nonDevToolsFileMessage);
      importing = false;
      return;
    }

    switch (devToolsScreen) {
      case TimelineScreen.id:
        _importTimeline(json);
        break;
      // TODO(jacobr): add the inspector handling case here once the inspector
      // can be exported.
      default:
        _notifications.push(attemptingToImportMessage(devToolsScreen));
        _pushSnapshotScreenForImport(devToolsScreen, json);
    }

    importing = false;
  }

  void _importTimeline(Map<String, dynamic> json) async {
    final offlineData = OfflineTimelineData.parse(json);
    if (offlineData.isEmpty) {
      _notifications.push(emptyTimelineMessage);
      return;
    }
    _pushSnapshotScreenForImport(TimelineScreen.id, offlineData);
  }
}

abstract class ExportController {
  factory ExportController() {
    return createExportController();
  }

  const ExportController.impl();

  void downloadFile(String filename, String contents);
}
