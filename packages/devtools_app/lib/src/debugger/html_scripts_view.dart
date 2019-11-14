// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:html_shim/html.dart' as html;
import 'package:vm_service/vm_service.dart';

import '../debugger/debugger_state.dart';
import '../ui/html_custom.dart';
import '../ui/html_elements.dart';

enum ListDirection {
  pageUp,
  pageDown,
  home,
  end,
}

/// Keycode definitions.
const int DOM_VK_RETURN = 13;
const int DOM_VK_ESCAPE = 27;
const int DOM_VK_PAGE_UP = 33;
const int DOM_VK_PAGE_DOWN = 34;
const int DOM_VK_END = 35;
const int DOM_VK_HOME = 36;
const int DOM_VK_UP = 38;
const int DOM_VK_DOWN = 40;

typedef URIDescriber = String Function(String uri);

class HtmlPopupView extends CoreElement {
  HtmlPopupView(this._scriptsView, this._sourceArea, this._sourcePathDiv,
      this._popupTextfield)
      : super('div', classes: 'open-popup');

  final CoreElement _sourceArea; // Top div area container of _sourcePathDiv
  final CoreElement _sourcePathDiv; // Text name of the source
  final CoreElement _popupTextfield; // Textfield to show while popup is active.

  CoreElement get popupTextfield => _popupTextfield;

  final HtmlScriptsView _scriptsView;

  String _oldSourceNameTextColor;

  bool _poppedUp = false;

  bool get isPoppedUp => _poppedUp;

  void showPopup() {
    _poppedUp = true;

    add(_scriptsView);

    final int sourceAreaWidth = _sourceArea.element.clientWidth;

    _scriptsView.element.element.style
      ..height = '${element.getBoundingClientRect().height - 2}px'
      ..width = '${sourceAreaWidth / 2}px';

    final html.Rectangle r = _sourceArea.element.getBoundingClientRect();

    final int nameHeight = _sourcePathDiv.element.clientHeight;

    int leftPosition = 20; // Default left position.
    final List<html.Node> elems =
        html.document.getElementsByClassName('CodeMirror-gutters');
    if (elems.length == 2) {
      final html.Element firstGutter = elems[0].firstChild as html.Element;
      if (firstGutter.style.display != 'none') {
        // Compute total gutter width (parent has both BP and line # gutters).
        // Offset left a little (5px) so it's not aligned to the gutter's edge
        // (hard to visualize).
        leftPosition = firstGutter.parent.getBoundingClientRect().width + 5;
      }
    }

    // Set the sourcePathDiv text color to the background color (hide filename).
    final String bgColor =
        _sourcePathDiv.element.getComputedStyle().backgroundColor;
    _oldSourceNameTextColor = _sourcePathDiv.element.getComputedStyle().color;

    _sourcePathDiv.element.style.color = bgColor;

    _popupTextfield.element.style
      ..height = '${nameHeight}px'
      ..minHeight = '${nameHeight}px'
      ..maxHeight = '${nameHeight}px'
      ..width = _scriptsView.element.element.style.width
      ..top = '${r.top}px'
      ..left = '${r.left + leftPosition}px'
      ..display = 'inline';

    element.style
      ..top = '${r.top + nameHeight}px'
      ..left = '${r.left + leftPosition}px'
      ..display = 'inline';
  }

  void hidePopup() {
    // Restore the text color to what it was (so the title can be seen).
    _sourcePathDiv.element.style.color = _oldSourceNameTextColor;

    element.style.display = 'none'; // Hide ScriptsView

    // Hide textfield and reset it's value.
    final html.InputElement inputElement = _popupTextfield.element;
    inputElement.value = '';
    inputElement.style.display = 'none';

    _poppedUp = false;
  }

  HtmlScriptsView get scriptsView => _scriptsView;
}

