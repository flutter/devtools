// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, as designed
import 'dart:html';

import '../../globals.dart';
import '../../primitives/utils.dart';
import 'drag_and_drop.dart';

DragAndDropManagerWeb createDragAndDropManager(int viewId) {
  return DragAndDropManagerWeb(viewId);
}

class DragAndDropManagerWeb extends DragAndDropManager {
  DragAndDropManagerWeb(int viewId) : super.impl(viewId);

  late final StreamSubscription<MouseEvent> onDragOverSubscription;

  late final StreamSubscription<MouseEvent> onDropSubscription;

  late final StreamSubscription<MouseEvent> onDragLeaveSubscription;

  @override
  void init() {
    onDragOverSubscription = document.body!.onDragOver.listen(_onDragOver);
    onDragLeaveSubscription = document.body!.onDragLeave.listen(_onDragLeave);
    onDropSubscription = document.body!.onDrop.listen(_onDrop);
  }

  @override
  void dispose() {
    unawaited(onDragOverSubscription.cancel());
    unawaited(onDragLeaveSubscription.cancel());
    unawaited(onDropSubscription.cancel());
    super.dispose();
  }

  void _onDragOver(MouseEvent event) {
    dragOver(event.offset.x as double, event.offset.y as double);

    // This is necessary to allow us to drop.
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }

  void _onDragLeave(MouseEvent _) {
    dragLeave();
  }

  void _onDrop(MouseEvent event) async {
    drop();

    // Stop the browser from redirecting.
    event.preventDefault();

    // If there is no active state or the active state does not have a drop
    // handler, return early.
    if (activeState?.widget.handleDrop == null) return;

    final List<File> files = event.dataTransfer.files!;
    if (files.length > 1) {
      notificationService.push('You cannot import more than one file.');
      return;
    }

    final droppedFile = files.first;
    if (droppedFile.type != 'application/json') {
      notificationService.push(
        '${droppedFile.type} is not a supported file type. Please import '
        'a .json file that was exported from Dart DevTools.',
      );
      return;
    }

    final FileReader reader = FileReader();
    reader.onLoad.listen((_) {
      try {
        final Object json = jsonDecode(reader.result as String);
        final devToolsJsonFile = DevToolsJsonFile(
          name: droppedFile.name,
          lastModifiedTime: droppedFile.lastModifiedDate,
          data: json,
        );
        activeState!.widget.handleDrop!(devToolsJsonFile);
      } on FormatException catch (e) {
        notificationService.push(
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
      notificationService.push('Could not import file: $e');
    }
  }
}
