// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/editor/api_classes.dart';
import '../../../shared/editor/editor_client.dart';

typedef EditableWidgetData =
    ({List<EditableArgument> args, String? name, String? documentation});

typedef EditArgumentFunction =
    Future<EditArgumentResponse?> Function<T>({
      required String name,
      required T value,
    });

class PropertyEditorController extends DisposableController
    with AutoDisposeControllerMixin {
  PropertyEditorController(this.editorClient) {
    _init();
  }

  final EditorClient editorClient;

  String get gaId => gac.PropertyEditorSidebar.id;

  TextDocument? _currentDocument;
  CursorPosition? _currentCursorPosition;

  ValueListenable<EditableWidgetData?> get editableWidgetData =>
      _editableWidgetData;
  final _editableWidgetData = ValueNotifier<EditableWidgetData?>(null);

  void _init() {
    autoDisposeStreamSubscription(
      editorClient.activeLocationChangedStream.listen((event) async {
        final textDocument = event.textDocument;
        final cursorPosition = event.selections.first.active;
        // Don't do anything if the text document is null.
        if (textDocument == null) {
          return;
        }
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
        final name = result?.name;
        _editableWidgetData.value = (
          args: args,
          name: name,
          documentation: result?.documentation,
        );
        // Register impression.
        ga.impression(
          gaId,
          gac.PropertyEditorSidebar.widgetPropertiesUpdate(name: name),
        );
      }),
    );
  }

  Future<EditArgumentResponse?> editArgument<T>({
    required String name,
    required T value,
  }) async {
    final document = _currentDocument;
    final position = _currentCursorPosition;
    if (document == null || position == null) return null;
    return editorClient.editArgument(
      textDocument: document,
      position: position,
      name: name,
      value: value,
    );
  }

  @visibleForTesting
  void initForTestsOnly({
    EditableArgumentsResult? editableArgsResult,
    TextDocument? document,
    CursorPosition? cursorPosition,
  }) {
    if (editableArgsResult != null) {
      _editableWidgetData.value = (
        args: editableArgsResult.args,
        name: editableArgsResult.name,
        documentation: editableArgsResult.documentation,
      );
    }
    if (document != null) {
      _currentDocument = document;
    }
    if (cursorPosition != null) {
      _currentCursorPosition = cursorPosition;
    }
  }
}
