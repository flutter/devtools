// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../flutter/controllers.dart';
import '../../../flutter/notifications.dart';
import '../../../timeline/timeline_controller.dart';

abstract class ImportControllerBase<T> {
  ImportControllerBase(this.notifications, this.controllers);

  final NotificationsState notifications;

  final ProvidedControllers controllers;

  void handleDragAndDrop(T event);

  void importData(String devToolsScreen) {
    if (devToolsScreen == null) {
      notifications.push(
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
        notifications.push(
          'Could not import file. The imported file is from '
          '"$devToolsScreen", which is not supported by this version of '
          'Dart DevTools. You may need to upgrade your version of Dart '
          'DevTools to view this file.',
        );
        return;
    }
  }
}

abstract class ExportControllerBase {
  void downloadFile(String filename, String contents);
}
