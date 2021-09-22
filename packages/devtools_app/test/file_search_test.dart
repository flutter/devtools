// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/debugger/file_search.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

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
        autoCompleteController.searchAutoComplete.value,
        equals([
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
        ]),
      );

      autoCompleteController.search = 'c';
      expect(
        autoCompleteController.searchAutoComplete.value,
        equals([
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
        ]),
      );

      autoCompleteController.search = 'ca';
      expect(
        autoCompleteController.searchAutoComplete.value,
        equals([
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
        ]),
      );

      autoCompleteController.search = 'cat';
      expect(
          autoCompleteController.searchAutoComplete.value,
          equals([
            // Exact matches:
            'zoo:animals/cats/meow.dart',
            'zoo:animals/cats/purr.dart',
            'zoo:animals/insects/caterpillar.dart',
            'kitchen:food/catering/party.dart',
            // Fuzzy matches:
            'zoo:animals/insects/cicada.dart',
            'kitchen:food/milk/carton.dart',
            'travel:adventure/cave_tours_europe.dart',
          ]),
          reason: 'Correct search results for "cat" query.');

      autoCompleteController.search = 'cate';
      expect(
        autoCompleteController.searchAutoComplete.value,
        equals([
          // Exact matches:
          'zoo:animals/insects/caterpillar.dart',
          'kitchen:food/catering/party.dart',
          // Fuzzy matches:
          'travel:adventure/cave_tours_europe.dart',
        ]),
      );

      autoCompleteController.search = 'cater';
      expect(
        autoCompleteController.searchAutoComplete.value,
        equals([
          // Exact matches:
          'zoo:animals/insects/caterpillar.dart',
          'kitchen:food/catering/party.dart',
          // Fuzzy matches:
          'travel:adventure/cave_tours_europe.dart',
        ]),
      );

      autoCompleteController.search = 'caterp';
      expect(
          autoCompleteController.searchAutoComplete.value,
          equals([
            // Exact matches:
            'zoo:animals/insects/caterpillar.dart',
            // Fuzzy matches:
            'travel:adventure/cave_tours_europe.dart',
          ]),
          reason: 'Correct search results for "caterp" query.');

      autoCompleteController.search = 'caterpi';
      expect(
        autoCompleteController.searchAutoComplete.value,
        equals([
          // Exact matches:
          'zoo:animals/insects/caterpillar.dart',
        ]),
      );

      autoCompleteController.search = 'caterpie';
      expect(
        autoCompleteController.searchAutoComplete.value,
        equals([
          // No matches message:
          'No files found.',
        ]),
      );
    });
  });
}
