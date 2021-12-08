// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auto_dispose.dart';
import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../theme.dart';
import '../trees.dart';
import '../ui/utils.dart';
import '../utils.dart';

/// Top 10 matches to display in auto-complete overlay.
const defaultTopMatchesLimit = 10;
int topMatchesLimit = defaultTopMatchesLimit;

mixin SearchControllerMixin<T extends DataSearchStateMixin> {
  final _searchNotifier = ValueNotifier<String>('');
  final _searchInProgress = ValueNotifier<bool>(false);

  /// Notify that the search has changed.
  ValueListenable get searchNotifier => _searchNotifier;
  ValueListenable get searchInProgressNotifier => _searchInProgress;

  /// Last X position of caret in search field, used for pop-up position.
  double xPosition = 0.0;

  set search(String value) {
    _searchNotifier.value = value;
    refreshSearchMatches();
  }

  set searchInProgress(bool searchInProgress) {
    _searchInProgress.value = searchInProgress;
  }

  String get search => _searchNotifier.value;
  bool get isSearchInProgress => _searchInProgress.value;

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
    _activeSearchMatch.value?.isActiveSearchMatch = false;
    _activeSearchMatch.value = searchMatches.value[activeMatchIndex]
      ..isActiveSearchMatch = true;
  }

  List<T> matchesForSearch(String search) => [];

  void resetSearch() {
    _searchNotifier.value = '';
    refreshSearchMatches();
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
    @required this.searchFieldKey,
    @required this.onTap,
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
        .copyWith(color: colorScheme.autoCompleteTextColor);

    final autoCompleteHighlightedTextStyle =
        Theme.of(context).regularTextStyle.copyWith(
              color: searchColor,
              fontWeight: FontWeight.bold,
            );

    final tileContents = searchAutoComplete.value
        .map((match) => _maybeHighlightMatchText(
              match,
              autoCompleteTextStyle,
              autoCompleteHighlightedTextStyle,
            ))
        .toList();

    final tileEntryHeight = tileContents.isEmpty
        ? 0.0
        : calculateTextSpanHeight(tileContents.first) + denseSpacing;

    final tileEntryMaxWidth = tileContents.isEmpty
        ? 0.0
        : calculateTextSpanWidth(findLongestTextSpan(tileContents)) +
            denseSpacing;

    // Find the searchField and place overlay below bottom of TextField and
    // make overlay width of TextField. This is also we decide the height of
    // the ListTile height, position above (if bottom is false).
    final RenderBox box = searchFieldKey.currentContext.findRenderObject();

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

    final autoCompleteTiles = <GestureDetector>[];
    final count = min(searchAutoComplete.value.length, totalTiles);
    for (var index = 0; index < count; index++) {
      final textSpan = tileContents[index];
      autoCompleteTiles.add(
        GestureDetector(
          onTap: () {
            controller.selectTheSearch = true;
            controller.search = textSpan.text;
            autoComplete.onTap(textSpan.text);
          },
          child: Container(
            color: controller.currentDefaultIndex == index
                ? colorScheme.autoCompleteHighlightColor
                : colorScheme.defaultBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  textSpan,
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Compute the Y position of the popup (auto-complete list). Its bottom
    // will be positioned at the top of the text field. Add 1 includes
    // the TextField border.
    final yCoord =
        bottom ? 0.0 : -((count * tileEntryHeight) + box.size.height + 1);

    final xCoord = controller.xPosition;

    return Positioned(
      key: searchAutoCompleteKey,
      width: isMaxWidth
          ? max(tileEntryMaxWidth, box.size.width)
          : AutoCompleteSearchControllerMixin.minPopupWidth,
      height: bottom ? null : count * tileEntryHeight,
      child: CompositedTransformFollower(
        link: controller.autoCompleteLayerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        offset: Offset(xCoord, yCoord),
        child: Material(
          elevation: defaultElevation,
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: autoCompleteTiles,
            itemExtent: tileEntryHeight,
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
    final text = match.text;
    final matchedSegments = match.matchedSegments;

    if (matchedSegments == null || matchedSegments.isEmpty) {
      return TextSpan(
        text: text,
        style: regularTextStyle,
      );
    }

    final spans = <TextSpan>[];
    int previousEndIndex = 0;

    for (final segment in matchedSegments) {
      if (previousEndIndex < segment.begin) {
        // Add the unhighlighted segment before the current highlighted segment:
        final segmentBefore = text.substring(previousEndIndex, segment.begin);
        spans.add(
          TextSpan(
            text: segmentBefore,
            style: regularTextStyle,
          ),
        );
      }
      // Add the current highlighted segment:
      final highlightedSegment = text.substring(segment.begin, segment.end);
      spans.add(
        TextSpan(
          text: highlightedSegment,
          style: highlightedTextStyle,
        ),
      );
      previousEndIndex = segment.end;
    }
    if (previousEndIndex < text.length - 1) {
      // Add the last unhighlighted segment:
      final lastSegment = text.substring(previousEndIndex);
      spans.add(
        TextSpan(
          text: lastSegment,
          style: regularTextStyle,
        ),
      );
    }

    return TextSpan(
      text: spans.first.text,
      style: spans.first.style,
      children: spans.sublist(1),
    );
  }
}

const searchAutoCompleteKeyName = 'SearchAutoComplete';

@visibleForTesting
final searchAutoCompleteKey = GlobalKey(debugLabel: searchAutoCompleteKeyName);

/// Parts of active editing for auto-complete.
class EditingParts {
  EditingParts({
    this.activeWord,
    this.leftSide,
    this.rightSide,
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

  void clearSearchAutoComplete() {
    searchAutoComplete.value = [];

    // Default index is 0.
    currentDefaultIndex = 0;
  }

  /// Layer links autoComplete popup to the search TextField widget.
  final LayerLink autoCompleteLayerLink = LayerLink();

  OverlayEntry autoCompleteOverlay;

  int currentDefaultIndex;

  static const minPopupWidth = 300.0;

  /// [bottom] if false placed above TextField (search field).
  /// [maxWidth] if true drop-down is width of TextField otherwise minPopupWidth.
  OverlayEntry createAutoCompleteOverlay({
    @required BuildContext context,
    @required GlobalKey searchFieldKey,
    @required SelectAutoComplete onTap,
    bool bottom = true,
    bool maxWidth = true,
  }) {
    return OverlayEntry(builder: (context) {
      return AutoComplete(
        this,
        searchFieldKey: searchFieldKey,
        onTap: onTap,
        bottom: bottom,
        maxWidth: maxWidth,
      );
    });
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
    @required BuildContext context,
    @required GlobalKey searchFieldKey,
    @required SelectAutoComplete onTap,
    bool bottom = true,
    bool maxWidth = true,
  }) {
    if (autoCompleteOverlay != null) {
      closeAutoCompleteOverlay();
    }

    autoCompleteOverlay = createAutoCompleteOverlay(
      context: context,
      searchFieldKey: searchFieldKey,
      onTap: onTap,
      bottom: bottom,
      maxWidth: maxWidth,
    );

    Overlay.of(context).insert(autoCompleteOverlay);
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
    String activeWord;
    String leftSide;
    String rightSide;

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
}

mixin SearchableMixin<T> {
  List<T> searchMatches = [];

  T activeSearchMatch;
}

/// Callback when item in the drop-down list is selected.
typedef SelectAutoComplete = Function(String selection);

/// Callback to handle highlighting item in the drop-down list.
typedef HighlightAutoComplete = Function(
  AutoCompleteSearchControllerMixin controller,
  bool directionDown,
);

/// Callback for clearing the search field.
typedef ClearSearchField = Function(
  SearchControllerMixin controller, {
  bool force,
});

/// Provided by clients to specify where the autocomplete overlay should be
/// positioned relative to the input text.
typedef OverlayXPositionBuilder = double Function(
  String inputValue,
  TextStyle inputStyle,
);

mixin SearchFieldMixin<T extends StatefulWidget> on State<T> {
  TextEditingController searchTextFieldController;
  FocusNode _searchFieldFocusNode;
  SelectAutoComplete _onSelection;
  void Function() _closeHandler;

  FocusNode get searchFieldFocusNode => _searchFieldFocusNode;

  @override
  void initState() {
    super.initState();
    _searchFieldFocusNode = FocusNode(debugLabel: 'search-field');
    searchTextFieldController = TextEditingController();
  }

  void callOnSelection(String foundMatch) {
    _onSelection(foundMatch);
  }

  @override
  void dispose() {
    super.dispose();
    searchTextFieldController?.dispose();
    _searchFieldFocusNode?.dispose();
  }

  /// Platform independent (Mac or Linux).
  final arrowDown =
      LogicalKeyboardKey.arrowDown.keyId & LogicalKeyboardKey.valueMask;
  final arrowUp =
      LogicalKeyboardKey.arrowUp.keyId & LogicalKeyboardKey.valueMask;
  final enter = LogicalKeyboardKey.enter.keyId & LogicalKeyboardKey.valueMask;
  final escape = LogicalKeyboardKey.escape.keyId & LogicalKeyboardKey.valueMask;
  final tab = LogicalKeyboardKey.tab.keyId & LogicalKeyboardKey.valueMask;

  /// Work around Mac Desktop bug returning physical keycode instead of logical
  /// keyId for the RawKeyEvent's data.logical keyId keys ENTER and TAB.
  final enterMac = PhysicalKeyboardKey.enter.usbHidUsage;
  final tabMac = PhysicalKeyboardKey.tab.usbHidUsage;

  /// Hookup up TextField (search field) to the auto-complete overlay
  /// pop-up.
  ///
  /// [controller]
  /// [searchFieldKey]
  /// [searchFieldEnabled]
  /// [onSelection]
  /// [onHighlightDropdown] use to override default highlghter.
  /// [decoration]
  /// [overlayXPositionBuilder] callback function to determine where the
  /// autocomplete overlay should be positioned relative to the input text.
  /// [supportClearField] if true clear TextField content if pop-up not visible. If
  /// pop-up is visible close the pop-up on first ESCAPE.
  /// [keyEventsToPropogate] a set of key events that should be propogated to
  /// other handlers
  Widget buildAutoCompleteSearchField({
    @required AutoCompleteSearchControllerMixin controller,
    @required GlobalKey searchFieldKey,
    @required bool searchFieldEnabled,
    @required bool shouldRequestFocus,
    @required SelectAutoComplete onSelection,
    HighlightAutoComplete onHighlightDropdown,
    InputDecoration decoration,
    String label,
    OverlayXPositionBuilder overlayXPositionBuilder,
    bool supportClearField = false,
    Set<LogicalKeyboardKey> keyEventsToPropogate = const {},
    VoidCallback onClose,
  }) {
    _onSelection = onSelection;

    final searchField = _SearchField(
      controller: controller,
      searchFieldKey: searchFieldKey,
      searchFieldEnabled: searchFieldEnabled,
      shouldRequestFocus: shouldRequestFocus,
      searchFieldFocusNode: _searchFieldFocusNode,
      searchTextFieldController: searchTextFieldController,
      decoration: decoration,
      label: label,
      overlayXPositionBuilder: overlayXPositionBuilder,
      onClose: onClose,
    );

    return _AutoCompleteSearchField(
      controller: controller,
      searchField: searchField,
      searchFieldFocusNode: _searchFieldFocusNode,
      autoCompleteLayerLink: controller.autoCompleteLayerLink,
      onSelection: onSelection,
      onHighlightDropdown: onHighlightDropdown,
      clearSearchField: clearSearchField,
      keyEventsToPropogate: keyEventsToPropogate,
      supportClearField: supportClearField,
      closeHandler: _closeHandler,
    );
  }

  Widget buildSearchField({
    @required SearchControllerMixin controller,
    @required GlobalKey searchFieldKey,
    @required bool searchFieldEnabled,
    @required bool shouldRequestFocus,
    bool supportsNavigation = false,
    VoidCallback onClose,
    Widget prefix,
    Widget suffix,
  }) {
    return _SearchField(
      controller: controller,
      searchFieldKey: searchFieldKey,
      searchFieldEnabled: searchFieldEnabled,
      shouldRequestFocus: shouldRequestFocus,
      searchFieldFocusNode: _searchFieldFocusNode,
      searchTextFieldController: searchTextFieldController,
      supportsNavigation: supportsNavigation,
      onClose: onClose,
      prefix: prefix,
      suffix: suffix,
    );
  }

  void selectFromSearchField(
    SearchControllerMixin controller,
    String selection,
  ) {
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
      if (controller is AutoCompleteSearchControllerMixin) {
        controller.closeAutoCompleteOverlay();
      }
    }
  }

  void updateSearchField(
    SearchControllerMixin controller, {
    @required String newValue,
    @required int caretPosition,
  }) {
    searchTextFieldController.text = newValue;
    searchTextFieldController.selection =
        TextSelection.collapsed(offset: caretPosition);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    @required this.controller,
    @required this.searchFieldKey,
    @required this.searchFieldEnabled,
    @required this.shouldRequestFocus,
    @required this.searchFieldFocusNode,
    @required this.searchTextFieldController,
    this.label = 'Search',
    this.supportsNavigation = false,
    this.tracking = false,
    this.decoration,
    this.onClose,
    this.overlayXPositionBuilder,
    this.prefix,
    this.suffix,
  });

  final SearchControllerMixin controller;
  final GlobalKey searchFieldKey;
  final bool searchFieldEnabled;
  final bool shouldRequestFocus;
  final FocusNode searchFieldFocusNode;
  final TextEditingController searchTextFieldController;
  final String label;
  final bool supportsNavigation;
  final bool tracking;
  final InputDecoration decoration;
  final VoidCallback onClose;
  final OverlayXPositionBuilder overlayXPositionBuilder;
  final Widget prefix;
  final Widget suffix;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.subtitle1;
    final searchField = TextField(
      key: searchFieldKey,
      autofocus: true,
      enabled: searchFieldEnabled,
      focusNode: searchFieldFocusNode,
      controller: searchTextFieldController,
      style: textStyle,
      onChanged: (value) {
        if (overlayXPositionBuilder != null) {
          controller.xPosition = overlayXPositionBuilder(value, textStyle);
        }
        controller.search = value;
      },
      onEditingComplete: () {
        searchFieldFocusNode.requestFocus();
      },
      // Guarantee that the TextField on all platforms renders in the same
      // color for border, label text, and cursor. Primarly, so golden screen
      // snapshots will compare with the exact color.
      // Guarantee that the TextField on all platforms renders in the same
      // color for border, label text, and cursor. Primarly, so golden screen
      // snapshots will compare with the exact color.
      decoration: decoration ??
          InputDecoration(
            contentPadding: const EdgeInsets.all(denseSpacing),
            focusedBorder:
                OutlineInputBorder(borderSide: searchFocusBorderColor),
            enabledBorder:
                OutlineInputBorder(borderSide: searchFocusBorderColor),
            labelStyle: TextStyle(color: searchColor),
            border: const OutlineInputBorder(),
            labelText: label ?? 'Search',
            prefix: prefix != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                        prefix,
                        SizedBox(
                          height: 24.0,
                          width: defaultIconSize,
                          child: Transform.rotate(
                            angle: degToRad(90),
                            child: const PaddedDivider(
                              padding:
                                  EdgeInsets.symmetric(vertical: densePadding),
                            ),
                          ),
                        ),
                      ])
                : null,
            suffix: suffix != null
                ? suffix
                : (supportsNavigation || onClose != null)
                    ? _SearchFieldSuffix(
                        controller: controller,
                        supportsNavigation: supportsNavigation,
                        onClose: onClose,
                      )
                    : null,
          ),
      cursorColor: searchColor,
    );

    if (shouldRequestFocus) {
      searchFieldFocusNode.requestFocus();
    }

    return searchField;
  }
}

class SearchDropdown<T> extends StatelessWidget {
  const SearchDropdown({
    Key key,
    this.value,
    this.onChanged,
    this.isDense = false,
    this.style,
    this.selectedItemBuilder,
    this.items,
    this.onTap,
  }) : super(key: key);

  final T value;
  final ValueChanged<T> onChanged;
  final bool isDense;
  final TextStyle style;
  final DropdownButtonBuilder selectedItemBuilder;
  final List<DropdownMenuItem<T>> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        iconSize: defaultIconSize,
        value: value,
        onTap: onTap,
        onChanged: onChanged,
        isDense: true,
        style: style,
        selectedItemBuilder: selectedItemBuilder,
        items: items,
      ),
    );
  }
}

