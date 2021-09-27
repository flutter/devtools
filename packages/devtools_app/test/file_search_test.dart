// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/debugger/file_search.dart';
import 'package:devtools_app/src/ui/search.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:devtools_app/lib/test_helpers/mocks.dart';
import 'package:devtools_app/lib/test_helpers/wrappers.dart';

void main() {
  final debuggerController = MockDebuggerController.withDefaults();

  Widget buildFileSearch() {
    return MaterialApp(
      home: Scaffold(
        body: Card(
          child: FileSearchField(
            debuggerController: debuggerController,
          ),
        ),
      ),
    );
  }

  group('File search', () {
    setUp(() {
      when(debuggerController.sortedScripts)
          .thenReturn(ValueNotifier(mockScriptRefs));
    });

    testWidgetsWithWindowSize(
        'Search returns expected files', const Size(1000.0, 4000.0),
        (WidgetTester tester) async {
      await tester.pumpWidget(buildFileSearch());
      final FileSearchFieldState state =
          tester.state(find.byType(FileSearchField));
      final autoCompleteController = state.autoCompleteController;

      autoCompleteController.search = '';
      expect(
        getAutoCompleteTextValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Show all results (truncated to 10):
            'zoo:animals/cats/meow.dart',
            'zoo:animals/cats/purr.dart',
            'zoo:animals/dogs/bark.dart',
            'zoo:animals/dogs/growl.dart',
            'zoo:animals/insects/caterpillar.dart',
            'zoo:animals/insects/cicada.dart',
            'kitchen:food/catering/party.dart',
            'kitchen:food/carton/milk.dart',
            'kitchen:food/milk/carton.dart',
            'travel:adventure/cave_tours_europe.dart',
          ],
        ),
      );
      expect(
          getAutoCompleteSegmentValues(
            autoCompleteController.searchAutoComplete.value,
          ),
          equals(
            ['[]', '[]', '[]', '[]', '[]', '[]', '[]', '[]', '[]', '[]'],
          ));

      autoCompleteController.search = 'c';
      expect(
        getAutoCompleteTextValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/cats/meow.dart',
            'zoo:animals/cats/purr.dart',
            'zoo:animals/insects/caterpillar.dart',
            'zoo:animals/insects/cicada.dart',
            'kitchen:food/catering/party.dart',
            'kitchen:food/carton/milk.dart',
            'kitchen:food/milk/carton.dart',
            'travel:adventure/cave_tours_europe.dart',
            'travel:canada/banff.dart',
          ],
        ),
      );
      expect(
        getAutoCompleteSegmentValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            '[12-13]',
            '[12-13]',
            '[16-17]',
            '[16-17]',
            '[3-4]',
            '[3-4]',
            '[3-4]',
            '[17-18]',
            '[7-8]'
          ],
        ),
      );

      autoCompleteController.search = 'ca';
      expect(
        getAutoCompleteTextValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/cats/meow.dart',
            'zoo:animals/cats/purr.dart',
            'zoo:animals/insects/caterpillar.dart',
            'zoo:animals/insects/cicada.dart',
            'kitchen:food/catering/party.dart',
            'kitchen:food/carton/milk.dart',
            'kitchen:food/milk/carton.dart',
            'travel:adventure/cave_tours_europe.dart',
            'travel:canada/banff.dart',
          ],
        ),
      );
      expect(
        getAutoCompleteSegmentValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            '[12-14]',
            '[12-14]',
            '[20-22]',
            '[22-24]',
            '[13-15]',
            '[13-15]',
            '[18-20]',
            '[17-19]',
            '[7-9]'
          ],
        ),
      );

      autoCompleteController.search = 'cat';
      expect(
        getAutoCompleteTextValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/cats/meow.dart',
            'zoo:animals/cats/purr.dart',
            'zoo:animals/insects/caterpillar.dart',
            'kitchen:food/catering/party.dart',
            // Fuzzy matches:
            'zoo:animals/insects/cicada.dart',
            'kitchen:food/milk/carton.dart',
            'travel:adventure/cave_tours_europe.dart',
          ],
        ),
      );
      expect(
        getAutoCompleteSegmentValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            '[12-15]',
            '[12-15]',
            '[20-23]',
            '[13-16]',
            // Fuzzy matches:
            '[20-21, 23-24, 30-31]',
            '[18-19, 19-20, 21-22]',
            '[17-18, 18-19, 22-23]'
          ],
        ),
      );

      autoCompleteController.search = 'cate';
      expect(
        getAutoCompleteTextValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/insects/caterpillar.dart',
            'kitchen:food/catering/party.dart',
            // Fuzzy matches:
            'travel:adventure/cave_tours_europe.dart',
          ],
        ),
      );
      expect(
        getAutoCompleteSegmentValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            '[20-24]',
            '[13-17]',
            // Fuzzy matches:
            '[17-18, 18-19, 22-23, 28-29]'
          ],
        ),
      );

      autoCompleteController.search = 'cater';
      expect(
        getAutoCompleteTextValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/insects/caterpillar.dart',
            'kitchen:food/catering/party.dart',
            // Fuzzy matches:
            'travel:adventure/cave_tours_europe.dart',
          ],
        ),
      );
      expect(
        getAutoCompleteSegmentValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            '[20-25]',
            '[13-18]',
            // Fuzzy matches:
            '[17-18, 18-19, 22-23, 28-29, 30-31]'
          ],
        ),
      );

      autoCompleteController.search = 'caterp';
      expect(
        getAutoCompleteTextValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/insects/caterpillar.dart',
            // Fuzzy matches:
            'travel:adventure/cave_tours_europe.dart',
          ],
        ),
      );
      expect(
        getAutoCompleteSegmentValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            '[20-26]',
            // Fuzzy matches:
            '[17-18, 18-19, 22-23, 28-29, 30-31, 32-33]'
          ],
        ),
      );

      autoCompleteController.search = 'caterpi';
      expect(
        getAutoCompleteTextValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/insects/caterpillar.dart',
          ],
        ),
      );
      expect(
        getAutoCompleteSegmentValues(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            '[20-27]',
          ],
        ),
      );

      autoCompleteController.search = 'caterpie';
      expect(autoCompleteController.searchAutoComplete.value, equals([]));
    });
  });
}

List<String> getAutoCompleteTextValues(List<AutoCompleteMatch> matches) {
  return matches.map((match) => match.text).toList();
}

List<String> getAutoCompleteSegmentValues(List<AutoCompleteMatch> matches) {
  return matches
      .map((match) => convertSegmentsToString(match.matchedSegments))
      .toList();
}

String convertSegmentsToString(List<Range> segments) {
  if (segments == null || segments.isEmpty) {
    return '[]';
  }

  final stringSegments =
      segments.map((segment) => '${segment.begin}-${segment.end}');
  return '[${stringSegments.join(', ')}]';
}
