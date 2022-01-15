// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/debugger/file_search.dart';
import 'package:devtools_app/src/ui/search.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:devtools_test/mocks.dart';
import 'package:devtools_test/wrappers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

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
        getAutoCompleteMatch(
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

      autoCompleteController.search = 'c';
      expect(
        getAutoCompleteMatch(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/Cats/meow.dart',
            'zoo:animals/Cats/purr.dart',
            'zoo:animals/inseCts/caterpillar.dart',
            'zoo:animals/inseCts/cicada.dart',
            'kitChen:food/catering/party.dart',
            'kitChen:food/carton/milk.dart',
            'kitChen:food/milk/carton.dart',
            'travel:adventure/Cave_tours_europe.dart',
            'travel:Canada/banff.dart'
          ],
        ),
      );

      autoCompleteController.search = 'ca';
      expect(
        getAutoCompleteMatch(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/CAts/meow.dart',
            'zoo:animals/CAts/purr.dart',
            'zoo:animals/insects/CAterpillar.dart',
            'zoo:animals/insects/ciCAda.dart',
            'kitchen:food/CAtering/party.dart',
            'kitchen:food/CArton/milk.dart',
            'kitchen:food/milk/CArton.dart',
            'travel:adventure/CAve_tours_europe.dart',
            'travel:CAnada/banff.dart'
          ],
        ),
      );

      autoCompleteController.search = 'cat';
      expect(
        getAutoCompleteMatch(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/CATs/meow.dart',
            'zoo:animals/CATs/purr.dart',
            'zoo:animals/insects/CATerpillar.dart',
            'kitchen:food/CATering/party.dart',
            // Fuzzy matches:
            'zoo:animals/insects/CicAda.darT',
            'kitchen:food/milk/CArTon.dart',
            'travel:adventure/CAve_Tours_europe.dart'
          ],
        ),
      );

      autoCompleteController.search = 'cate';
      expect(
        getAutoCompleteMatch(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/insects/CATErpillar.dart',
            'kitchen:food/CATEring/party.dart',
            // Fuzzy matches:
            'travel:adventure/CAve_Tours_Europe.dart'
          ],
        ),
      );

      autoCompleteController.search = 'cater';
      expect(
        getAutoCompleteMatch(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/insects/CATERpillar.dart',
            'kitchen:food/CATERing/party.dart',
            // Fuzzy matches:
            'travel:adventure/CAve_Tours_EuRope.dart'
          ],
        ),
      );

      autoCompleteController.search = 'caterp';
      expect(
        getAutoCompleteMatch(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/insects/CATERPillar.dart',
            // Fuzzy matches:
            'travel:adventure/CAve_Tours_EuRoPe.dart'
          ],
        ),
      );

      autoCompleteController.search = 'caterpi';
      expect(
        getAutoCompleteMatch(
          autoCompleteController.searchAutoComplete.value,
        ),
        equals(
          [
            // Exact matches:
            'zoo:animals/insects/CATERPIllar.dart',
          ],
        ),
      );

      autoCompleteController.search = 'caterpie';
      expect(autoCompleteController.searchAutoComplete.value, equals([]));
    });
  });
}

List<String> getAutoCompleteMatch(List<AutoCompleteMatch> matches) {
  return matches
      .map(
        (match) => transformAutoCompleteMatch<String>(
          match: match,
          transformMatchedSegment: (segment) => segment.toUpperCase(),
          transformUnmatchedSegment: (segment) => segment.toLowerCase(),
          combineSegments: (segments) => segments.join(''),
        ),
      )
      .toList();
}