class _AutoCompleteSearchField extends StatelessWidget {
  const _AutoCompleteSearchField({
    @required this.searchField,
    @required this.controller,
    @required this.searchFieldFocusNode,
    @required this.autoCompleteLayerLink,
    @required this.onSelection,
    @required this.onHighlightDropdown,
    @required this.clearSearchField,
    this.keyEventsToPropogate = const {},
    this.supportClearField = false,
    this.closeHandler,
  });

  final AutoCompleteSearchControllerMixin controller;
  final _SearchField searchField;
  final FocusNode searchFieldFocusNode;
  final LayerLink autoCompleteLayerLink;
  final SelectAutoComplete onSelection;
  final HighlightAutoComplete onHighlightDropdown;
  final ClearSearchField clearSearchField;
  final Set<LogicalKeyboardKey> keyEventsToPropogate;
  final bool supportClearField;
  final VoidCallback closeHandler;

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

  /// Work around Mac Desktop bug returning physical keycode instead of logical
  /// keyId for the RawKeyEvent's data.logical keyId keys ENTER and TAB.
  int get enterMac => PhysicalKeyboardKey.enter.usbHidUsage;
  int get tabMac => PhysicalKeyboardKey.tab.usbHidUsage;

  @override
  Widget build(BuildContext context) {
    final highlightDropdown =
        onHighlightDropdown != null ? onHighlightDropdown : _highlightDropdown;

    final rawKeyboardFocusNode = FocusNode(debugLabel: 'search');

    rawKeyboardFocusNode.onKey = (FocusNode node, RawKeyEvent event) {
      if (event is RawKeyDownEvent) {
        final key = event.data.logicalKey.keyId & LogicalKeyboardKey.valueMask;

        if (key == escape) {
          // TODO(kenz): Enable this once we find a way around the navigation
          // this causes. This triggers a "back" navigation.
          // ESCAPE key pressed clear search TextField.c
          if (controller.autoCompleteOverlay != null) {
            controller.closeAutoCompleteOverlay();
          } else if (supportClearField) {
            // If pop-up closed ESCAPE will clean the TextField.
            clearSearchField(controller, force: true);
          }
          return _determineKeyEventResult(
            key,
            keyEventsToPropogate,
          );
        } else if (controller.autoCompleteOverlay != null) {
          if (key == enter || key == enterMac || key == tab || key == tabMac) {
            // Enter / Tab pressed.
            String foundExact;

            // What the user has typed in so far.
            final searchToMatch = controller.search.toLowerCase();
            // Find exact match in autocomplete list - use that as our search value.
            for (final autoEntry in controller.searchAutoComplete.value) {
              if (searchToMatch == autoEntry.text.toLowerCase()) {
                foundExact = autoEntry.text;
                break;
              }
            }
            // Nothing found, pick item selected in dropdown.
            final autoCompleteList = controller.searchAutoComplete.value;
            if (foundExact == null ||
                autoCompleteList[controller.currentDefaultIndex].text !=
                    foundExact) {
              if (autoCompleteList.isNotEmpty) {
                foundExact =
                    autoCompleteList[controller.currentDefaultIndex].text;
              }
            }

            if (foundExact != null) {
              controller.selectTheSearch = true;
              controller.search = foundExact;
              onSelection(foundExact);
              return _determineKeyEventResult(key, keyEventsToPropogate);
            }
          } else if (key == arrowDown || key == arrowUp) {
            highlightDropdown(controller, key == arrowDown);
            return _determineKeyEventResult(key, keyEventsToPropogate);
          }
        }

        // We don't support tabs in the search input. Swallow to prevent a
        // change of focus.
        if (key == tab || key == tabMac) {
          _determineKeyEventResult(key, keyEventsToPropogate);
        }
      }

      return KeyEventResult.ignored;
    };

    if (closeHandler != null) {
      searchFieldFocusNode.removeListener(closeHandler);
    }
    final autoCompleteCloseHandler = () {
      if (!searchFieldFocusNode.hasFocus) {
        controller.closeAutoCompleteOverlay();
      }
    };
    searchFieldFocusNode.addListener(autoCompleteCloseHandler);

    return RawKeyboardListener(
      focusNode: rawKeyboardFocusNode,
      child: CompositedTransformTarget(
        link: autoCompleteLayerLink,
        child: searchField,
      ),
    );
  }

