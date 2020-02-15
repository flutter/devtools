// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../flutter/controllers.dart';
import '../../../flutter/notifications.dart';
import '../../../timeline/timeline_controller.dart';

import '_fake_export.dart'
    if (dart.library.html) '_export_web.dart'
    if (dart.library.io) '_export_desktop.dart';

// TODO(kenz): we should support a file picker import for desktop.

class ImportController {
  const ImportController(this._notifications, this._controllers);

  final NotificationsState _notifications;

  final ProvidedControllers _controllers;

  void dispose() {
    // TODO(Kenzie): Disabled see issue https://github.com/flutter/devtools/issues/1637.
//    notifications?.dispose();
    _controllers?.dispose();
  }

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

    // TODO(jacobr): add the inspector handling case here once the inspector
    // can be exported.
    switch (devToolsScreen) {
      case timelineScreenId:
        // TODO(kenz): actually import and load timeline data.
//        final timelineController =
//            controllers?.timeline ?? TimelineController();
        break;
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
}

abstract class ExportController {
  factory ExportController() {
    return createExportController();
  }

  const ExportController.impl();

  void downloadFile(String filename, String contents);
}
