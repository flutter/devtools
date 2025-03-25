// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/editor/api_classes.dart';
import '../../../shared/editor/editor_client.dart';
import '../../../shared/ui/filter.dart';
import '../../../shared/utils/utils.dart';
import 'property_editor_types.dart';

typedef EditableWidgetData =
    ({
      List<EditableProperty> properties,
      String? name,
      String? documentation,
      String? fileUri,
    });

typedef EditArgumentFunction =
    Future<EditArgumentResponse?> Function<T>({
      required String name,
      required T value,
    });

class PropertyEditorController extends DisposableController
    with AutoDisposeControllerMixin, FilterControllerMixin<EditableProperty> {
  PropertyEditorController(this.editorClient) {
    init();
  }

  final EditorClient editorClient;

  String get gaId => gac.PropertyEditorSidebar.id;

  TextDocument? _currentDocument;
  CursorPosition? _currentCursorPosition;

  ValueListenable<EditableWidgetData?> get editableWidgetData =>
      _editableWidgetData;
  final _editableWidgetData = ValueNotifier<EditableWidgetData?>(null);

  ValueListenable<bool> get shouldReconnect => _shouldReconnect;
  final _shouldReconnect = ValueNotifier<bool>(false);

  bool get waitingForFirstEvent => _waitingForFirstEvent;
  bool _waitingForFirstEvent = true;

  late final Debouncer _editableArgsDebouncer;

  late final Timer _checkConnectionTimer;

  static const _editableArgsDebounceDuration = Duration(milliseconds: 600);

  static const _checkConnectionInterval = Duration(minutes: 1);

  @override
  void init() {
    super.init();
    _editableArgsDebouncer = Debouncer(duration: _editableArgsDebounceDuration);
    _checkConnectionTimer = _periodicallyCheckConnection(
      _checkConnectionInterval,
    );

    // Update in response to ActiveLocationChanged events.
    autoDisposeStreamSubscription(
      editorClient.activeLocationChangedStream.listen((event) async {
        if (_waitingForFirstEvent) _waitingForFirstEvent = false;
        final textDocument = event.textDocument;
        final cursorPosition = event.selections.first.active;
        // Don't do anything if the text document is null.
        if (textDocument == null) {
          return;
        }
        // Don't do anything if the event corresponds to the current position
        // and document version.
        //
        // Note: This is only checked if the document version is not null. For
        // IntelliJ, the document verison is always null, so identical events
        // indicating a valid change are possible.
        if (textDocument.version != null &&
            textDocument == _currentDocument &&
            cursorPosition == _currentCursorPosition) {
          return;
        }
        if (!textDocument.uriAsString.endsWith('.dart')) {
          _editableWidgetData.value = (
            properties: [],
            name: null,
            documentation: null,
            fileUri: textDocument.uriAsString,
          );
          return;
        }
        _editableArgsDebouncer.run(
          () => _updateWithEditableArgs(
            textDocument: textDocument,
            cursorPosition: cursorPosition,
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    _editableArgsDebouncer.dispose();
    _checkConnectionTimer.cancel();
    super.dispose();
  }

  @override
  void filterData(Filter<EditableProperty> filter) {
    super.filterData(filter);
    final filtered = (_editableWidgetData.value?.properties ?? []).where(
      (property) => property.matchesQuery(filter.queryFilter.query),
    );
    filteredData
      ..clear()
      ..addAll(filtered);
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

  Future<void> _updateWithEditableArgs({
    required TextDocument textDocument,
    required CursorPosition cursorPosition,
  }) async {
    _currentDocument = textDocument;
    _currentCursorPosition = cursorPosition;
    // Get the editable arguments for the current position.
    final result = await editorClient.getEditableArguments(
      textDocument: textDocument,
      position: cursorPosition,
    );
    final properties =
        (result?.args ?? <EditableArgument>[])
            .map(argToProperty)
            .nonNulls
            // Filter out any deprecated properties that aren't set.
            .where((property) => !property.isDeprecated || property.hasArgument)
            .toList();
    final name = result?.name;
    _editableWidgetData.value = (
      properties: properties,
      name: name,
      documentation: result?.documentation,
      fileUri: _currentDocument?.uriAsString,
    );
    filterData(activeFilter.value);
    // Register impression.
    ga.impression(
      gaId,
      gac.PropertyEditorSidebar.widgetPropertiesUpdate(name: name),
    );
  }

  Timer _periodicallyCheckConnection(Duration interval) {
    return Timer.periodic(interval, (timer) {
      final isClosed = editorClient.isClientClosed();
      if (isClosed) {
        _shouldReconnect.value = true;
        timer.cancel();
      }
    });
  }

  @visibleForTesting
  void initForTestsOnly({
    EditableArgumentsResult? editableArgsResult,
    TextDocument? document,
    CursorPosition? cursorPosition,
  }) {
    setActiveFilter();
    if (editableArgsResult != null) {
      _editableWidgetData.value = (
        properties:
            editableArgsResult.args.map(argToProperty).nonNulls.toList(),
        name: editableArgsResult.name,
        documentation: editableArgsResult.documentation,
        fileUri: document?.uriAsString,
      );
    }
    if (document != null) {
      _currentDocument = document;
    }
    if (cursorPosition != null) {
      _currentCursorPosition = cursorPosition;
    }
    filterData(activeFilter.value);
  }
}
