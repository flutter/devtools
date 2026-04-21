// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TestSearchController searchController;

  final testData = <TestSearchData>[
    TestSearchData('Foo'),
    TestSearchData('Bar'),
    TestSearchData('FooBar'),
    TestSearchData('Baz'),
    TestSearchData('FooBaz'),
  ];

  group('SearchControllerMixin', () {
    setUp(() {
      searchController = TestSearchController()..data.addAll(testData);
    });

    test('updates values for query', () {
      expect(searchController.search, isEmpty);
      expect(searchController.searchMatches.value, isEmpty);

      searchController.search = 'foo';

      expect(searchController.search, equals('foo'));
      expect(searchController.searchMatches.value.length, equals(3));
      expect(searchController.activeSearchMatch.value!.name, equals('Foo'));
      expect(searchController.matchIndex.value, equals(1));
      for (final data in testData) {
        if (data.name.caseInsensitiveContains('foo')) {
          expect(data.isSearchMatch, isTrue);
        } else {
          expect(data.isSearchMatch, isFalse);
        }
      }
    });

    test('nextMatch and previousMatch', () {
      searchController.search = 'foo';
      expect(searchController.matchIndex.value, equals(1));
      expect(searchController.activeSearchMatch.value!.name, equals('Foo'));

      searchController.nextMatch();
      expect(searchController.matchIndex.value, equals(2));
      expect(searchController.activeSearchMatch.value!.name, equals('FooBar'));

      searchController.nextMatch();
      expect(searchController.matchIndex.value, equals(3));
      expect(searchController.activeSearchMatch.value!.name, equals('FooBaz'));

      searchController.nextMatch();
      expect(searchController.matchIndex.value, equals(1));
      expect(searchController.activeSearchMatch.value!.name, equals('Foo'));

      searchController.previousMatch();
      expect(searchController.matchIndex.value, equals(3));
      expect(searchController.activeSearchMatch.value!.name, equals('FooBaz'));

      searchController.previousMatch();
      expect(searchController.matchIndex.value, equals(2));
      expect(searchController.activeSearchMatch.value!.name, equals('FooBar'));
    });

    test('resetSearch', () {
      searchController.search = 'foo';
      expect(searchController.search, equals('foo'));
      expect(searchController.searchMatches.value.length, equals(3));

      searchController.resetSearch();
      expect(searchController.search, isEmpty);
      expect(searchController.searchMatches.value, isEmpty);
    });

    test('searchPreviousMatches', () {
      searchController.search = 'foo';
      expect(searchController.searchMatches.value.length, equals(3));

      // Add a new item that matches 'foob' but was not in the previous matches.
      searchController.data.add(TestSearchData('FooBarBaz'));

      // Since 'foob' contains 'foo', it will search previous matches.
      // 'FooBarBaz' was not in the previous matches, so it should not be found.
      searchController.search = 'foob';
      expect(searchController.searchMatches.value.length, equals(2));
      expect(
        searchController.searchMatches.value.map((e) => e.name),
        equals(['FooBar', 'FooBaz']),
      );
    });

    test('updates values for empty query', () {
      searchController.search = 'foo';
      expect(searchController.search, equals('foo'));
      expect(searchController.searchMatches.value.length, equals(3));
      expect(searchController.activeSearchMatch.value!.name, equals('Foo'));
      expect(searchController.matchIndex.value, equals(1));
      for (final data in testData) {
        if (data.name.caseInsensitiveContains('foo')) {
          expect(data.isSearchMatch, isTrue);
        } else {
          expect(data.isSearchMatch, isFalse);
        }
      }

      // Set the search query to the empty string
      searchController.search = '';
      expect(searchController.search, equals(''));
      expect(searchController.searchMatches.value, isEmpty);
      expect(searchController.activeSearchMatch.value, isNull);
      expect(searchController.matchIndex.value, equals(0));
      for (final data in testData) {
        expect(data.isSearchMatch, isFalse);
      }
    });

    test('debounce', () async {
      final debounceController = TestDebounceSearchController()
        ..data.addAll(testData);
      expect(debounceController.search, isEmpty);
      expect(debounceController.searchMatches.value, isEmpty);

      debounceController.search = 'foo';
      expect(debounceController.search, equals('foo'));
      expect(
        debounceController.searchMatches.value,
        isEmpty,
      ); // Has not updated yet
      expect(debounceController.isSearchInProgress, isTrue);

      await Future.delayed(const Duration(milliseconds: 150));

      expect(debounceController.isSearchInProgress, isFalse);
      expect(debounceController.searchMatches.value.length, equals(3));
    });
  });

  group('AutoCompleteMatch', () {
    test('transformAutoCompleteMatch without matched segments', () {
      final match = AutoCompleteMatch('test');
      final result = match.transformAutoCompleteMatch<String>(
        transformMatchedSegment: (s) => '[$s]',
        transformUnmatchedSegment: (s) => '<$s>',
        combineSegments: (segments) => segments.join(),
      );
      expect(result, equals('<test>'));
    });

    test('transformAutoCompleteMatch with matched segments', () {
      final match = AutoCompleteMatch(
        'testSuggestion',
        matchedSegments: [
          const Range(0, 4), // 'test'
          const Range(10, 14), // 'tion'
        ],
      );
      final result = match.transformAutoCompleteMatch<String>(
        transformMatchedSegment: (s) => '[$s]',
        transformUnmatchedSegment: (s) => '<$s>',
        combineSegments: (segments) => segments.join(),
      );
      expect(result, equals('[test]<Sugges>[tion]'));
    });
  });

  group('AutoCompleteSearchControllerMixin', () {
    late TestAutoCompleteSearchController autoCompleteController;

    setUp(() {
      autoCompleteController = TestAutoCompleteSearchController();
    });

    tearDown(() {
      autoCompleteController.dispose();
    });

    test('clearSearchAutoComplete', () {
      autoCompleteController.searchAutoComplete.value = [
        AutoCompleteMatch('test'),
      ];
      autoCompleteController.setCurrentHoveredIndexValue(1);

      autoCompleteController.clearSearchAutoComplete();

      expect(autoCompleteController.searchAutoComplete.value, isEmpty);
      expect(autoCompleteController.currentHoveredIndex.value, equals(0));
    });

    test('updateCurrentSuggestion / clearCurrentSuggestion', () {
      autoCompleteController.searchAutoComplete.value = [
        AutoCompleteMatch('testSuggestion'),
      ];
      autoCompleteController.setCurrentHoveredIndexValue(0);

      autoCompleteController.updateCurrentSuggestion('test');
      expect(
        autoCompleteController.currentSuggestion.value,
        equals('Suggestion'),
      );

      autoCompleteController.updateCurrentSuggestion('testSuggest');
      expect(autoCompleteController.currentSuggestion.value, equals('ion'));

      // Active word is longer than hovered text (should not happen in practice but handled)
      autoCompleteController.updateCurrentSuggestion('testSuggestionWithMore');
      expect(autoCompleteController.currentSuggestion.value, isNull);

      autoCompleteController.clearCurrentSuggestion();
      expect(autoCompleteController.currentSuggestion.value, isNull);
    });

    test('activeEditingParts', () {
      final parts1 = AutoCompleteSearchControllerMixin.activeEditingParts(
        'addOne.yName + 1000 + myChart.tra',
        const TextSelection.collapsed(offset: 33),
      );
      expect(parts1.activeWord, equals('tra'));
      expect(parts1.leftSide, equals('addOne.yName + 1000 + myChart.'));
      expect(parts1.rightSide, equals(''));
      expect(parts1.isField, isTrue);

      final parts2 = AutoCompleteSearchControllerMixin.activeEditingParts(
        'controller.cl + 1000 + myChart.tra',
        const TextSelection.collapsed(offset: 13),
      );
      expect(parts2.activeWord, equals('cl'));
      expect(parts2.leftSide, equals('controller.'));
      expect(parts2.rightSide, equals(' + 1000 + myChart.tra'));
      expect(parts2.isField, isTrue);

      final parts3 = AutoCompleteSearchControllerMixin.activeEditingParts(
        'foo',
        const TextSelection.collapsed(offset: 3),
      );
      expect(parts3.activeWord, equals('foo'));
      expect(parts3.leftSide, equals(''));
      expect(parts3.rightSide, equals(''));
      expect(parts3.isField, isFalse);
    });

    test('clearSearchField', () {
      autoCompleteController.search = 'foo';
      autoCompleteController.clearSearchField();
      expect(autoCompleteController.search, isEmpty);

      autoCompleteController.clearSearchField(force: true);
      expect(autoCompleteController.search, isEmpty);
    });

    test('updateSearchField', () {
      autoCompleteController.updateSearchField(
        newValue: 'foo bar',
        caretPosition: 3,
      );
      expect(
        autoCompleteController.searchTextFieldController.text,
        equals('foo bar'),
      );
      expect(
        autoCompleteController.searchTextFieldController.selection.baseOffset,
        equals(3),
      );
    });
  });

  group('StatelessSearchField', () {
    testWidgets('calls onChanged and onClose', (WidgetTester tester) async {
      final searchController = TestSearchController()..init();
      bool closeCalled = false;
      String lastChangedValue = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatelessSearchField(
              controller: searchController,
              searchFieldEnabled: true,
              shouldRequestFocus: false,
              onClose: () {
                closeCalled = true;
              },
              onChanged: (value) {
                lastChangedValue = value;
              },
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'test input');
      await tester.pumpAndSettle();

      expect(lastChangedValue, equals('test input'));

      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      expect(closeCalled, isTrue);
    });
  });

  group('SearchField', () {
    testWidgets('calls onClose', (WidgetTester tester) async {
      final searchController = TestSearchController()..init();
      bool closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchField(
              searchController: searchController,
              onClose: () {
                closeCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'foo');
      await tester.pumpAndSettle();
      // find the close button
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      expect(closeCalled, isTrue);
    });
  });
}

class TestSearchController extends DisposableController
    with SearchControllerMixin<TestSearchData> {
  final data = <TestSearchData>[];

  @override
  Iterable<TestSearchData> get currentDataToSearchThrough => data;
}

class TestDebounceSearchController extends DisposableController
    with SearchControllerMixin<TestSearchData> {
  final data = <TestSearchData>[];

  @override
  Iterable<TestSearchData> get currentDataToSearchThrough => data;

  @override
  Duration? get debounceDelay => const Duration(milliseconds: 100);
}

class TestSearchData with SearchableDataMixin {
  TestSearchData(this.name);

  final String name;

  @override
  bool matchesSearchToken(RegExp regExpSearch) {
    return name.caseInsensitiveContains(regExpSearch.pattern);
  }
}

class TestAutoCompleteSearchController extends DisposableController
    with SearchControllerMixin, AutoCompleteSearchControllerMixin {
  TestAutoCompleteSearchController() {
    init();
  }

  @override
  GlobalKey<State<StatefulWidget>> get searchFieldKey => GlobalKey();

  @override
  Iterable<SearchableDataMixin> get currentDataToSearchThrough => [];
}