class HtmlScriptsView implements CoreElementView {
  HtmlScriptsView(URIDescriber uriDescriber) {
    _items = HtmlSelectableList<ScriptRef>()
      ..flex()
      ..clazz('debugger-items-list');
    _items.setRenderer((ScriptRef scriptRef) {
      final String uri = scriptRef.uri;
      final String name = uriDescriber(uri);

      // Case insensitive matching.
      final matchingName = name.toLowerCase();

      CoreElement element;
      if (_matcherRendering != null && _matcherRendering.active) {
        // InputElement's need to fetch the value not text/textContent property.
        // The value and text are different, all nodes have a text. It the text
        // content of the node itself along with its descendants. However, input
        // elements have a value property - its the input data of the input
        // element. Input elements may have a text/textContent but it is always
        // empty because they are void elements.
        final html.InputElement inputElement =
            _matcherRendering._textfield.element as html.InputElement;
        // Case insensitive matching.
        final String matchPart = inputElement.value.toLowerCase();

        // Compute the matched characters to be bolded.
        final int startIndex = matchingName.lastIndexOf(matchPart);
        final String firstPart = name.substring(0, startIndex);
        final int endBoldIndex = startIndex + matchPart.length;
        final String boldPart = name.substring(startIndex, endBoldIndex);
        final String endPart = name.substring(endBoldIndex);

        // Construct the HTML with the bold tag and ensure that the HTML
        // constructed is safe from attacks e.g., XSS, etc.
        final String safeElement = html.Element.html(
                '<div>$firstPart<strong class="strong-match">$boldPart</strong>$endPart</div>')
            .innerHtml;
        element = li(html: safeElement, c: 'list-item');
      } else {
        element = li(text: name, c: 'list-item');
      }

      element.tooltip = uri;
      return element;
    });
  }

  HtmlScriptsMatcher _matcherRendering;

  HtmlScriptsMatcher get matcher => _matcherRendering;

  void setMatcher(HtmlScriptsMatcher _matcher) {
    _matcherRendering = _matcher;
  }

  void reset() {
    _highlightRef = null;
  }

  void scrollAndHighlight(
    int row,
    int topPosition, {
    bool top = false,
    bool bottom = false,
  }) {
    // TODO(terry): this fixed a RangeError, but investigate why this method is
    // called when the list is empty.
    if (items.isEmpty) return;

    // Highlight this row.
    _highlightRef = items[row];

    final CoreElement newElement = _items.renderer(_highlightRef);

    _items.setReplace(row, _highlightRef);

    if (topPosition != -1) element.scrollTop = topPosition;

    newElement?.scrollIntoView(top: top, bottom: bottom);
  }

  /// Returns the row number of item to make visible.
  int page(ListDirection direction, [int startRow = 0]) {
    final int listHeight = element.element.clientHeight;
    final int itemHeight = _items.element.children[0].clientHeight;
    final int itemsVis = (listHeight / itemHeight).truncate() - 1;

    int childToScrollTo;
    switch (direction) {
      case ListDirection.pageDown:
        int itemIndex = startRow + itemsVis;
        if (itemIndex > _items.items.length - 1) {
          itemIndex = _items.items.length - 1;
        }
        childToScrollTo = itemIndex;
        final int scrollPosition = startRow > 0 ? startRow * itemHeight : 0;
        scrollAndHighlight(childToScrollTo, scrollPosition, top: true);
        break;
      case ListDirection.pageUp:
        int itemIndex = startRow - itemsVis;
        if (itemIndex < 0) itemIndex = 0;
        childToScrollTo = itemIndex;
        final int scrollPosition =
            childToScrollTo > 0 ? childToScrollTo * itemHeight : 0;
        scrollAndHighlight(childToScrollTo, scrollPosition, top: true);
        break;
      case ListDirection.home:
        childToScrollTo = 0;
        scrollAndHighlight(childToScrollTo, childToScrollTo);
        break;
      case ListDirection.end:
        childToScrollTo = _items.items.length - 1;
        final int scrollPosition =
            childToScrollTo > 0 ? (childToScrollTo - itemsVis) * itemHeight : 0;
        scrollAndHighlight(childToScrollTo, scrollPosition);
        break;
    }

    return childToScrollTo;
  }

  HtmlSelectableList<ScriptRef> _items;
  ScriptRef _highlightRef;

  String rootLib;

  List<ScriptRef> get items => _items.items;

  @override
  CoreElement get element => _items;

