// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/ui/file_import.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test_infra/responsive_layout_utils.dart';

/// The width, in logical pixels, below which the search field is on its own
/// row. Matches the threshold in `NetworkScreen`.
const _searchOnOwnRowBelowWidth = 600.0;

/// The width, in logical pixels, below which the filter field is on its own
/// row. Matches the threshold in `NetworkScreen`.
const _filterOnOwnRowBelowWidth = 900.0;

Finder _inToolbar(Finder finder) {
  return find.descendant(of: find.byType(NetworkScreenBody), matching: finder);
}

/// Resizes the test window to [width] and pumps, rebuilding the screen at the
/// new size in the same widget tree.
Future<void> _setWindowWidth(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, responsiveLayoutHeight);
  tester.view.devicePixelRatio = 1.0;
  await tester.pump();
}

/// Whether the EditableText inside [field] holds primary focus.
bool _fieldHasFocus(WidgetTester tester, Finder field) {
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  if (editable.evaluate().isEmpty) return false;
  final focusNode = tester.widget<EditableText>(editable).focusNode;
  return focusNode.hasFocus &&
      identical(focusNode, FocusManager.instance.primaryFocus);
}

Finder get _search => _inToolbar(find.byType(SearchField<NetworkController>));

Finder get _filter =>
    _inToolbar(find.byType(StandaloneFilterField<NetworkRequest>));

Finder get _recordButton => _inToolbar(find.byType(StartStopRecordingButton));

/// Asserts the layout of the Network toolbar at [width].
void _expectToolbarLayout(WidgetTester tester, {required double width}) {
  final body = tester.getRect(find.byType(NetworkScreenBody));
  final search = tester.getRect(_search);
  final filter = tester.getRect(_filter);
  final record = tester.getRect(_recordButton);
  final clear = tester.getRect(_inToolbar(find.byType(ClearButton)));
  final export = tester.getRect(_inToolbar(find.byType(OpenSaveButtonGroup)));

  expectNoIntersections({
    'record': record,
    'clear': clear,
    'search': search,
    'filter': filter,
    'export': export,
  });
  expectWithinBounds({
    'record': record,
    'clear': clear,
    'search': search,
    'filter': filter,
    'export': export,
  }, body);

  // The field's own controls were the elements that overlapped in the report.
  final fieldControls = <String, Rect>{
    for (final (i, control) in _inToolbar(
      find.descendant(
        of: _filter,
        matching: find.byType(InputDecorationSuffixButton),
      ),
    ).evaluate().indexed)
      'filterSuffix$i': tester.getRect(find.byWidget(control.widget)),
  };
  expect(fieldControls, isNotEmpty);
  expectWithinBounds(fieldControls, filter);
  expectNoIntersections(fieldControls);

  if (width < _searchOnOwnRowBelowWidth) {
    expect(search.top, greaterThanOrEqualTo(record.bottom - geometryTolerance));
  } else {
    expect(search.center.dy, closeTo(record.center.dy, geometryTolerance));
  }
  if (width < _filterOnOwnRowBelowWidth) {
    expect(filter.top, greaterThanOrEqualTo(search.bottom - geometryTolerance));
  } else {
    expect(filter.center.dy, closeTo(search.center.dy, geometryTolerance));
  }

  [_recordButton, _search, _filter].forEach(expectInteractable);
}

