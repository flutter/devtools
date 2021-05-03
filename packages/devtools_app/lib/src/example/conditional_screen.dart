// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose.dart';
import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../globals.dart';
import '../screen.dart';
import '../theme.dart';
import '../ui/search.dart';

/// This is an example implementation of a conditional screen that supports
/// offline mode and uses a provided controller [ExampleController].
///
/// This class exists solely as an example and should not be used in the
/// DevTools app.
class ExampleConditionalScreen extends Screen {
  const ExampleConditionalScreen()
      : super.conditional(
          id: id,
          requiresLibrary: 'package:flutter/',
          title: 'Example',
          icon: Icons.palette,
        );

  static const id = 'example';

  @override
  Widget build(BuildContext context) {
    return const _ExampleConditionalScreenBody();
  }
}

class _ExampleConditionalScreenBody extends StatefulWidget {
  const _ExampleConditionalScreenBody();

  @override
  _ExampleConditionalScreenBodyState createState() =>
      _ExampleConditionalScreenBodyState();
}

/// Evaluation TextField Key
final evalFieldKey = GlobalKey(debugLabel: 'evalTextFieldKey');

class _ExampleConditionalScreenBodyState
    extends State<_ExampleConditionalScreenBody>
    with
        OfflineScreenMixin<_ExampleConditionalScreenBody, String>,
        AutoDisposeMixin,
        SearchFieldMixin<_ExampleConditionalScreenBody>,
        TickerProviderStateMixin {
  ExampleController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<ExampleController>(context);
    if (newController == controller) return;
    controller = newController;

    if (shouldLoadOfflineData()) {
      final json = offlineDataJson[ExampleConditionalScreen.id];
      if (json.isNotEmpty) {
        loadOfflineData(json['title']);
      }
    }

    addAutoDisposeListener(controller.searchNotifier, () {
      controller.handleAutoCompleteOverlay(
        context: context,
        searchFieldKey: evalFieldKey,
        onTap: selectTheMatch,
        bottom: false,
        maxWidth: false,
      );
    });

    addAutoDisposeListener(controller.selectTheSearchNotifier, _handleSearch);

    addAutoDisposeListener(controller.searchNotifier, _handleSearch);
  }

  List<String> _nameScopeMatches(
    String searchingValue, [
    bool isField = false,
  ]) {
    final knownScope = isField
        ? [
            'add',
            'addOne',
            'addOnly',
            'addAll',
            'plot',
            'xName',
            'yName',
            'traces',
            'clear',
            'addData',
            'rect',
            'top',
            'left',
            'bottom',
            'right',
            'length',
          ]
        : [
            'application',
            'appBar',
            'foo',
            'clear',
            'foobar',
            'reset',
            'index',
            'indexes',
            'length',
            'rebuild',
            'myApplication',
            'myWidget',
            'myAppBar',
            'myList',
            'myChart',
            'controller',
            'chart',
            'data',
            'name',
            'names',
            'myList',
          ];

    final matchingNames = knownScope.where((element) {
      final matchName = matchSearch(element, searchingValue);
      return matchName != null;
    });

    return matchingNames.toList();
  }

  void _handleSearch() {
    final searchingValue = controller.search;

    // Field of left-side searched word
    if (!controller.isField) {
      controller.isField = searchingValue.endsWith('.');
    }

    if (searchingValue.isNotEmpty) {
      if (controller.selectTheSearch) {
        // Found an exact match.
        controller.resetSearch();
        return;
      }

      // No exact match, return the list of possible matches.
      controller.clearSearchAutoComplete();

      // Find word in TextField to try and match (word breaks).
      final textFieldEditingValue = searchTextFieldController.value;
      final selection = textFieldEditingValue.selection;

      final parts = AutoCompleteSearchControllerMixin.activeEdtingParts(
        searchingValue,
        selection,
        handleFields: controller.isField,
      );

      // Only show pop-up if there's a real variable name or field.
      if (parts.activeWord.isEmpty && !parts.isField) return;

      final matches = _nameScopeMatches(parts.activeWord, parts.isField);

      // Remove duplicates and sort the matches.
      final normalizedMatches = matches.toSet().toList()..sort();
      // Use the top 10 matches:
      controller.searchAutoComplete.value = normalizedMatches.sublist(
        0,
        min(topMatchesLimit, normalizedMatches.length),
      );
    }
  }

  /// Replace the current activeWord (partial name) with the selected item from
  /// the auto-complete list [newMatch].
  void replaceWord(String newMatch) {
    final textFieldEditingValue = searchTextFieldController.value;
    final editingValue = textFieldEditingValue.text;
    final selection = textFieldEditingValue.selection;

    final parts = AutoCompleteSearchControllerMixin.activeEdtingParts(
      editingValue,
      selection,
      handleFields: controller.isField,
    );

    // Add the newly selected auto-complete value.
    final newValue = '${parts.leftSide}$newMatch${parts.rightSide}';

    // Update the value and caret position of the auto-completed word.
    controller.searchTextFieldValue = TextEditingValue(
      text: newValue,
      selection: TextSelection.fromPosition(
        // Update the caret position to just beyond the newly picked
        // auto-complete item.
        TextPosition(offset: parts.leftSide.length + newMatch.length),
      ),
    );
  }

  /// Return null if no match, otherwise string.
  String matchSearch(String knownName, String matchString) {
    final name = knownName.toLowerCase();
    if (name.contains(matchString.toLowerCase())) {
      return name;
    }
    return null;
  }

  @override
  void dispose() {
    // Clean up the TextFieldController and FocusNode.
    searchTextFieldController.dispose();
    searchFieldFocusNode.dispose();
    rawKeyboardFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exampleScreen = ValueListenableBuilder(
      valueListenable: controller.title,
      builder: (context, value, _) {
        return Center(child: Text(value));
      },
    );

    // TODO(terry): Should be in theme
    const evalBorder = BorderSide(color: Colors.white, width: 2);

    final evaluator = Column(children: [
      const Expanded(
        child: Placeholder(
          fallbackWidth: 300,
          fallbackHeight: 500,
          color: Colors.yellow,
        ),
      ),
      buildAutoCompleteSearchField(
        controller: controller,
        searchFieldKey: evalFieldKey,
        searchFieldEnabled: true,
        shouldRequestFocus: true,
        onSelection: selectTheMatch,
        onHighlightDropdown: highlightDropdown,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.all(denseSpacing),
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(borderSide: evalBorder),
          enabledBorder: OutlineInputBorder(borderSide: evalBorder),
          labelText: 'Eval',
        ),
        tracking: true,
      ),
    ]);

    // We put these two items in a stack because the screen's UI needs to be
    // built before offline data is processed in order to initialize listeners
    // that respond to data processing events. The spinner hides the screen's
    // empty UI while data is being processed.
    return Stack(
      children: [
        exampleScreen,
        if (loadingOfflineData)
          Container(
            color: Colors.grey[50],
            child: const CenteredCircularProgressIndicator(),
          ),
        evaluator,
      ],
    );
  }

  void highlightDropdown(bool directionDown) {
    final numItems = controller.searchAutoComplete.value.length - 1;
    var indexToSelect = controller.currentDefaultIndex;
    if (directionDown) {
      // Select next item in auto-complete overlay.
      ++indexToSelect;
      if (indexToSelect > numItems) {
        // Greater than max go back to top list item.
        indexToSelect = 0;
      }
    } else {
      // Select previous item item in auto-complete overlay.
      --indexToSelect;
      if (indexToSelect < 0) {
        // Less than first go back to bottom list item.
        indexToSelect = numItems;
      }
    }

    controller.currentDefaultIndex = indexToSelect;

    // Cause the auto-complete list to update, list is small 10 items max.
    controller.searchAutoComplete.value =
        controller.searchAutoComplete.value.toList();
  }

  /// Match, found,  select it and process via ValueNotifiers.
  void selectTheMatch(String foundName) {
    setState(() {
      replaceWord(foundName);

      // We're done with the selected auto-complete item.
      controller.selectTheSearch = false;
      controller.isField = false;

      controller.closeAutoCompleteOverlay();
    });
  }

  @override
  FutureOr<void> processOfflineData(String offlineData) async {
    await controller.processOfflineData(offlineData);
  }

  @override
  bool shouldLoadOfflineData() {
    return offlineMode &&
        offlineDataJson.isNotEmpty &&
        offlineDataJson[ExampleConditionalScreen.id] != null;
  }
}

class ExampleController extends DisposableController
    with
        AutoDisposeControllerMixin,
        SearchControllerMixin,
        AutoCompleteSearchControllerMixin {
  final ValueNotifier<String> title = ValueNotifier('Example screen');

  FutureOr<void> processOfflineData(String offlineData) {
    title.value = offlineData;
  }
}
