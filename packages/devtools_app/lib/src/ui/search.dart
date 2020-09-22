// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../common_widgets.dart';
import '../theme.dart';
import '../utils.dart';

/// Top 10 matches to display in auto-complete overlay.
const topMatchesLimit = 10;

mixin SearchControllerMixin<T> {
  final _searchNotifier = ValueNotifier<String>('');

  /// Notify that the search has changed.
  ValueListenable get searchNotifier => _searchNotifier;

  set search(String value) {
    _searchNotifier.value = value;
    refreshSearchMatches();
  }

  String get search => _searchNotifier.value;

  final _searchMatches = ValueNotifier<List<T>>([]);

  ValueListenable<List<T>> get searchMatches => _searchMatches;

  void refreshSearchMatches() {
    updateMatches(matchesForSearch(_searchNotifier.value));
  }

  void updateMatches(List<T> matches) {
    _searchMatches.value = matches;
    if (matches.isEmpty) {
      matchIndex.value = 0;
    }
    if (matches.isNotEmpty && matchIndex.value == 0) {
      matchIndex.value = 1;
    }
    _updateActiveSearchMatch();
  }

  final _activeSearchMatch = ValueNotifier<T>(null);

  ValueListenable<T> get activeSearchMatch => _activeSearchMatch;

  /// 1-based index used for displaying matches status text (e.g. "2 / 15")
  final matchIndex = ValueNotifier<int>(0);

  void previousMatch() {
    var previousMatchIndex = matchIndex.value - 1;
    if (previousMatchIndex < 1) {
      previousMatchIndex = _searchMatches.value.length;
    }
    matchIndex.value = previousMatchIndex;
    _updateActiveSearchMatch();
  }

  void nextMatch() {
    var nextMatchIndex = matchIndex.value + 1;
    if (nextMatchIndex > _searchMatches.value.length) {
      nextMatchIndex = 1;
    }
    matchIndex.value = nextMatchIndex;
    _updateActiveSearchMatch();
  }

  void _updateActiveSearchMatch() {
    // [matchIndex] is 1-based. Subtract 1 for the 0-based list [searchMatches].
    final activeMatchIndex = matchIndex.value - 1;
    if (activeMatchIndex < 0) {
      _activeSearchMatch.value = null;
      return;
    }
    assert(activeMatchIndex < searchMatches.value.length);
    _activeSearchMatch.value = searchMatches.value[activeMatchIndex];
  }

  List<T> matchesForSearch(String search) => [];

  void resetSearch() {
    _searchNotifier.value = '';
    refreshSearchMatches();
  }
}

mixin AutoCompleteSearchControllerMixin on SearchControllerMixin {
  final selectTheSearchNotifier = ValueNotifier<bool>(false);

  bool get selectTheSearch => selectTheSearchNotifier.value;

  /// Search is very dynamic, with auto-complete or programmatic searching,
  /// setting the value to true will fire off searching.
  set selectTheSearch(bool v) {
    selectTheSearchNotifier.value = v;
  }

  final searchAutoComplete = ValueNotifier<List<String>>([]);

  ValueListenable<List<String>> get searchAutoCompleteNotifier =>
      searchAutoComplete;

  void clearSearchAutoComplete() {
    searchAutoComplete.value = [];
  }

  /// Layer links autoComplete popup to the search TextField widget.
  final LayerLink autoCompleteLayerLink = LayerLink();

  OverlayEntry autoCompleteOverlay;

  OverlayEntry createAutoCompleteOverlay({
    @required GlobalKey searchFieldKey,
  }) {
    // TODO(kenz): investigate whether we actually need the global key for this.
    // Find the searchField and place overlay below bottom of TextField and
    // make overlay width of TextField.
    final RenderBox box = searchFieldKey.currentContext.findRenderObject();

    final autoCompleteTiles = <ListTile>[];
    for (final matchedName in searchAutoComplete.value) {
      autoCompleteTiles.add(
        ListTile(
          title: Text(matchedName),
          onTap: () {
            selectTheSearch = true;
            search = matchedName;
          },
        ),
      );
    }

    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: box.size.width,
          child: CompositedTransformFollower(
            link: autoCompleteLayerLink,
            showWhenUnlinked: false,
            offset: Offset(0.0, box.size.height),
            child: Material(
              elevation: 4.0,
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: autoCompleteTiles,
              ),
            ),
          ),
        );
      },
    );
  }

  void closeAutoCompleteOverlay() {
    autoCompleteOverlay?.remove();
    autoCompleteOverlay = null;
  }

  /// Helper setState callback when searchAutoCompleteNotifier changes, usage:
  ///
  ///     addAutoDisposeListener(controller.searchAutoCompleteNotifier, () {
  ///      setState(autoCompleteOverlaySetState(controller, context));
  ///     });
  VoidCallback autoCompleteOverlaySetState({
    @required GlobalKey searchFieldKey,
    @required BuildContext context,
  }) {
    return () {
      if (autoCompleteOverlay != null) {
        closeAutoCompleteOverlay();
      }

      autoCompleteOverlay = createAutoCompleteOverlay(
        searchFieldKey: searchFieldKey,
      );
      Overlay.of(context).insert(autoCompleteOverlay);
    };
  }
}

mixin SearchableMixin<T> {
  List<T> searchMatches = [];

  T activeSearchMatch;
}