void main() {
  setUpAll(loadFonts);

  late FakeServiceConnectionManager connection;
  late NetworkController network;
  late LoggingController logging;
  late DebuggerController debugger;

  setUp(() {
    connection = createLayoutServiceConnection();
    setUpLayoutGlobals(connection);
    network = NetworkController();
    logging = LoggingController();
    debugger = DebuggerController();
  });

  for (final embedded in [false, true]) {
    group('Network toolbar (${embedded ? 'embedded' : 'standalone'})', () {
      for (final width in responsiveLayoutWidths) {
        testWidgetsWithWindowSize(
          'has no overlap or clipping at $width',
          Size(width, responsiveLayoutHeight),
          (WidgetTester tester) async {
            final errors = await collectFlutterErrors(
              () => pumpDevToolsScaffold(
                tester,
                pageId: ScreenMetaData.network.id,
                embedded: embedded,
                connected: true,
                connection: connection,
                network: network,
                logging: logging,
                debugger: debugger,
              ),
            );
            expect(errors, isEmpty, reason: errors.join('\n'));
            _expectToolbarLayout(tester, width: width);
            await stopNetworkPolling(tester, network);
          },
        );
      }
    });
  }

  group('Network toolbar state across resizes', () {
    // Resizing across the breakpoints reparents the search and filter fields
    // between rows. Their stable keys keep each field's state attached, so
    // text, selection, and focus survive the move.
    testWidgetsWithWindowSize(
      'search and filter keep text, selection, and focus across resizes',
      const Size(650, responsiveLayoutHeight),
      (WidgetTester tester) async {
        final errors = await collectFlutterErrors(
          () => pumpDevToolsScaffold(
            tester,
            pageId: ScreenMetaData.network.id,
            embedded: false,
            connected: true,
            connection: connection,
            network: network,
            logging: logging,
            debugger: debugger,
          ),
        );
        expect(errors, isEmpty, reason: errors.join('\n'));

        final searchEditable = find.descendant(
          of: _search,
          matching: find.byType(EditableText),
        );
        final filterEditable = find.descendant(
          of: _filter,
          matching: find.byType(EditableText),
        );

        await tester.enterText(searchEditable, 'method:GET');
        await tester.enterText(filterEditable, 'status:200');
        tester.widget<EditableText>(searchEditable).controller.selection =
            const TextSelection(baseOffset: 2, extentOffset: 7);
        tester.widget<EditableText>(filterEditable).controller.selection =
            const TextSelection(baseOffset: 1, extentOffset: 4);
        await tester.pump();

        // Focus the filter field so the test can catch a focus steal by the
        // search field's autofocus when it is remounted.
        await tester.showKeyboard(filterEditable);
        await tester.pump();

        final searchFieldState = tester.state(_search);
        final searchEditableState = tester.state(searchEditable);
        final filterFieldState = tester.state(_filter);
        final filterEditableState = tester.state(filterEditable);
        final searchCtl = tester
            .widget<EditableText>(searchEditable)
            .controller;
        final filterCtl = tester
            .widget<EditableText>(filterEditable)
            .controller;
        final searchText = searchCtl.value.text;
        final searchSelection = searchCtl.value.selection;
        final filterText = filterCtl.value.text;
        final filterSelection = filterCtl.value.selection;
        final activeQuery = network.activeFilter.value.queryFilter.query;

        expect(searchText, 'method:GET');
        expect(filterText, 'status:200');
        expect(network.search, 'method:GET');
        expect(_fieldHasFocus(tester, _filter), isTrue);
        expect(_fieldHasFocus(tester, _search), isFalse);

        // Cross each boundary in both directions in the same tree, and finish
        // on a wide desktop baseline.
        for (final width in [599.0, 600.0, 899.0, 900.0, 899.0, 1400.0]) {
          final resizeErrors = await collectFlutterErrors(
            () => _setWindowWidth(tester, width),
          );
          expect(resizeErrors, isEmpty, reason: resizeErrors.join('\n'));

          expect(
            tester.state(_search),
            same(searchFieldState),
            reason: 'SearchField state lost at $width',
          );
          expect(
            tester.state(searchEditable),
            same(searchEditableState),
            reason: 'search EditableText state lost at $width',
          );
          expect(
            tester.state(_filter),
            same(filterFieldState),
            reason: 'StandaloneFilterField state lost at $width',
          );
          expect(
            tester.state(filterEditable),
            same(filterEditableState),
            reason: 'filter EditableText state lost at $width',
          );
          expect(
            tester.widget<EditableText>(searchEditable).controller,
            same(searchCtl),
            reason: 'search text controller replaced at $width',
          );
          expect(
            tester.widget<EditableText>(filterEditable).controller,
            same(filterCtl),
            reason: 'filter text controller replaced at $width',
          );
          expect(searchCtl.value.text, searchText);
          expect(searchCtl.value.selection, searchSelection);
          expect(filterCtl.value.text, filterText);
          expect(filterCtl.value.selection, filterSelection);
          expect(network.search, 'method:GET');
          expect(network.activeFilter.value.queryFilter.query, activeQuery);
          expect(
            _fieldHasFocus(tester, _filter),
            isTrue,
            reason: 'filter focus lost at $width',
          );
          expect(
            _fieldHasFocus(tester, _search),
            isFalse,
            reason: 'remounted search field stole focus at $width',
          );
        }

        // The wide baseline still places both fields in the top row.
        final search = tester.getRect(_search);
        final filter = tester.getRect(_filter);
        final record = tester.getRect(_recordButton);
        expect(search.center.dy, closeTo(record.center.dy, geometryTolerance));
        expect(filter.center.dy, closeTo(search.center.dy, geometryTolerance));

        await stopNetworkPolling(tester, network);
      },
    );
  });

  group('Network toolbar behavior', () {
    for (final width in [328.0, 900.0, 1400.0]) {
      testWidgetsWithWindowSize(
        'search, filter, and recording work at $width',
        Size(width, responsiveLayoutHeight),
        (WidgetTester tester) async {
          await pumpDevToolsScaffold(
            tester,
            pageId: ScreenMetaData.network.id,
            embedded: false,
            connected: true,
            connection: connection,
            network: network,
            logging: logging,
            debugger: debugger,
          );

          await tester.enterText(
            find.descendant(of: _search, matching: find.byType(EditableText)),
            'GET',
          );
          expect(network.search, 'GET');

          await tester.enterText(
            find.descendant(of: _filter, matching: find.byType(EditableText)),
            'http',
          );
          expect(network.activeFilter.value.queryFilter.query, 'http');

          final wasRecording = network.recordingNotifier.value;
          await tester.tap(_recordButton);
          await tester.pump(const Duration(seconds: 1));
          expect(network.recordingNotifier.value, !wasRecording);

          await stopNetworkPolling(tester, network);
        },
      );
    }
  });
}