  bool get itemsHadClicked => _items.hadClicked;

  Stream<html.KeyboardEvent> get onKeyDown {
    return _items.onKeyDown;
  }

  Stream<ScriptRef> get onSelectionChanged {
    return _items.onSelectionChanged;
  }

  Stream<void> get onScriptsChanged {
    return _items.onItemsChanged;
  }

  void showScripts(
    List<ScriptRef> scripts,
    String rootLib,
    String commonPrefix, {
    bool selectRootScript = false,
    ScriptRef selectScriptRef,
  }) {
    this.rootLib = rootLib;

    scripts.sort((ScriptRef ref1, ScriptRef ref2) {
      String uri1 = ref1.uri;
      String uri2 = ref2.uri;

      uri1 = _convertDartInternalUris(uri1);
      uri2 = _convertDartInternalUris(uri2);

      if (commonPrefix != null) {
        if (uri1.startsWith(commonPrefix) && !uri2.startsWith(commonPrefix)) {
          return -1;
        } else if (!uri1.startsWith(commonPrefix) &&
            uri2.startsWith(commonPrefix)) {
          return 1;
        }
      }

      if (uri1.startsWith('dart:') && !uri2.startsWith('dart:')) {
        return 1;
      } else if (!uri1.startsWith('dart:') && uri2.startsWith('dart:')) {
        return -1;
      }

      return uri1.compareTo(uri2);
    });

    ScriptRef selection;
    if (selectRootScript) {
      selection = scripts.firstWhere((script) => script.uri == rootLib,
          orElse: () => null);
    } else if (selectScriptRef != null) {
      selection = selectScriptRef;
    }

    _items.setItems(scripts,
        selection: selection, scrollSelectionIntoView: true);
  }

  String _convertDartInternalUris(String uri) {
    if (uri.startsWith('dart:_')) {
      return uri.replaceAll('dart:_', 'dart:');
    } else {
      return uri;
    }
  }

  void clearScripts() => _items.clearItems();
}

class HtmlScriptsMatcher {
  HtmlScriptsMatcher(this._debuggerState);

  HtmlScriptsView _scriptsView;
  CoreElement _textfield;
  final DebuggerState _debuggerState;

  ScriptRef _originalScriptRef;
  int _originalScrollTop;

  Map<String, List<ScriptRef>> matchingState = {};

  String _lastMatchingChars;

  String get lastMatchingChars => _lastMatchingChars;

  // Current Row via matching and navigation (up/down ARROW, up/down PAGE, HOME
  // and END.
  int _selectRow = -1;

  StreamSubscription _keyEventSubscription;

  bool get active => _keyEventSubscription != null;

  Function _finishCallback;

  void finish() {
    if (_finishCallback != null) _finishCallback();
  }

  void start(
    ScriptRef revertScriptRef,
    HtmlScriptsView scriptView,
    CoreElement textfield, [
    Function finishCallback,
  ]) {
    _scriptsView = scriptView;
    _textfield = textfield;

    if (finishCallback != null) _finishCallback = finishCallback;

    _startMatching(revertScriptRef, true);

    // Start handling user's keystrokes to show matching list of files.
    _keyEventSubscription ??=
        _textfield.onKeyDown.listen((html.KeyboardEvent e) {
      switch (e.keyCode) {
        case DOM_VK_RETURN:
          reset();
          _scriptsView.reset();
          finish();
          e.preventDefault();
          break;
        case DOM_VK_ESCAPE:
          cancel();
          break;
        case DOM_VK_PAGE_UP:
          _selectRow = _scriptsView.page(ListDirection.pageUp, _selectRow);
          e.preventDefault();
          break;
        case DOM_VK_PAGE_DOWN:
          _selectRow = _scriptsView.page(ListDirection.pageDown, _selectRow);
          e.preventDefault();
          break;
        case DOM_VK_END:
          _selectRow = _scriptsView.page(ListDirection.end);
          e.preventDefault();
          break;
        case DOM_VK_HOME:
          _selectRow = _scriptsView.page(ListDirection.home);
          e.preventDefault();
          break;
        case DOM_VK_UP:
          // Set selection one item up.
          if (_selectRow > 0) {
            _selectRow -= 1;
            _scriptsView.scrollAndHighlight(_selectRow, -1);
          }
          e.preventDefault();
          break;
        case DOM_VK_DOWN:
          // Set selection one item down.
          if (_selectRow < _scriptsView.items.length - 1) {
            _selectRow += 1;
            _scriptsView.scrollAndHighlight(_selectRow, -1);
          }
          e.preventDefault();
          break;
      }
    });
  }

