// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:async/async.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../common_widgets.dart';
import '../primitives/trees.dart';
import '../primitives/utils.dart';
import '../ui/utils.dart';
import '../utils.dart';
import 'colors.dart';

// TODO(https://github.com/flutter/devtools/issues/5416): break this file up
// into managable pieces.

/// Top 10 matches to display in auto-complete overlay.
const defaultTopMatchesLimit = 10;
int topMatchesLimit = defaultTopMatchesLimit;

final _log = Logger('packages/devtools_app/lib/src/shared/ui/search');

mixin SearchControllerMixin<T extends SearchableDataMixin> {
  final _searchNotifier = ValueNotifier<String>('');
  final _searchInProgress = ValueNotifier<bool>(false);

  /// Notify that the search has changed.
  ValueListenable<String> get searchNotifier => _searchNotifier;
  ValueListenable<bool> get searchInProgressNotifier => _searchInProgress;

  CancelableOperation<void>? _searchOperation;
  Timer? _searchDebounce;

  set search(String value) {
    final previousSearchValue = _searchNotifier.value;
    final shouldSearchPreviousMatches = previousSearchValue.isNotEmpty &&
        value.caseInsensitiveContains(previousSearchValue);
    _searchNotifier.value = value;
    refreshSearchMatches(searchPreviousMatches: shouldSearchPreviousMatches);
  }

  set searchInProgress(bool searchInProgress) {
    _searchInProgress.value = searchInProgress;
  }

  String get search => _searchNotifier.value;
  bool get isSearchInProgress => _searchInProgress.value;

  final _searchMatches = ValueNotifier<List<T>>([]);

  ValueListenable<List<T>> get searchMatches => _searchMatches;

  /// Delay to reduce the amount of search queries
  /// Duration.zero (default) disables debounce
  Duration? get debounceDelay => null;

  /// Text field controller for the [SearchField] that this instance of
  /// [SearchControllerMixin] controls.
  SearchTextEditingController get searchTextFieldController =>
      _searchTextFieldController!;
  SearchTextEditingController? _searchTextFieldController;

  /// Focus node for the [SearchField] that this instance of
  /// [SearchControllerMixin] controls.
  FocusNode get searchFieldFocusNode => _searchFieldFocusNode!;
  FocusNode? _searchFieldFocusNode;

  void refreshSearchMatches({bool searchPreviousMatches = false}) {
    if (_searchNotifier.value.isNotEmpty) {
      if (debounceDelay != null) {
        _startDebounceTimer(
          search,
          searchPreviousMatches: searchPreviousMatches,
        );
      } else {
        final matches = matchesForSearch(
          _searchNotifier.value,
          searchPreviousMatches: searchPreviousMatches,
        );
        _updateMatches(matches);
      }
    } else {
      _updateMatches(<T>[]);
    }
  }

  void _startDebounceTimer(
    String search, {
    required bool searchPreviousMatches,
  }) {
    searchInProgress = true;

    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }

    assert(debounceDelay != null);
    _searchDebounce = Timer(
      search.isEmpty ? Duration.zero : debounceDelay!,
      () async {
        // Abort any ongoing search operations and start a new one
        try {
          await _searchOperation?.cancel();
        } catch (e, st) {
          _log.shout(e, e, st);
        }
        searchInProgress = true;

        // Start new search operation
        final future = Future(() {
          return matchesForSearch(
            _searchNotifier.value,
            searchPreviousMatches: searchPreviousMatches,
          );
        }).then((matches) {
          searchInProgress = false;
          _updateMatches(matches);
        });
        _searchOperation = CancelableOperation.fromFuture(future);
        await _searchOperation!.value;
        searchInProgress = false;
      },
    );
  }

  void _updateMatches(List<T> matches) {
    for (final previousMatch in _searchMatches.value) {
      previousMatch.isSearchMatch = false;
    }
    for (final newMatch in matches) {
      newMatch.isSearchMatch = true;
    }
    if (matches.isEmpty) {
      matchIndex.value = 0;
    }
    if (matches.isNotEmpty && matchIndex.value == 0) {
      matchIndex.value = 1;
    }
    _searchMatches.value = matches;
    _updateActiveSearchMatch();
  }

  final _activeSearchMatch = ValueNotifier<T?>(null);

  ValueListenable<T?> get activeSearchMatch => _activeSearchMatch;

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
    int activeMatchIndex = matchIndex.value - 1;
    if (activeMatchIndex < 0) {
      _activeSearchMatch.value?.isActiveSearchMatch = false;
      _activeSearchMatch.value = null;
      return;
    }
    if (searchMatches.value.isNotEmpty &&
        activeMatchIndex >= searchMatches.value.length) {
      activeMatchIndex = 0;
      matchIndex.value = 1; // first item because [matchIndex] us 1-based
    }

    _activeSearchMatch.value?.isActiveSearchMatch = false;
    if (searchMatches.value.isNotEmpty) {
      _activeSearchMatch.value = searchMatches.value[activeMatchIndex]
        ..isActiveSearchMatch = true;
    }
    onMatchChanged(activeMatchIndex);
  }

  /// The data that should be searched through when [matchesForSearch] is
  /// called.
  ///
  /// If [matchesForSearch] is overridden in such a way that
  /// [currentDataToSearchThrough] is not used, then this getter does not need
  /// to be implemented.
  Iterable<T> get currentDataToSearchThrough => throw UnimplementedError(
        'Implement this getter in order to use the default'
        ' [matchesForSearch] behavior.',
      );

  /// Default search matching logic.
  ///
  /// The use of this method requires both [currentDataToSearchThrough] and
  /// [T.matchesSearchToken] to be implemented.
  List<T> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) {
    if (search.isEmpty) return <T>[];
    final regexSearch = RegExp(search, caseSensitive: false);
    final matches = <T>[];
    if (searchPreviousMatches) {
      final previousMatches = searchMatches.value;
      for (final previousMatch in previousMatches) {
        if (previousMatch.matchesSearchToken(regexSearch)) {
          matches.add(previousMatch);
        }
      }
    } else {
      final searchData = currentDataToSearchThrough;
      for (final data in searchData) {
        if (data.matchesSearchToken(regexSearch)) {
          matches.add(data);
        }
      }
    }
    return matches;
  }

  /// Called when selected match index changes. Index is 0 based
  // Subclasses provide a valid implementation.
  // ignore: avoid-unused-parameters
  void onMatchChanged(int index) {}

  void resetSearch() {
    _searchNotifier.value = '';
    _searchTextFieldController?.clear();
    refreshSearchMatches();
  }

  @mustCallSuper
  void initSearch() {
    _searchTextFieldController?.dispose();
    _searchFieldFocusNode?.dispose();
    _searchTextFieldController = SearchTextEditingController()
      ..text = _searchNotifier.value;
    _searchFieldFocusNode = FocusNode(
      debugLabel: 'search-field',
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event.logicalKey.keyLabel == 'Enter') {
          if (event is RawKeyDownEvent) {
            if (event.isShiftPressed) {
              previousMatch();
            } else {
              nextMatch();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @mustCallSuper
  void disposeSearch() {
    unawaited(_searchOperation?.cancel());
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }
    _searchTextFieldController?.dispose();
    _searchFieldFocusNode?.dispose();
    _searchTextFieldController = null;
    _searchFieldFocusNode = null;
  }
}

class AutoComplete extends StatefulWidget {
  /// [controller] AutoCompleteController to associate with this pop-up.
  /// [searchFieldKey] global key of the TextField to associate with the
  /// auto-complete.
  /// [onTap] method to call when item in drop-down list is tapped.
  /// [bottom] display drop-down below (true) the TextField or above (false)
  /// the TextField.
  const AutoComplete(
    this.controller, {
    super.key,
    required this.searchFieldKey,
    required this.onTap,
    bool bottom = true, // If false placed above.
    bool maxWidth = true,
  })  : isBottom = bottom,
        isMaxWidth = maxWidth;

  final AutoCompleteSearchControllerMixin controller;
  final GlobalKey searchFieldKey;
  final SelectAutoComplete onTap;
  final bool isBottom;
  final bool isMaxWidth;

  @override
  AutoCompleteState createState() => AutoCompleteState();
}

class AutoCompleteState extends State<AutoComplete> with AutoDisposeMixin {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final autoComplete = context.widget as AutoComplete;
    final controller = autoComplete.controller;
    final searchFieldKey = autoComplete.searchFieldKey;
    final onTap = autoComplete.onTap;
    final bottom = autoComplete.isBottom;
    final isMaxWidth = autoComplete.isMaxWidth;

    addAutoDisposeListener(controller.searchAutoCompleteNotifier, () {
      controller.handleAutoCompleteOverlay(
        context: context,
        searchFieldKey: searchFieldKey,
        onTap: onTap,
        bottom: bottom,
        maxWidth: isMaxWidth,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final autoComplete = context.widget as AutoComplete;

    final controller = autoComplete.controller;
    final searchFieldKey = autoComplete.searchFieldKey;
    final bottom = autoComplete.isBottom;
    final isMaxWidth = autoComplete.isMaxWidth;
    final searchAutoComplete = controller.searchAutoComplete;

    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final autoCompleteTextStyle = Theme.of(context)
        .regularTextStyle
        .copyWith(color: colorScheme.contrastTextColor);

    final autoCompleteHighlightedTextStyle =
        Theme.of(context).regularTextStyle.copyWith(
              fontWeight: FontWeight.bold,
            );

    final tileContents = searchAutoComplete.value
        .map(
          (match) => _maybeHighlightMatchText(
            match,
            autoCompleteTextStyle,
            autoCompleteHighlightedTextStyle,
          ),
        )
        .toList();

    // When there are no tiles present, we don't need to display the
    // auto complete list.
    if (tileContents.isEmpty) return const SizedBox.shrink();

    final tileEntryHeight = tileContents.isEmpty
        ? 0.0
        : calculateTextSpanHeight(tileContents.first) + denseSpacing;

    // Find the searchField and place overlay below bottom of TextField and
    // make overlay width of TextField. This is also we decide the height of
    // the ListTile height, position above (if bottom is false).
    final RenderBox box =
        searchFieldKey.currentContext!.findRenderObject() as RenderBox;

    // Compute to global coordinates.
    final offset = box.localToGlobal(Offset.zero);

    final areaHeight = offset.dy;
    final maxAreaForPopup = areaHeight - tileEntryHeight;
    // TODO(terry): Scrolling doesn't work so max popup height is also total
    //              matches to use.
    topMatchesLimit = min(
      defaultTopMatchesLimit,
      (maxAreaForPopup / tileEntryHeight) - 1, // zero based.
    ).truncate();

    // Total tiles visible.
    final totalTiles = bottom
        ? searchAutoComplete.value.length
        : (maxAreaForPopup / tileEntryHeight).truncateToDouble();

    final autoCompleteTiles = <AutoCompleteTile>[];
    final count = min(searchAutoComplete.value.length, totalTiles);
    for (var index = 0; index < count; index++) {
      final textSpan = tileContents[index];
      autoCompleteTiles.add(
        AutoCompleteTile(
          index: index,
          textSpan: textSpan,
          controller: controller,
          onTap: autoComplete.onTap,
          highlightColor: colorScheme.autoCompleteHighlightColor,
          defaultColor: colorScheme.defaultBackgroundColor,
        ),
      );
    }

    // Compute the Y position of the popup (auto-complete list). Its bottom
    // will be positioned at the top of the text field. Add 1 includes
    // the TextField border.
    final double yCoord =
        bottom ? 0.0 : -((count * tileEntryHeight) + box.size.height + 1);

    final xCoord = controller.xPosition;

    return Positioned(
      key: searchAutoCompleteKey,
      width: isMaxWidth
          ? box.size.width
          : AutoCompleteSearchControllerMixin.minPopupWidth,
      height: count * tileEntryHeight,
      child: CompositedTransformFollower(
        link: controller.autoCompleteLayerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        offset: Offset(xCoord, yCoord),
        child: Material(
          elevation: defaultElevation,
          child: TextFieldTapRegion(
            child: ListView(
              padding: EdgeInsets.zero,
              itemExtent: tileEntryHeight,
              children: autoCompleteTiles,
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _maybeHighlightMatchText(
    AutoCompleteMatch match,
    TextStyle regularTextStyle,
    TextStyle highlightedTextStyle,
  ) {
    return match.transformAutoCompleteMatch<TextSpan>(
      transformMatchedSegment: (segment) => TextSpan(
        text: segment,
        style: highlightedTextStyle,
      ),
      transformUnmatchedSegment: (segment) => TextSpan(
        text: segment,
        style: regularTextStyle,
      ),
      combineSegments: (segments) => TextSpan(
        text: segments.first.text,
        style: segments.first.style,
        children: segments.sublist(1),
      ),
    );
  }
}

class AutoCompleteTile extends StatelessWidget {
  const AutoCompleteTile({
    super.key,
    required this.textSpan,
    required this.index,
    required this.controller,
    required this.onTap,
    required this.highlightColor,
    required this.defaultColor,
  });

  final TextSpan textSpan;
  final int index;
  final AutoCompleteSearchControllerMixin controller;
  final SelectAutoComplete onTap;
  final Color highlightColor;
  final Color defaultColor;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onHover: (_) {
        controller.setCurrentHoveredIndexValue(index);
      },
      child: GestureDetector(
        onTap: () {
          final selected = textSpan.toPlainText();
          controller.selectTheSearch = true;
          controller.search = selected;
          onTap(selected);
        },
        child: ValueListenableBuilder(
          valueListenable: controller.currentHoveredIndex,
          builder: (context, currentHoveredIndex, _) {
            return Container(
              color:
                  currentHoveredIndex == index ? highlightColor : defaultColor,
              padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
              alignment: Alignment.centerLeft,
              child: Text.rich(
                textSpan,
                maxLines: 1,
              ),
            );
          },
        ),
      ),
    );
  }
}

const searchAutoCompleteKeyName = 'SearchAutoComplete';

@visibleForTesting
final searchAutoCompleteKey = GlobalKey(debugLabel: searchAutoCompleteKeyName);

/// Parts of active editing for auto-complete.
class EditingParts {
  EditingParts({
    required this.activeWord,
    required this.leftSide,
    required this.rightSide,
  });

  final String activeWord;

  final String leftSide;

  final String rightSide;

  bool get isField => leftSide.endsWith('.');
}

/// Parsing characters looking for valid names e.g.,
///    [ _ | a..z | A..Z ] [ _ | a..z | A..Z | 0..9 ]+
const asciiSpace = 32;
const ascii0 = 48;
const ascii9 = 57;
const asciiUnderscore = 95;
const asciiA = 65;
const asciiZ = 90;
const asciia = 97;
const asciiz = 122;

mixin AutoCompleteSearchControllerMixin on SearchControllerMixin {
  final selectTheSearchNotifier = ValueNotifier<bool>(false);

  bool get selectTheSearch => selectTheSearchNotifier.value;

  /// Search is very dynamic, with auto-complete or programmatic searching,
  /// setting the value to true will fire off searching.
  set selectTheSearch(bool v) {
    selectTheSearchNotifier.value = v;
  }

  final searchAutoComplete = ValueNotifier<List<AutoCompleteMatch>>([]);

  ValueListenable<List<AutoCompleteMatch>> get searchAutoCompleteNotifier =>
      searchAutoComplete;

  /// Layer links autoComplete popup to the search TextField widget.
  final LayerLink autoCompleteLayerLink = LayerLink();

  OverlayEntry? autoCompleteOverlay;

  ValueListenable<int> get currentHoveredIndex => _currentHoveredIndex;

  final _currentHoveredIndex = ValueNotifier<int>(0);

  String? get currentHoveredText => searchAutoComplete.value.isNotEmpty
      ? searchAutoComplete.value[currentHoveredIndex.value].text
      : null;

  /// Last X position of caret in search field, used for pop-up position.
  double xPosition = 0.0;

  ValueListenable<String?> get currentSuggestion => _currentSuggestionNotifier;

  final _currentSuggestionNotifier = ValueNotifier<String?>(null);

  static const minPopupWidth = 300.0;

  /// Key used to find the search text field for positioning the auto complete
  /// overlay.
  GlobalKey get searchFieldKey;

  /// [FocusNode] for the keyboard listener responsible for handling auto
  /// complete search.
  FocusNode get rawKeyboardFocusNode => _rawKeyboardFocusNode!;
  FocusNode? _rawKeyboardFocusNode;

  @override
  void initSearch() {
    super.initSearch();
    _rawKeyboardFocusNode?.dispose();
    _rawKeyboardFocusNode = FocusNode(debugLabel: 'search-raw-keyboard');
  }

  @override
  void disposeSearch() {
    _rawKeyboardFocusNode?.dispose();
    _rawKeyboardFocusNode = null;
    super.disposeSearch();
  }

  void setCurrentHoveredIndexValue(int index) {
    _currentHoveredIndex.value = index;
  }

  void clearSearchAutoComplete() {
    searchAutoComplete.value = [];

    // Default index is 0.
    setCurrentHoveredIndexValue(0);
  }

  void updateCurrentSuggestion(String activeWord) {
    final hoveredText = currentHoveredText;
    final suggestion =
        hoveredText?.substring(min(activeWord.length, hoveredText.length));

    if (suggestion == null || suggestion.isEmpty) {
      clearCurrentSuggestion();
      return;
    }

    _currentSuggestionNotifier.value = suggestion;
  }

  void clearCurrentSuggestion() {
    _currentSuggestionNotifier.value = null;
  }

  /// [bottom] if false placed above TextField (search field).
  /// [maxWidth] if true drop-down is width of TextField otherwise minPopupWidth.
  OverlayEntry createAutoCompleteOverlay({
    required GlobalKey searchFieldKey,
    required SelectAutoComplete onTap,
    bool bottom = true,
    bool maxWidth = true,
  }) {
    return OverlayEntry(
      builder: (context) {
        return AutoComplete(
          this,
          searchFieldKey: searchFieldKey,
          onTap: onTap,
          bottom: bottom,
          maxWidth: maxWidth,
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
  void handleAutoCompleteOverlay({
    required BuildContext context,
    required GlobalKey searchFieldKey,
    required SelectAutoComplete onTap,
    bool bottom = true,
    bool maxWidth = true,
  }) {
    if (autoCompleteOverlay != null) {
      closeAutoCompleteOverlay();
    }

    autoCompleteOverlay = createAutoCompleteOverlay(
      searchFieldKey: searchFieldKey,
      onTap: onTap,
      bottom: bottom,
      maxWidth: maxWidth,
    );

    Overlay.of(context).insert(autoCompleteOverlay!);
  }

  /// Until an expression parser, poor man's way of finding the parts for
  /// auto-complete.
  ///
  /// Returns the parts of the editing area e.g.,
  ///
  ///                                        caret
  ///                                          ↓
  ///         addOne.yName + 1000 + myChart.tra┃
  ///         |_____________________________|_|
  ///                    ↑                   ↑
  ///                 leftSide           activeWord
  ///
  /// activeWord  is "tra"
  /// leftSide    is "addOne.yName + 1000 + myChart."
  /// rightSide   is "". RightSide isNotEmpty if caret is not
  ///             at the end the end TxtField value. If the
  ///             caret is within the text e.g.,
  ///
  ///                            caret
  ///                              ↓
  ///                 controller.cl┃ + 1000 + myChart.tra
  ///
  /// activeWord  is "cl"
  /// leftSide    is "controller."
  /// rightSide   is " + 1000 + myChart.tra"
  static EditingParts activeEditingParts(
    String editing,
    TextSelection selection, {
    bool handleFields = false,
  }) {
    String activeWord = '';
    String leftSide = '';
    String rightSide = '';

    final startSelection = selection.start;
    if (startSelection != -1 && startSelection == selection.end) {
      final selectionValue = editing.substring(0, startSelection);
      var lastSpaceIndex = selectionValue.lastIndexOf(handleFields ? '.' : ' ');
      lastSpaceIndex = lastSpaceIndex >= 0 ? lastSpaceIndex + 1 : 0;

      activeWord = selectionValue.substring(
        lastSpaceIndex,
        startSelection,
      );

      var variableStart = -1;
      // Validate activeWord is really a word.
      for (var index = activeWord.length - 1; index >= 0; index--) {
        final char = activeWord.codeUnitAt(index);

        if (char >= ascii0 && char <= ascii9) {
          // Keep gobbling # assuming might be part of variable name.
          continue;
        } else if (char == asciiUnderscore ||
            (char >= asciiA && char <= asciiZ) ||
            (char >= asciia && char <= asciiz)) {
          variableStart = index;
        } else if (variableStart == -1) {
          // Never had a variable start.
          lastSpaceIndex += activeWord.length;
          activeWord = selectionValue.substring(
            lastSpaceIndex - 1,
            startSelection - 1,
          );
          break;
        } else {
          lastSpaceIndex += variableStart;
          activeWord = selectionValue.substring(
            lastSpaceIndex,
            startSelection,
          );
          break;
        }
      }

      leftSide = selectionValue.substring(0, lastSpaceIndex);
      rightSide = editing.substring(startSelection);
    }

    return EditingParts(
      activeWord: activeWord,
      leftSide: leftSide,
      rightSide: rightSide,
    );
  }

  void clearSearchField({bool force = false}) {
    if (force || search.isNotEmpty) {
      resetSearch();
      closeAutoCompleteOverlay();
    }
  }

  void updateSearchField({
    required String newValue,
    required int caretPosition,
  }) {
    searchTextFieldController
      ..text = newValue
      ..selection = TextSelection.collapsed(offset: caretPosition);
  }
}

mixin SearchableMixin<T> {
  List<T> searchMatches = [];

  T? activeSearchMatch;
}

/// Callback when item in the drop-down list is selected.
typedef SelectAutoComplete = Function(String selection);

/// Callback to handle highlighting item in the drop-down list.
typedef HighlightAutoComplete = Function(
  AutoCompleteSearchControllerMixin controller,
  bool directionDown,
);

/// Provided by clients to specify where the autocomplete overlay should be
/// positioned relative to the input text.
typedef OverlayXPositionBuilder = double Function(
  String inputValue,
  TextStyle? inputStyle,
);

class SearchTextEditingController extends TextEditingController {
  String? _suggestionText;

  String? get suggestionText {
    if (_suggestionText == null) return null;
    if (selection.end < text.length) return null;

    return _suggestionText;
  }

  set suggestionText(String? suggestionText) {
    _suggestionText = suggestionText;
    notifyListeners();
  }

  bool get isAtEnd => text.length <= selection.end;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (suggestionText == null) {
      // If no `suggestionText` is provided, use the default implementation of `buildTextSpan`
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    return TextSpan(
      children: [
        TextSpan(text: text),
        TextSpan(
          text: suggestionText,
          style: style?.copyWith(color: Theme.of(context).colorScheme.grey),
        ),
      ],
      style: style,
    );
  }
}

/// Mixin for managing search field lifecycle.
///
/// This should be mixed into any [State] class that builds [SearchField] or
/// [AutoCompleteSearchField].
mixin SearchFieldMixin<T extends StatefulWidget>
    on AutoDisposeMixin<T>, State<T> {
  SearchControllerMixin get searchController;

  @override
  void initState() {
    super.initState();
    // ignore: avoid-unrelated-type-assertions, false positive.
    if (this is ProvidedControllerMixin) {
      // Controllers provided through package:provider will not be ready until
      // [didChangeDependencies] is called, so ensure [searchController] is
      // ready before calling [searchController.initSearch].
      (this as ProvidedControllerMixin).callWhenControllerReady((_) {
        searchController.initSearch();
      });
    } else {
      searchController.initSearch();
    }
  }

  @override
  void dispose() {
    searchController.disposeSearch();
    super.dispose();
  }
}

/// A stateful text field with search capability.
///
/// [_SearchFieldState] automatically handles the lifecycle of the search field
/// through the [SearchFieldMixin].
///
/// Use this widget for simple use cases where the elements initialized and
/// disposed in [SearchControllerMixin.initSearch] and
/// [SearchControllerMixin.disposeSearch] are not used outside of the context
/// of the search code.
///
/// If these elements need to be used by the widget state that builds the search
/// field, consider using [StatelessSearchField] instead and manually mixing in
/// [SearchFieldMixin] so that you can manage the lifecycle properly.
class SearchField<T extends SearchControllerMixin> extends StatefulWidget {
  SearchField({
    required this.searchController,
    this.searchFieldEnabled = true,
    this.shouldRequestFocus = false,
    this.supportsNavigation = true,
    this.onClose,
    this.searchFieldWidth = defaultSearchFieldWidth,
    double? searchFieldHeight,
    EdgeInsets? containerPadding,
    super.key,
  })  : searchFieldHeight = searchFieldHeight ?? defaultTextFieldHeight,
        containerPadding =
            containerPadding ?? const EdgeInsets.only(top: _defaultTopPadding);

  final T searchController;

  final double searchFieldWidth;

  final double searchFieldHeight;

  /// The padding for the [Container] that contains the search text field.
  final EdgeInsets containerPadding;

  /// Whether the search text field should be enabled.
  final bool searchFieldEnabled;

  /// Whether the search text field should automatically request focus once it
  /// is built.
  final bool shouldRequestFocus;

  /// Whether this search field includes navigation controls for traversing
  /// search results.
  final bool supportsNavigation;

  /// Optional callback called when the search field suffix close action is
  /// triggered.
  final VoidCallback? onClose;

  /// Padding to ensure the 'Search' hint on the text field is not cut off for
  /// the default text field height [defaultTextFieldHeight].
  static const _defaultTopPadding = 3.0;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField>
    with AutoDisposeMixin, SearchFieldMixin {
  @override
  SearchControllerMixin get searchController => widget.searchController;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.searchFieldWidth,
      height: widget.searchFieldHeight,
      padding: widget.containerPadding,
      child: StatelessSearchField(
        controller: searchController,
        searchFieldEnabled: widget.searchFieldEnabled,
        shouldRequestFocus: widget.shouldRequestFocus,
        supportsNavigation: widget.supportsNavigation,
        onClose: widget.onClose,
      ),
    );
  }
}

/// A stateless text field with search capability.
///
/// The widget that builds [StatelessSearchField] is responsible for mixing in
/// [SearchFieldMixin], which manages the search field lifecycle.
///
/// Use this widget for use cases where the default state management that
/// [SearchField] provides is not sufficient for the use case. This can be the
/// case when the elements initialized and disposed in
/// [SearchControllerMixin.initSearch] and [SearchControllerMixin.disposeSearch]
/// need to be accessed outside of the context of the search code.
class StatelessSearchField<T extends SearchableDataMixin>
    extends StatelessWidget {
  const StatelessSearchField({
    super.key,
    required this.controller,
    required this.searchFieldEnabled,
    required this.shouldRequestFocus,
    this.searchFieldKey,
    this.label = 'Search',
    this.decoration,
    this.supportsNavigation = false,
    this.onClose,
    this.onChanged,
    this.prefix,
    this.suffix,
    this.style,
  });

  final SearchControllerMixin<T> controller;

  /// Whether the search text field should be enabled.
  final bool searchFieldEnabled;

  /// Whether the search text field should automatically request focus once it
  /// is built.
  final bool shouldRequestFocus;

  /// Whether this search field includes navigation controls for traversing
  /// search results.
  final bool supportsNavigation;

  /// Label for the search field's input text decoration.
  final String label;

  /// Optional callback called when the search field suffix close action is
  /// triggered.
  final VoidCallback? onClose;

  /// Optional prefix to be used for the [TextField]'s decoration.
  final Widget? prefix;

  /// Optional suffix to be used for the [TextField]'s decoration.
  final Widget? suffix;

  /// Style for the search text field.
  final TextStyle? style;

  /// Optional decoration for the search text field.
  ///
  /// When null, a default [InputDecoration] will be used.
  final InputDecoration? decoration;

  /// Optional callback called in the [TextField]'s onChanged handler.
  final void Function(String)? onChanged;

  /// Optional key for the search text field.
  final GlobalKey? searchFieldKey;

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? Theme.of(context).textTheme.bodyMedium;

    final searchField = TextField(
      key: searchFieldKey,
      autofocus: true,
      enabled: searchFieldEnabled,
      focusNode: controller.searchFieldFocusNode,
      controller: controller.searchTextFieldController,
      style: textStyle,
      onChanged: (value) {
        onChanged?.call(value);
        controller.search = value;
        controller.searchFieldFocusNode.requestFocus();
      },
      onEditingComplete: () {
        controller.searchFieldFocusNode.requestFocus();
      },
      // Guarantee that the TextField on all platforms renders in the same
      // color for border, label text, and cursor. Primarly, so golden screen
      // snapshots will compare with the exact color.
      // Guarantee that the TextField on all platforms renders in the same
      // color for border, label text, and cursor. Primarly, so golden screen
      // snapshots will compare with the exact color.
      decoration: decoration ??
          InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: denseSpacing,
              vertical: densePadding,
            ),
            border: const OutlineInputBorder(),
            labelText: label,
            // TODO(kenz): add the search icon to the search field.
            prefix: prefix != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      prefix!,
                      SizedBox(
                        height: inputDecorationElementHeight,
                        width: defaultIconSize,
                        child: Transform.rotate(
                          angle: degToRad(90),
                          child: PaddedDivider.vertical(),
                        ),
                      ),
                    ],
                  )
                : null,
            suffix: suffix ??
                ((supportsNavigation || onClose != null)
                    ? _SearchFieldSuffix(
                        controller: controller,
                        supportsNavigation: supportsNavigation,
                        onClose: onClose,
                      )
                    : null),
          ),
    );

    if (shouldRequestFocus) {
      controller.searchFieldFocusNode.requestFocus();
    }

    return searchField;
  }
}

/// A text field with autocomplete search capability.
///
/// The widget that builds [AutoCompleteSearchField] is responsible for mixing
/// in [SearchFieldMixin], which manages the search field lifecycle.
class AutoCompleteSearchField extends StatefulWidget {
  const AutoCompleteSearchField({
    super.key,
    required this.controller,
    required this.searchFieldEnabled,
    required this.shouldRequestFocus,
    required this.onSelection,
    this.onHighlightDropdown,
    this.label = 'Search',
    this.decoration,
    this.overlayXPositionBuilder,
    this.clearFieldOnEscapeWhenOverlayHidden = false,
    this.onClose,
    this.onFocusLost,
    this.style,
    this.keyEventsToIgnore = const {},
  });

  final AutoCompleteSearchControllerMixin controller;

  /// Whether the search text field should be enabled.
  final bool searchFieldEnabled;

  /// Whether the search text field should automatically request focus once it
  /// is built.
  final bool shouldRequestFocus;

  /// Label for the search field's input text decoration.
  final String label;

  /// Callback called when the search field suffix close action is triggered.
  final VoidCallback? onClose;

  /// Callback to determine where the autocomplete overlay should be positioned
  /// relative to the input text.
  final OverlayXPositionBuilder? overlayXPositionBuilder;

  /// Style for the search text field.
  final TextStyle? style;

  /// Optional decoration for the search text field.
  ///
  /// When null, a default [InputDecoration] will be used.
  final InputDecoration? decoration;

  /// Handler called when an item is selected from the autocomplete dropdown.
  final SelectAutoComplete onSelection;

  /// Handler to manage how an item in the autocomplete dropdown should be
  /// highlighted.
  final HighlightAutoComplete? onHighlightDropdown;

  /// A set of key events that should be ignored, as they will be propagated to
  /// other handlers.
  final Set<LogicalKeyboardKey> keyEventsToIgnore;

  /// Whether to clear [TextField] content when the escape key is pressed and
  /// autocomplete overlay is not showing.
  final bool clearFieldOnEscapeWhenOverlayHidden;

  /// Handler called when either [controller.searchFieldFocusNode] or
  /// [controller.rawKeyboardFocusNode] has lost focus.
  final VoidCallback? onFocusLost;

  @override
  State<AutoCompleteSearchField> createState() =>
      _AutoCompleteSearchFieldState();
}

class _AutoCompleteSearchFieldState extends State<AutoCompleteSearchField>
    with AutoDisposeMixin {
  /// Platform independent (Mac or Linux).
  int get arrowDown =>
      LogicalKeyboardKey.arrowDown.keyId & LogicalKeyboardKey.valueMask;

  int get arrowUp =>
      LogicalKeyboardKey.arrowUp.keyId & LogicalKeyboardKey.valueMask;

  int get enter =>
      LogicalKeyboardKey.enter.keyId & LogicalKeyboardKey.valueMask;

  int get escape =>
      LogicalKeyboardKey.escape.keyId & LogicalKeyboardKey.valueMask;

  int get tab => LogicalKeyboardKey.tab.keyId & LogicalKeyboardKey.valueMask;

  int get arrowRight =>
      LogicalKeyboardKey.arrowRight.keyId & LogicalKeyboardKey.valueMask;

  HighlightAutoComplete get _highlightDropdown =>
      widget.onHighlightDropdown != null
          ? widget.onHighlightDropdown as HighlightAutoComplete
          : _highlightDropdownItem;

  @override
  void initState() {
    super.initState();

    addAutoDisposeListener(
      widget.controller.searchFieldFocusNode,
      _handleLostFocus,
    );
    addAutoDisposeListener(
      widget.controller.rawKeyboardFocusNode,
      _handleLostFocus,
    );
    widget.controller.rawKeyboardFocusNode.onKey = _handleKeyStrokes;
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: widget.controller.rawKeyboardFocusNode,
      child: CompositedTransformTarget(
        link: widget.controller.autoCompleteLayerLink,
        child: StatelessSearchField(
          controller: widget.controller,
          searchFieldKey: widget.controller.searchFieldKey,
          searchFieldEnabled: widget.searchFieldEnabled,
          shouldRequestFocus: widget.shouldRequestFocus,
          label: widget.label,
          decoration: widget.decoration,
          onChanged: (value) {
            if (widget.overlayXPositionBuilder != null) {
              widget.controller.xPosition = widget.overlayXPositionBuilder!(
                value,
                widget.style ?? Theme.of(context).textTheme.titleMedium,
              );
            }
          },
          onClose: widget.onClose,
          style: widget.style,
        ),
      ),
    );
  }

  void _handleLostFocus() {
    if (widget.controller.searchFieldFocusNode.hasPrimaryFocus ||
        widget.controller.rawKeyboardFocusNode.hasPrimaryFocus) {
      return;
    }

    if (widget.onFocusLost != null) {
      widget.onFocusLost!();
    } else {
      widget.controller.closeAutoCompleteOverlay();
    }
  }

  KeyEventResult _handleKeyStrokes(FocusNode _, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.data.logicalKey.keyId & LogicalKeyboardKey.valueMask;

      if (key == escape) {
        // TODO(kenz): Enable this once we find a way around the navigation
        // this causes. This triggers a "back" navigation.
        // ESCAPE key pressed clear search TextField.c
        if (widget.controller.autoCompleteOverlay != null) {
          widget.controller.closeAutoCompleteOverlay();
        } else if (widget.clearFieldOnEscapeWhenOverlayHidden) {
          // If pop-up closed ESCAPE will clean the TextField.
          widget.controller.clearSearchField(force: true);
        }
        return _determineKeyEventResult(key);
      } else if (widget.controller.autoCompleteOverlay != null) {
        if (key == enter ||
            key == tab ||
            (key == arrowRight &&
                widget.controller.searchTextFieldController.isAtEnd)) {
          // Enter / Tab pressed OR right arrow pressed while text field is at the end
          String? foundExact;

          // What the user has typed in so far.
          final searchToMatch = widget.controller.search.toLowerCase();
          // Find exact match in autocomplete list - use that as our search value.
          for (final autoEntry in widget.controller.searchAutoComplete.value) {
            if (searchToMatch == autoEntry.text.toLowerCase()) {
              foundExact = autoEntry.text;
              break;
            }
          }
          // Nothing found, pick item selected in dropdown.
          final autoCompleteList = widget.controller.searchAutoComplete.value;
          if (foundExact == null ||
              autoCompleteList[widget.controller.currentHoveredIndex.value]
                      .text !=
                  foundExact) {
            if (autoCompleteList.isNotEmpty) {
              foundExact =
                  autoCompleteList[widget.controller.currentHoveredIndex.value]
                      .text;
            }
          }

          if (foundExact != null) {
            widget.controller
              ..selectTheSearch = true
              ..search = foundExact;
            widget.onSelection(foundExact);
            return _determineKeyEventResult(key);
          }
        } else if (key == arrowDown || key == arrowUp) {
          _highlightDropdown(widget.controller, key == arrowDown);
          return _determineKeyEventResult(key);
        }
      }

      // We don't support tabs in the search input. Swallow to prevent a
      // change of focus.
      if (key == tab) {
        _determineKeyEventResult(key);
      }
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _determineKeyEventResult(int keyEventId) {
    final shouldIgnoreKeyEvent = widget.keyEventsToIgnore
        .any((key) => key.keyId & LogicalKeyboardKey.valueMask == keyEventId);
    return shouldIgnoreKeyEvent
        ? KeyEventResult.ignored
        : KeyEventResult.handled;
  }

  void _highlightDropdownItem(
    AutoCompleteSearchControllerMixin controller,
    bool directionDown,
  ) {
    final numItems = controller.searchAutoComplete.value.length - 1;
    var indexToSelect = controller.currentHoveredIndex.value;
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

    controller.setCurrentHoveredIndexValue(indexToSelect);
  }
}

class _SearchFieldSuffix extends StatelessWidget {
  const _SearchFieldSuffix({
    required this.controller,
    this.supportsNavigation = false,
    this.onClose,
  });

  final SearchControllerMixin controller;
  final bool supportsNavigation;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    assert(supportsNavigation || onClose != null);
    return supportsNavigation
        ? SearchNavigationControls(controller, onClose: onClose)
        : closeSearchDropdownButton(onClose);
  }
}

class SearchNavigationControls extends StatelessWidget {
  const SearchNavigationControls(
    this.controller, {
    super.key,
    required this.onClose,
  });

  final SearchControllerMixin controller;

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SearchableDataMixin>>(
      valueListenable: controller.searchMatches,
      builder: (context, matches, _) {
        final numMatches = matches.length;
        return ValueListenableBuilder<bool>(
          valueListenable: controller.searchInProgressNotifier,
          builder: (context, isSearchInProgress, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Opacity(
                  opacity: isSearchInProgress ? 1 : 0,
                  child: SizedBox(
                    width: scaleByFontFactor(smallProgressSize),
                    height: scaleByFontFactor(smallProgressSize),
                    child: isSearchInProgress
                        ? SmallCircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color?>(
                              Theme.of(context).textTheme.bodyMedium!.color,
                            ),
                          )
                        : const SizedBox(),
                  ),
                ),
                _matchesStatus(numMatches),
                SizedBox(
                  height: inputDecorationElementHeight,
                  width: defaultIconSize,
                  child: Transform.rotate(
                    angle: degToRad(90),
                    child: PaddedDivider.vertical(),
                  ),
                ),
                inputDecorationSuffixButton(
                  Icons.keyboard_arrow_up,
                  numMatches > 1 ? controller.previousMatch : null,
                ),
                inputDecorationSuffixButton(
                  Icons.keyboard_arrow_down,
                  numMatches > 1 ? controller.nextMatch : null,
                ),
                if (onClose != null) closeSearchDropdownButton(onClose),
              ],
            );
          },
        );
      },
    );
  }

  Widget _matchesStatus(int numMatches) {
    return ValueListenableBuilder<int>(
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

mixin SearchableDataMixin {
  bool isSearchMatch = false;
  bool isActiveSearchMatch = false;

  /// Whether this [SearchableDataMixin] is a match for the search query
  /// [search].
  ///
  /// This method is used by [SearchControllerMixin.matchesForSearch]. If
  /// [SearchControllerMixin.matchesForSearch] is overridden in such a way that
  /// [matchesSearchToken] is not used, then this method does not need to be
  /// implemented.
  bool matchesSearchToken(RegExp regExpSearch) => throw UnimplementedError(
        'Implement this method in order to use the default'
        ' [SearchControllerMixin.matchesForSearch] behavior.',
      );
}

// This mixin is used to get around the type system where a type `T` needs to
// both extend `TreeNode<T>` and mixin `DataSearchStateMixin`.
mixin TreeDataSearchStateMixin<T extends TreeNode<T>>
    on TreeNode<T>, SearchableDataMixin {}

class AutoCompleteController extends DisposableController
    with SearchControllerMixin, AutoCompleteSearchControllerMixin {
  AutoCompleteController(this._searchFieldKey);

  @override
  GlobalKey get searchFieldKey => _searchFieldKey;
  final GlobalKey _searchFieldKey;

  // TODO(jacobr): seems a little surprising that returning an empty list of
  // matches for the search is the intended behavior for the auto-complete
  // controller.
  @override
  List<SearchableDataMixin> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) =>
      const [];
}

class AutoCompleteMatch {
  AutoCompleteMatch(this.text, {this.matchedSegments = const <Range>[]});

  final String text;
  final List<Range> matchedSegments;

  /// Transform the autocomplete match somehow (e.g. create a TextSpan where the
  /// matched segments are highlighted).
  T transformAutoCompleteMatch<T>({
    required T Function(String segment) transformMatchedSegment,
    required T Function(String segment) transformUnmatchedSegment,
    required T Function(List<T> segments) combineSegments,
  }) {
    if (matchedSegments.isEmpty) {
      return transformUnmatchedSegment(text);
    }

    final segments = <T>[];
    int previousEndIndex = 0;
    for (final segment in matchedSegments) {
      if (previousEndIndex < segment.begin) {
        // Add the unmatched segment before the current matched segment:
        final segmentBefore =
            text.substring(previousEndIndex, segment.begin as int);
        segments.add(transformUnmatchedSegment(segmentBefore));
      }
      // Add the matched segment:
      final matchedSegment =
          text.substring(segment.begin as int, segment.end as int);
      segments.add(transformMatchedSegment(matchedSegment));
      previousEndIndex = segment.end as int;
    }
    if (previousEndIndex < text.length) {
      // Add the last unmatched segment:
      final lastSegment = text.substring(previousEndIndex);
      segments.add(transformUnmatchedSegment(lastSegment));
    }

    assert(segments.isNotEmpty);
    return combineSegments(segments);
  }
}

// TODO(kenz): try to use colors from the DevTools color schemes instead
extension AutoCompleteColorExtension on ColorScheme {
  Color get autoCompleteHighlightColor =>
      isLight ? Colors.grey[300]! : Colors.grey[700]!;
}