  KeyEventResult _determineKeyEventResult(
    int keyEventId,
    Set<LogicalKeyboardKey> keyEventsToPropogate,
  ) {
    final shouldPropogateKeyEvent = keyEventsToPropogate
        .any((key) => key.keyId & LogicalKeyboardKey.valueMask == keyEventId);
    return shouldPropogateKeyEvent
        ? KeyEventResult.ignored
        : KeyEventResult.handled;
  }

  void _highlightDropdown(
    AutoCompleteSearchControllerMixin controller,
    bool directionDown,
  ) {
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
}

class _SearchFieldSuffix extends StatelessWidget {
  const _SearchFieldSuffix({
    @required this.controller,
    this.supportsNavigation = false,
    this.onClose,
  });

  final SearchControllerMixin controller;
  final bool supportsNavigation;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    assert(supportsNavigation || onClose != null);
    if (supportsNavigation) {
      return SearchNavigationControls(controller, onClose: onClose);
    } else {
      return closeSearchDropdownButton(onClose);
    }
  }
}

class SearchNavigationControls extends StatelessWidget {
  const SearchNavigationControls(this.controller, {@required this.onClose});

  final SearchControllerMixin controller;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: controller.searchMatches,
        builder: (context, matches, _) {
          final numMatches = matches.length;
          return ValueListenableBuilder(
            valueListenable: controller.searchInProgressNotifier,
            builder: (context, isSearchInProgress, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Opacity(
                    opacity: isSearchInProgress ? 1 : 0,
                    child: SizedBox(
                      width: scaleByFontFactor(10.0),
                      height: scaleByFontFactor(10.0),
                      child: isSearchInProgress
                          ? CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).textTheme.bodyText2.color),
                            )
                          : const SizedBox(),
                    ),
                  ),
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
                  if (onClose != null) closeSearchDropdownButton(onClose)
                ],
              );
            },
          );
        });
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

mixin DataSearchStateMixin {
  bool isSearchMatch = false;
  bool isActiveSearchMatch = false;
}

// This mixin is used to get around the type system where a type `T` needs to
// both extend `TreeNode<T>` and mixin `SearchableDataMixin`.
mixin TreeDataSearchStateMixin<T extends TreeNode<T>>
    on TreeNode<T>, DataSearchStateMixin {}

class AutoCompleteController extends DisposableController
    with SearchControllerMixin, AutoCompleteSearchControllerMixin {}

class AutoCompleteMatch {
  AutoCompleteMatch(this.text, {this.matchedSegments});

  final String text;
  final List<Range> matchedSegments;
}