  void cancel() {
    revert();
    finish();
  }

  void updateScripts() {
    matchingState[''] = _scriptsView.items;
  }

  void selectFirstItem() {
    _selectRow = 0;
    _scriptsView.scrollAndHighlight(_selectRow, -1);
  }

  // Finished matching - throw away all matching states.
  void reset() {
    ScriptRef selectedScriptRef;

    if (_scriptsView._items.hadClicked) {
      // Matcher was active but user clicked.  So remember the item clicked on -
      // is the currently selected.
      selectedScriptRef = _scriptsView._items.selectedItem();
    } else {
      // Use the ScriptRef we've highlighted from match navigation.
      selectedScriptRef = _scriptsView._highlightRef;
    }

    if (_keyEventSubscription != null) {
      // No more event routing until user has clicked again in the textfield.
      _keyEventSubscription.cancel();
      _keyEventSubscription = null;
    }

    // Remember the whole set of ScriptRefs
    final List<ScriptRef> originalRefs = matchingState[''];

    _scriptsView.showScripts(
      originalRefs,
      _debuggerState.rootLib.uri,
      _debuggerState.commonScriptPrefix,
      selectScriptRef: selectedScriptRef,
    );

    // Lose all other intermediate matches - we're done.
    matchingState.clear();
    matchingState.putIfAbsent('', () => originalRefs);

    (_textfield.element as html.InputElement).value = '';

    _scriptsView._highlightRef = null;
  }

  int rowPosition(int row) {
    final int itemHeight = _scriptsView._items.element.children[0].clientHeight;
    return row * itemHeight;
  }

  /// Revert list and selection back to before the matcher (first click in the
  /// textfield).
  void revert() {
    reset();

    _scriptsView.showScripts(
      matchingState[''],
      _debuggerState.rootLib.uri,
      _debuggerState.commonScriptPrefix,
      selectScriptRef: _originalScriptRef,
    );

    if (_originalScriptRef != null) {
      if (_scriptsView._items.selectedItem() != null) {
        _scriptsView.element.scrollTop = _originalScrollTop;
      }
    }
  }

  void _startMatching(ScriptRef originalScriptRef, [bool initialize = false]) {
    _originalScriptRef = originalScriptRef;
    _originalScrollTop = _scriptsView.element.scrollTop;

    final html.InputElement element = _textfield.element;
    if (initialize || element.value.isEmpty) {
      // Save all the scripts.
      matchingState.putIfAbsent('', () => _scriptsView.items);
    }
  }

  /// Show the list of files matching the set of keystrokes typed.
  void displayMatchingScripts(String charsToMatch) {
    String previousMatch = '';

    final charsMatchLen = charsToMatch.length;
    if (charsMatchLen > 0) {
      previousMatch = charsToMatch.substring(0, charsMatchLen - 1);
    }

    List<ScriptRef> lastMatchingRefs = matchingState[previousMatch];
    lastMatchingRefs ??= matchingState[''];

    final List<ScriptRef> matchingRefs = lastMatchingRefs
        .where((ScriptRef ref) =>
            _debuggerState
                .getShortScriptName(ref.uri)
                // Case insensitive matching.
                .toLowerCase()
                .lastIndexOf('${charsToMatch.toLowerCase()}') >=
            0)
        .toList();

    matchingState.putIfAbsent(charsToMatch, () => matchingRefs);

    _scriptsView.clearScripts();
    _scriptsView.showScripts(
      matchingRefs,
      _debuggerState.rootLib.uri,
      _debuggerState.commonScriptPrefix,
    );

    selectFirstItem();

    _scriptsView._items.scrollTop = 0;

    _lastMatchingChars = charsToMatch;
  }
}