mixin SearchFieldMixin {
  FocusNode searchFieldFocusNode;
  TextEditingController searchTextFieldController;
  FocusNode rawKeyboardFocusNode;

  Widget buildAutoCompleteSearchField({
    @required AutoCompleteSearchControllerMixin controller,
    @required GlobalKey searchFieldKey,
    @required bool searchFieldEnabled,
    @required bool shouldRequestFocus,
    @required Function(String selection) onSelection,
  }) {
    rawKeyboardFocusNode = FocusNode();
    return RawKeyboardListener(
      focusNode: rawKeyboardFocusNode,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey.keyId == LogicalKeyboardKey.escape.keyId) {
            // TODO(kenz): Enable this once we find a way around the navigation
            // this causes. This triggers a "back" navigation.
            // ESCAPE key pressed clear search TextField.
            // clearSearchField(controller);
          } else if (event.logicalKey.keyId == LogicalKeyboardKey.enter.keyId) {
            // ENTER pressed.
            var foundExact = false;
            // Find exact match in autocomplete list - use that as our search value.
            for (final autoEntry in controller.searchAutoComplete.value) {
              if (controller.search.toLowerCase() == autoEntry.toLowerCase()) {
                foundExact = true;
                onSelection(autoEntry);
              }
            }
            // Nothing found, pick first line in dropdown.
            if (!foundExact) {
              final autoCompleteList = controller.searchAutoComplete.value;
              if (autoCompleteList.isNotEmpty) {
                onSelection(autoCompleteList.first);
              }
            }
          }
        }
      },
      child: _buildSearchField(
        controller: controller,
        searchFieldKey: searchFieldKey,
        searchFieldEnabled: searchFieldEnabled,
        shouldRequestFocus: shouldRequestFocus,
        autoCompleteLayerLink: controller.autoCompleteLayerLink,
      ),
    );
  }

  Widget buildSearchField({
    @required SearchControllerMixin controller,
    @required GlobalKey searchFieldKey,
    @required bool searchFieldEnabled,
    @required bool shouldRequestFocus,
    bool supportsNavigation = false,
  }) {
    return _buildSearchField(
      controller: controller,
      searchFieldKey: searchFieldKey,
      searchFieldEnabled: searchFieldEnabled,
      shouldRequestFocus: shouldRequestFocus,
      autoCompleteLayerLink: null,
      supportsNavigation: supportsNavigation,
    );
  }

  Widget _buildSearchField({
    @required SearchControllerMixin controller,
    @required GlobalKey searchFieldKey,
    @required bool searchFieldEnabled,
    @required bool shouldRequestFocus,
    @required LayerLink autoCompleteLayerLink,
    bool supportsNavigation = false,
  }) {
    // Creating new TextEditingController.
    searchFieldFocusNode = FocusNode();

    if (controller is AutoCompleteSearchControllerMixin) {
      searchFieldFocusNode.addListener(() {
        if (!searchFieldFocusNode.hasFocus) {
          controller.closeAutoCompleteOverlay();
        }
      });
    }

    searchTextFieldController = TextEditingController(text: controller.search);
    searchTextFieldController.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.search.length));

    final searchField = TextField(
      key: searchFieldKey,
      autofocus: true,
      enabled: searchFieldEnabled,
      focusNode: searchFieldFocusNode,
      controller: searchTextFieldController,
      onChanged: (value) {
        controller.search = value;
      },
      onEditingComplete: () {
        searchFieldFocusNode.requestFocus();
      },
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.all(denseSpacing),
        border: const OutlineInputBorder(),
        labelText: 'Search',
        suffix: _buildSearchFieldSuffix(
          controller,
          supportsNavigation: supportsNavigation,
        ),
      ),
    );

    if (shouldRequestFocus) {
      searchFieldFocusNode.requestFocus();
    }

    if (controller is AutoCompleteSearchControllerMixin) {
      return CompositedTransformTarget(
        link: autoCompleteLayerLink,
        child: searchField,
      );
    }
    return searchField;
  }

  Widget _buildSearchFieldSuffix(
    SearchControllerMixin controller, {
    bool supportsNavigation = false,
  }) {
    final onClear = () => clearSearchField(controller);
    if (supportsNavigation) {
      return SearchNavigationControls(controller, onClear: onClear);
    } else {
      return clearInputButton(onClear);
    }
  }

  void selectFromSearchField(
      SearchControllerMixin controller, String selection) {
    searchTextFieldController.clear();
    controller.search = selection;
    clearSearchField(controller, force: true);
    if (controller is AutoCompleteSearchControllerMixin) {
      controller.selectTheSearch = true;
      controller.closeAutoCompleteOverlay();
    }
  }

  void clearSearchField(SearchControllerMixin controller, {force = false}) {
    if (force || controller.search.isNotEmpty) {
      searchTextFieldController.clear();
      controller.resetSearch();
    }
  }
}

class SearchNavigationControls extends StatelessWidget {
  const SearchNavigationControls(this.controller, {@required this.onClear});

  final SearchControllerMixin controller;

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.searchMatches,
      builder: (context, matches, _) {
        final numMatches = matches.length;
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _matchesStatus(numMatches),
            SizedBox(
              height: 24.0,
              width: defaultIconSize,
              child: Transform.rotate(
                angle: degToRad(90),
                child: const PaddedDivider(
                  padding: EdgeInsets.symmetric(vertical: densePadding),
                ),
              ),
            ),
            inputDecorationSuffixButton(Icons.keyboard_arrow_up,
                numMatches > 1 ? controller.previousMatch : null),
            inputDecorationSuffixButton(Icons.keyboard_arrow_down,
                numMatches > 1 ? controller.nextMatch : null),
            clearInputButton(onClear),
          ],
        );
      },
    );
  }

  Widget _matchesStatus(int numMatches) {
    return ValueListenableBuilder(
      valueListenable: controller.matchIndex,
      builder: (context, index, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: densePadding),
          child: Text(
            '$index/$numMatches',
            style: const TextStyle(fontSize: 12.0),
          ),
        );
      },
    );
  }
}
