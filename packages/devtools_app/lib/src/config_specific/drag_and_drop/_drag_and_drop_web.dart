// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:meta/meta.dart';

import '../../notifications.dart';
import '../../utils.dart';
import 'drag_and_drop.dart';

DragAndDropManagerWeb createDragAndDropManager({
  @required NotificationsState notifications,
}) {
  return DragAndDropManagerWeb(notifications: notifications);
}

class DragAndDropManagerWeb extends DragAndDropManager {
  DragAndDropManagerWeb({
    @required NotificationsState notifications,
  }) : super.impl(notifications: notifications);

  StreamSubscription<MouseEvent> onDragOverSubscription;

  StreamSubscription<MouseEvent> onDropSubscription;

  StreamSubscription<MouseEvent> onDragLeaveSubscription;

  @override
  void init() {
    onDragOverSubscription = document.body.onDragOver.listen(_onDragOver);
    onDragLeaveSubscription = document.body.onDragLeave.listen(_onDragLeave);
    onDropSubscription = document.body.onDrop.listen(_onDrop);
  }

  @override
  void dispose() {
    onDragOverSubscription?.cancel();
    onDragLeaveSubscription?.cancel();
    onDropSubscription?.cancel();
    super.dispose();
  }

  void _onDragOver(MouseEvent event) {
    super.dragOver(event.offset.x, event.offset.y);

    // This is necessary to allow us to drop.
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }

  void _onDragLeave(MouseEvent event) {
    super.dragLeave();
  }

  void _onDrop(MouseEvent event) async {
    super.drop();

    // Stop the browser from redirecting.
    event.preventDefault();

    if (activeState == null) return;

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
        final Map<String, dynamic> json = jsonDecode(reader.result);
        final devToolsJsonFile = DevToolsJsonFile(
          name: droppedFile.name,
          lastModifiedTime: droppedFile.lastModifiedDate,
          data: json,
        );
        activeState.widget.handleDrop(devToolsJsonFile);
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
