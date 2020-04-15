// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../flutter/controllers.dart';
import '../../../flutter/notifications.dart';
import '../../../flutter/screen.dart';
import '../../../timeline/flutter/timeline_model.dart';
import '_export_stub.dart'
    if (dart.library.html) '_export_web.dart'
    if (dart.library.io) '_export_desktop.dart';

const nonDevToolsFileMessage = 'The imported file is not a Dart DevTools file.'
    ' At this time, DevTools only supports importing files that were originally'
    ' exported from DevTools.';

String unsupportedDevToolsFileMessage(String devToolsScreen) {
  return 'Could not import file. The imported file is from "$devToolsScreen", '
      'which is not supported by this version of Dart DevTools. You may need to'
      ' upgrade your version of Dart DevTools to view this file.';
}

const emptyTimelineMessage = 'Imported file does not contain timeline data.';

// TODO(kenz): we should support a file picker import for desktop.
class ImportController {
  ImportController(
    this._notifications,
    this._controllers,
    this.pushScreenForImport,
  );

  final void Function(DevToolsScreenType type) pushScreenForImport;

  final NotificationService _notifications;

  final ProvidedControllers _controllers;

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

    // TODO(kenz): add UI progress indicator when offline data is loading.
    // TODO(kenz): add support for custom / conditional screens.
    switch (devToolsScreen) {
      case DevToolsScreenType.timelineId:
        _importTimeline(json);
        break;
      // TODO(jacobr): add the inspector handling case here once the inspector
      // can be exported.
      default:
        _notifications.push(unsupportedDevToolsFileMessage(devToolsScreen));
        importing = false;
        return;
    }

    importing = false;
  }

  void _importTimeline(Map<String, dynamic> json) async {
    final offlineData = OfflineTimelineData.parse(json);
    if (offlineData.isEmpty) {
      _notifications.push(emptyTimelineMessage);
      return;
    }

    // TODO(kenz): handle imports when we don't have any active controllers
    // (i.e. when the connect screen is showing).
    final timelineController = _controllers?.timeline;
    if (timelineController == null) {
      return;
    }

    pushScreenForImport(DevToolsScreenType.timeline);

    await timelineController.loadOfflineData(offlineData);
  }
}

abstract class ExportController {
  factory ExportController() {
    return createExportController();
  }

  const ExportController.impl();

  void downloadFile(String filename, String contents);
}
