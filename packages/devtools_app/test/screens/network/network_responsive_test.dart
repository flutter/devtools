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
