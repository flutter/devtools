// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/debugger/file_search.dart';
import 'package:devtools_app/src/ui/search.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

void main() {
  final debuggerController = MockDebuggerController.withDefaults();
  final autoCompleteController = AutoCompleteController();

  Widget buildFileSearch() {
    return MaterialApp(
      home: Scaffold(
        body: Card(
          child: FileSearchField(
              debuggerController: debuggerController,
              autoCompleteController: autoCompleteController),
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

      autoCompleteController.search = '';
      expect(
          autoCompleteController.searchAutoComplete.value,
          equals([
            // Show all results (truncated to 10):
            'animals/cats/meow.dart',
            'animals/cats/purr.dart',
            'animals/dogs/bark.dart',
            'animals/dogs/growl.dart',
            'animals/insects/caterpillar.dart',
            'animals/insects/cicada.dart',
            'food/catering/party.dart',
            'food/carton/milk.dart',
            'food/milk/carton.dart',
            'travel/adventure/cave_tours_europe.dart',
          ]),
          reason: 'Correct search results for empty query.');

      autoCompleteController.search = 'c';
      expect(
          autoCompleteController.searchAutoComplete.value,
          equals([
            // Exact matches:
            'animals/cats/meow.dart',
            'animals/cats/purr.dart',
            'animals/insects/caterpillar.dart',
            'animals/insects/cicada.dart',
            'food/catering/party.dart',
            'food/carton/milk.dart',
            'food/milk/carton.dart',
            'travel/adventure/cave_tours_europe.dart',
            'travel/canada/banff.dart',
          ]),
          reason: 'Correct search results for "c" query.');

      autoCompleteController.search = 'ca';
      expect(
          autoCompleteController.searchAutoComplete.value,
          equals([
            // Exact matches:
            'animals/cats/meow.dart',
            'animals/cats/purr.dart',
            'animals/insects/caterpillar.dart',
            'animals/insects/cicada.dart',
            'food/catering/party.dart',
            'food/carton/milk.dart',
            'food/milk/carton.dart',
            'travel/adventure/cave_tours_europe.dart',
            'travel/canada/banff.dart',
          ]),
          reason: 'Correct search results for "ca" query.');

      autoCompleteController.search = 'cat';
      expect(
          autoCompleteController.searchAutoComplete.value,
          equals([
            // Exact matches:
            'animals/cats/meow.dart',
            'animals/cats/purr.dart',
            'animals/insects/caterpillar.dart',
            'food/catering/party.dart',
            // Fuzzy matches:
            'animals/insects/cicada.dart',
            'food/milk/carton.dart',
            'travel/adventure/cave_tours_europe.dart',
          ]),
          reason: 'Correct search results for "cat" query.');

      autoCompleteController.search = 'cate';
      expect(
          autoCompleteController.searchAutoComplete.value,
          equals([
            // Exact matches:
            'animals/insects/caterpillar.dart',
            'food/catering/party.dart',
            // Fuzzy matches:
            'travel/adventure/cave_tours_europe.dart',
          ]),
          reason: 'Correct search results for "cate" query.');

      autoCompleteController.search = 'cater';
      expect(
          autoCompleteController.searchAutoComplete.value,
          equals([
            // Exact matches:
            'animals/insects/caterpillar.dart',
            'food/catering/party.dart',
            // Fuzzy matches:
            'travel/adventure/cave_tours_europe.dart',
          ]),
          reason: 'Correct search results for "cater" query.');

      autoCompleteController.search = 'caterp';
      expect(
          autoCompleteController.searchAutoComplete.value,
          equals([
            // Exact matches:
            'animals/insects/caterpillar.dart',
            // Fuzzy matches:
            'travel/adventure/cave_tours_europe.dart',
          ]),
          reason: 'Correct search results for "caterp" query.');

      autoCompleteController.search = 'caterpi';
      expect(
          autoCompleteController.searchAutoComplete.value,
          equals([
            // Exact matches:
            'animals/insects/caterpillar.dart',
          ]),
          reason: 'Correct search results for "caterpi" query.');
    });
  });
}
