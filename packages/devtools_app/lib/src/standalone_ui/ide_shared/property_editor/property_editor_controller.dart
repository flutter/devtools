// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../service/editor/api_classes.dart';
import '../../../service/editor/editor_client.dart';

class PropertyEditorController extends DisposableController
    with AutoDisposeControllerMixin {
  PropertyEditorController(this.editorClient) {
    _init();
  }

  final EditorClient editorClient;

  TextDocument? _currentDocument;
  CursorPosition? _currentCursorPosition;

  ValueListenable<List<EditableArgument>> get editableArgs => _editableArgs;
  final _editableArgs = ValueNotifier<List<EditableArgument>>([]);

  @visibleForTesting
  void updateEditableArgs(List<EditableArgument> args) {
    _editableArgs.value = args;
  }

  void _init() {
    autoDisposeStreamSubscription(
      editorClient.activeLocationChangedStream.listen((event) async {
        final textDocument = event.textDocument;
        final cursorPosition = event.selections.first.active;
        // Don't do anything if the event corresponds to the current position.
        if (textDocument == _currentDocument &&
            cursorPosition == _currentCursorPosition) {
          return;
        }
        _currentDocument = textDocument;
        _currentCursorPosition = cursorPosition;
        // Get the editable arguments for the current position.
        final result = await editorClient.getEditableArguments(
          textDocument: textDocument,
          position: cursorPosition,
        );
        final args = result?.args ?? <EditableArgument>[];
        updateEditableArgs(args);
      }),
    );
  }
}
