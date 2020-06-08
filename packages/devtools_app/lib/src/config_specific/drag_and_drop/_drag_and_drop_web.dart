// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:flutter/material.dart';

import 'drag_and_drop.dart';

DragAndDropWeb createDragAndDrop({
  @required void Function(Map<String, dynamic> data) handleDrop,
  @required Widget child,
}) {
  return DragAndDropWeb(handleDrop: handleDrop, child: child);
}

class DragAndDropWeb extends DragAndDrop {
  const DragAndDropWeb({
    @required void Function(Map<String, dynamic> data) handleDrop,
    @required Widget child,
  }) : super.impl(handleDrop: handleDrop, child: child);

  @override
  _DragAndDropWebState createState() => _DragAndDropWebState();
}

class _DragAndDropWebState extends DragAndDropState {
  StreamSubscription<MouseEvent> onDragOverSubscription;
  StreamSubscription<MouseEvent> onDropSubscription;
  StreamSubscription<MouseEvent> onDragLeaveSubscription;

  @override
  void initState() {
    onDragOverSubscription = document.body.onDragOver.listen(_onDragOver);
    onDragLeaveSubscription = document.body.onDragLeave.listen(_onDragLeave);
    onDropSubscription = document.body.onDrop.listen(_onDrop);
    super.initState();
  }

  @override
  void dispose() {
    onDragOverSubscription?.cancel();
    onDragLeaveSubscription?.cancel();
    onDropSubscription?.cancel();
    super.dispose();
  }

  void _onDragOver(MouseEvent event) {
    super.dragOver();
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
        widget.handleDrop(json);
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
