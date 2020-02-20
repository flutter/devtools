// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../enum_utils.dart';

import '../../../flutter/controllers.dart';
import '../../../flutter/notifications.dart';
import '../../../flutter/screen.dart';
import '../../../timeline/timeline_controller.dart';
import '../../../timeline/timeline_model.dart';

import '_fake_export.dart'
    if (dart.library.html) '_export_web.dart'
    if (dart.library.io) '_export_desktop.dart';

// TODO(kenz): we should support a file picker import for desktop.

class ImportController {
  ImportController(
    this._notifications,
    this._controllers,
    this.pushScreenForImport,
  );

  static final _devToolsScreenTypeUtils =
      EnumUtils<DevToolsScreenType>(DevToolsScreenType.values);

  final void Function(DevToolsScreenType type) pushScreenForImport;

  final NotificationsState _notifications;

  final ProvidedControllers _controllers;

  void importData(Map<String, dynamic> json) {
    final devToolsScreen = json['dartDevToolsScreen'];
    if (devToolsScreen == null) {
      _notifications.push(
        'The imported file is not a Dart DevTools file. At this time, '
        'DevTools only supports importing files that were originally '
        'exported from DevTools.',
      );
      return;
    }

    // TODO(kenz): add UI progress indicator when offline data is loading.
    switch (_devToolsScreenTypeUtils.enumEntry(devToolsScreen)) {
      case DevToolsScreenType.timeline:
        _importTimeline(json);
        break;
      // TODO(jacobr): add the inspector handling case here once the inspector
      // can be exported.
      default:
        _notifications.push(
          'Could not import file. The imported file is from '
          '"$devToolsScreen", which is not supported by this version of '
          'Dart DevTools. You may need to upgrade your version of Dart '
          'DevTools to view this file.',
        );
        return;
    }
  }

  void _importTimeline(Map<String, dynamic> json) async {
    OfflineData offlineData;
    final timelineMode =
        json[TimelineData.timelineModeKey] == TimelineMode.full.toString()
            ? TimelineMode.full
            : TimelineMode.frameBased;
    if (timelineMode == TimelineMode.frameBased) {
      offlineData = OfflineFrameBasedTimelineData.parse(json);
    } else {
      offlineData = OfflineFullTimelineData.parse(json);
    }

    if (offlineData.isEmpty) {
      _notifications.push('Imported file does not contain timeline data.');
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
