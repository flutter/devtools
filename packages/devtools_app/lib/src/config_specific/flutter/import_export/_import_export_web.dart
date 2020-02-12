// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:html';

import '../../../flutter/controllers.dart';
import '../../../flutter/notifications.dart';
import '_import_export_base.dart';

class ImportController extends ImportControllerBase<MouseEvent> {
  ImportController(
    NotificationsState notifications,
    ProvidedControllers controllers,
  ) : super(notifications, controllers);

  @override
  void handleDragAndDrop(MouseEvent event) {
    final List<File> files = event.dataTransfer.files;
    if (files.length > 1) {
      notifications.push('You cannot import more than one file.');
      return;
    }

    final droppedFile = files.first;
    if (droppedFile.type != 'application/json') {
      notifications.push(
          '${droppedFile.type} is not a supported file type. Please import '
          'a .json file that was exported from Dart DevTools.');
      return;
    }

    final FileReader reader = FileReader();
    reader.onLoad.listen((_) {
      try {
        final Map<String, dynamic> import = jsonDecode(reader.result);
        final devToolsScreen = import['dartDevToolsScreen'];
        importData(devToolsScreen);
      } on FormatException catch (e) {
        notifications.push(
          'JSON syntax error in imported file: "$e". Please make sure the '
          'imported file is a Dart DevTools file, and check that it has not '
          'been modified.',
        );
        return;
      }
    });

    try {
      reader.readAsText(droppedFile);
    } catch (e) {
      notifications.push('Could not import file: $e');
    }
  }
}

class ExportController extends ExportControllerBase {
  @override
  void downloadFile(String filename, String contents) {
    final element = document.createElement('a');
    element.setAttribute('href', Url.createObjectUrl(Blob([contents])));
    element.setAttribute('download', filename);
    element.style.display = 'none';
    document.body.append(element);
    element.click();
    element.remove();
  }
}
