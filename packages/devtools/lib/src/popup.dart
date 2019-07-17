// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

import 'ui/custom.dart';
import 'ui/elements.dart';

/// Overview
/// --------
/// Popup with auto-complete. UI parts visible to the user consists of two parts:
///   1. Textfield (keyboard input)
///   2. Popup list that appears below the textfield
///
/// In DevTools, auto-complete is exposed as search (find) with as a magnifying
/// glass button e.g.,
///
///    ----
///   | O  |
///   |  \ |
///    ----
///
/// Clicking on the search button or using the shortcut key CTRL+f will make the
/// textfield visible and set focus, to it, for keyboard input. Directly below
/// the textfield a popup list will appear displaying all possible values (e.g.,
/// list of all classes in the user's application after a memory snapshot).
///
/// Typing characters, in the textfield, filters the contents of the popup list
/// to only show entries that match the characters typed.  The matching
/// characters are bolded for each entry in the filtered list. Special chars:
///   - page up/down and arrow up/down - navigate up/down the list.
///   - ESC - cancel autocomplete
///   - ENTER - process the selected item in the popup list.
///   - click - process the item clicked on in the popup list.
///
/// Using
/// -----
/// To create an auto-complete you'll need to:
///
///   1. create a textfield e.g.,
///
///         textField = CoreElement('input', classes: 'auto-text')
///
///   2. create a PopupListView to hold your list of items to filter e.g.,
///
///         heapPopupList = PopupListView<String>();
///
///   3. create a PopupAutoCompleteView this class manages the matcher, binding
///      the textfield to the popup list and visibility of the textfield and
///      popup list (calling show or hide) e.g.,
///
///       popupAutoComplete = PopupAutoCompleteView(
///         heapPopupList,    // popuplist used to populate
///         screenDiv,        // container to display popup (parent)
///         vmSearchField,    // textfield
///         _searchForClass,  // Callback when user selects item in autocomplete
///       );
///
///       popupAutoComplete.show();
///
/// Priming the data
/// ----------------
///     if (heapPopupList.isEmpty) {
///       // Only fetch if data has changed.
///       heapPopupList.setList(allItemsKnown());
///     }
///
///     if (!textField.isVisible) {
///       textField.element.style.visibility = 'visible';
///       textField.element.focus();
///
///       popupAutoComplete.show();
///     } else {
///       heapPopup.matcher.finish(false); // Cancel the popup auto-complete
///                                        // finish is _searchForClass callback
///     }
///   }
///
/// Processing popup selection
/// --------------------------
///   // Finish callback from search class selected (auto-complete).
///   void _searchForClass([bool cancel]) {
///     if (cancel) {
///       popupAutoComplete.matcher.reset();
///       heapPopupList.reset();
///     } else {
///       // Highlighted class is the class to select.
///       final String classSelected = heapPopupList.highlightedItem;
///
///       final List<ClassHeapDetailStats> classesData = tableStack.first.data;
///       int row = 0;
///       for (ClassHeapDetailStats stat in classesData) {
///         if (stat.classRef.name == classSelected) {
///           tableStack.first.selectByIndex(row, scrollBehavior: 'auto');
///         }
///         row++;
///       }
///     }
///
///     // Done with the popup.
///     popupAutoComplete.hide();
///   }

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

typedef FinishFunction = void Function([bool cancel]);

// This is the class that has the entire list to display for auto-complete.
class PopupListView<T> implements CoreElementView {
  PopupListView() {
    items = SelectableList<T>()
      ..flex()
      ..clazz('popup-items-list');
    items.setRenderer((T item) {
      // Renderer for the list show matching characters.
      final String name = item.toString();
      CoreElement element;
      if (_popupAutoCompleteView.matcher != null &&
          _popupAutoCompleteView.matcher.active) {
        // InputElement's need to fetch the value not text/textContent property.
        // The value and text are different, all nodes have a text. It the text
        // content of the node itself along with its descendants. However, input
        // elements have a value property - its the input data of the input
        // element. Input elements may have a text/textContent but it is always
        // empty because they are void elements.
        final html.InputElement inputElement = _popupAutoCompleteView
            .matcher.textField.element as html.InputElement;
        final String matchPart = inputElement.value;

        // Compute the matched characters to be bolded.
        final int startIndex = name.lastIndexOf(matchPart);
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

      return element;
    });
  }

  PopupAutoCompleteView _popupAutoCompleteView;

  set setPopupAutoCompleteView(PopupAutoCompleteView pacView) {
    _popupAutoCompleteView = pacView;
  }

  void reset() {
    highlightedItem = null;
  }

  void scrollAndHighlight(
    int row,
    int topPosition, {
    bool top = false,
    bool bottom = false,
  }) {
    // TODO(terry): this fixed a RangeError, but investigate why this method is
    // called when the list is empty.
    if (itemsAsList.isEmpty) return;

    // Highlight this row.
    highlightedItem = itemsAsList[row];

    final CoreElement newElement = items.renderer(highlightedItem);

    items.setReplace(row, highlightedItem);

    if (topPosition != -1) element.scrollTop = topPosition;

    newElement?.scrollIntoView(top: top, bottom: bottom);
  }

  /// Returns the row number of item to make visible.
  int page(ListDirection direction, [int startRow = 0]) {
    final int listHeight = element.element.clientHeight;
    final int itemHeight = items.element.children[0].clientHeight;
    final int itemsVis = (listHeight / itemHeight).truncate() - 1;

    int childToScrollTo;
    switch (direction) {
      case ListDirection.pageDown:
        int itemIndex = startRow + itemsVis;
        if (itemIndex > items.items.length - 1) {
          itemIndex = items.items.length - 1;
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
        childToScrollTo = items.items.length - 1;
        final int scrollPosition =
            childToScrollTo > 0 ? (childToScrollTo - itemsVis) * itemHeight : 0;
        scrollAndHighlight(childToScrollTo, scrollPosition);
        break;
    }

    return childToScrollTo;
  }

  SelectableList<T> items;
  T highlightedItem;

  List<T> get itemsAsList => items.items;

  bool get isEmpty => items.items.isEmpty;

  @override
  CoreElement get element => items;

  bool get itemsHadClicked => items.hadClicked;

  Stream<html.KeyboardEvent> get onKeyDown => items.onKeyDown;

  Stream<T> get onSelectionChanged => items.onSelectionChanged;

  Stream<void> get onScriptsChanged => items.onItemsChanged;

  void setList(
    List<T> theItems, {
    T select,
  }) {
    theItems.sort((T item1, T item2) {
      return item1.toString().compareTo(item2.toString());
    });

    T selection;
    if (select != null) {
      selection = select;
    }

    items.setItems(theItems,
        selection: selection, scrollSelectionIntoView: true);
  }

  void clearList() => items.clearItems();
}

// View manages Input element (popupTextField) / popup list displayed _listView.
// show() displays popup list directly below the Input element (popupTextfield).
class PopupAutoCompleteView extends CoreElement {
  PopupAutoCompleteView(
    this._listView,
    this._containerElement,
    this._popupTextfield,
    this._completeAction,
  ) : super('div', classes: 'popup-view') {
    _initialize();
  }

  // Mimic used when the textField should mimic another field's background-color
  // and color.
  PopupAutoCompleteView.mimic(
    this._listView,
    this._containerElement,
    this._popupTextfield,
    this._completeAction,
    this._elementToMimic,
  ) : super('div', classes: 'popup-view') {
    _initialize();
  }

  void _initialize() {
    // Setup backpointer from PopupListView to PopupAutoCompleteView (to access
    // the AutoCompleteMatcher _matcher that's created here.
    _listView.setPopupAutoCompleteView = this;

    // Hookup listener for selection changes in the popup list (clicking an item
    // in the list).
    _hookupListeners();

    // Hookup focus/blur/keyboard events in the textfield.
    _popupTextfield
      ..focus(() {
        // Activate popup auto-complete.
        _matcher ??= AutoCompleteMatcher();
        if (!matcher.active) {
          matcher.start('', _listView, _popupTextfield, _completeAction);
        }
      })
      ..blur(() {
        Timer(const Duration(milliseconds: 200),
            () => matcher?.finish(true)); // Hide/clear the popup.
      })
      ..onKeyUp.listen((html.KeyboardEvent e) {
        switch (e.keyCode) {
          case DOM_VK_RETURN:
          case DOM_VK_ESCAPE:
          case DOM_VK_PAGE_UP:
          case DOM_VK_PAGE_DOWN:
          case DOM_VK_END:
          case DOM_VK_HOME:
          case DOM_VK_UP:
          case DOM_VK_DOWN:
            return;
          default:
            if (e.ctrlKey || e.key == 'Control') {
              // CTRL key is down (a shortcut key) - this isn't for the matcher.
              e.preventDefault();
            } else {
              final html.InputElement inputElement = _popupTextfield.element;
              final String value = inputElement.value.trim();
              matcher.displayMatchingItems(value);
            }
        }
      });
  }

  // View of all items to display during auto-complete, this list will be pruned
  // during auto-complete matching.
  final PopupListView _listView;

  // Container to display input element that accepts keyboard input during auto-
  // complete and the _listView (popup) is displayed in this container too.
  final CoreElement
      _containerElement; // Top div area container of _sourcePathDiv

  // When creating or making visible the input element use this element to mimic
  // the auto-complete input element background color and text color.
  CoreElement _elementToMimic;

  // Input element field to display while popup is active for keyboard input and
  // _listView navigation (page up/down, arrow up/down, escape, etc.)
  final CoreElement _popupTextfield;

  // This is where all the incremental filter is done.
  AutoCompleteMatcher get matcher => _matcher;
  AutoCompleteMatcher _matcher;

  // Callback to user code to process an item selected (click or ENTER to
  // process the selected item).
  final FinishFunction _completeAction;

  CoreElement get popupTextfield => _popupTextfield;

  bool get isPoppedUp => _poppedUp;
  bool _poppedUp = false;

  /// Handle explicit clicking in the popupList.
  void _hookupListeners() {
    _listView.onSelectionChanged.listen((classSelected) async {
      if (_listView.itemsHadClicked && matcher != null && matcher.active) {
        // User clicked in the list while matcher was active.
        if (_listView.itemsHadClicked) {
          _listView.highlightedItem = classSelected;
          matcher?.finish(false);
        }

        matcher.reset();
      }
    });
  }

  void show() {
    _poppedUp = true;

    add(_listView);

    _matcher.selectFirstItem();

    final html.Rectangle r = _containerElement.element.getBoundingClientRect();

    int nameHeight;
    if (_elementToMimic == null) {
      nameHeight =
          _popupTextfield.element.getBoundingClientRect().height.round();
    } else {
      nameHeight =
          _elementToMimic.element.getBoundingClientRect().height.round();
    }

    final textFieldClientRect = _popupTextfield.element.getBoundingClientRect();
    final leftPosition = (textFieldClientRect.left).round();
    element.style
      ..top = '${r.top + nameHeight}px'
      ..left = '${leftPosition}px'
      ..display = 'inline';

    matcher.displayMatchingItems('');
  }

  void hide() {
    element.style.display = 'none'; // Hide PopupView

    // Hide textField and reset it's value.
    final html.InputElement inputElement = _popupTextfield.element;
    inputElement.value = '';
    inputElement.style.visibility = 'hidden';

    _poppedUp = false;
  }

  PopupListView get listView => _listView;
}

/// This class handles all the incremental matching as keys are types as well as
/// navigation through the popup list e.g., pageUp, arrow up/down, etc.
class AutoCompleteMatcher<T> {
  AutoCompleteMatcher();

  PopupListView get listView => _listView;
  PopupListView _listView;

  CoreElement get textField => _textField;
  CoreElement _textField; // Input element for keyboard input.

  T _original;

  int _originalScrollTop;

  Map<String, List<T>> matchingState = {};

  String _lastMatchingChars;

  String get lastMatchingChars => _lastMatchingChars;

  // Current Row via matching and navigation (up/down ARROW, up/down PAGE, HOME
  // and END.
  int _selectRow = -1;

  StreamSubscription _subscription;

  bool get active => _subscription != null;

  FinishFunction _finishCallback;

  void finish([bool cancel = false]) {
    if (_finishCallback != null) _finishCallback(cancel);
  }

  void start(T revert, PopupListView<T> listView, CoreElement textfield,
      [FinishFunction finishCallback]) {
    _listView = listView;
    _textField = textfield;

    if (finishCallback != null) _finishCallback = finishCallback;

    _startMatching(revert, true);

    // Start handling user's keystrokes to show matching list of files.
    _subscription ??= _textField.onKeyDown.listen((html.KeyboardEvent e) {
      bool preventDefault = true;
      switch (e.keyCode) {
        case DOM_VK_RETURN:
          finish();
          reset();
          _listView.reset();
          break;
        case DOM_VK_ESCAPE:
          cancel();
          preventDefault = false;
          break;
        case DOM_VK_PAGE_UP:
          _selectRow = _listView.page(ListDirection.pageUp, _selectRow);
          break;
        case DOM_VK_PAGE_DOWN:
          _selectRow = _listView.page(ListDirection.pageDown, _selectRow);
          break;
        case DOM_VK_END:
          _selectRow = _listView.page(ListDirection.end);
          break;
        case DOM_VK_HOME:
          _selectRow = _listView.page(ListDirection.home);
          break;
        case DOM_VK_UP:
          // Set selection one item up.
          if (_selectRow > 0) {
            _selectRow -= 1;
            _listView.scrollAndHighlight(_selectRow, -1);
          }
          break;
        case DOM_VK_DOWN:
          // Set selection one item down.
          if (_selectRow < listView.itemsAsList.length - 1) {
            _selectRow += 1;
            _listView.scrollAndHighlight(_selectRow, -1);
          }
          break;
        default:
          // All other keys do normal processing.
          preventDefault = false;
      }
      if (preventDefault) e.preventDefault();
    });
  }

  void cancel() {
    revert();
    finish();
  }

  void selectFirstItem() {
    _selectRow = 0;
    _listView.scrollAndHighlight(_selectRow, -1);
  }

  // Finished matching - throw away all matching states.
  void reset() {
    String selected;

    if (listView.items.hadClicked) {
      // Matcher was active but user clicked.  So remember the item clicked on -
      // is the currently selected.
      selected = listView.items.selectedItem();
    } else {
      // Use the item we've highlighted from match navigation.
      selected = listView.highlightedItem;
    }

    if (_subscription != null) {
      // No more event routing until user has clicked again the the textField.
      _subscription.cancel();
      _subscription = null;
    }

    // Remember the whole set of items
    final List<T> originals = matchingState[''];

    _listView.setList(
      originals,
      select: selected,
    );

    // Lose all other intermediate matches - we're done.
    matchingState.clear();
    matchingState.putIfAbsent('', () => originals);

    (_textField.element as html.InputElement).value = '';

    listView.highlightedItem = null;

    _selectRow = -1;
  }

  int rowPosition(int row) {
    final int itemHeight = listView.items.element.children[0].clientHeight;
    return row * itemHeight;
  }

  /// Revert list and selection back to before the matcher (first click in the
  /// textField).
  void revert() {
    reset();
    _listView.setList(
      matchingState[''],
      select: _original,
    );

    if (_original != null) {
      if (listView.items.selectedItem() != null) {
        listView.element.scrollTop = _originalScrollTop;
      }
    }
  }

  void _startMatching(T original, [bool initialize = false]) {
    _original = original;
    _originalScrollTop = _listView.element.scrollTop;

    final html.InputElement element = _textField.element;
    if (initialize || element.value.isEmpty) {
      // Save all the scripts.
      matchingState.putIfAbsent('', () => listView.itemsAsList);
    }
  }

  /// Show the list of files matching the set of keystrokes typed.
  void displayMatchingItems(String charsToMatch) {
    String previousMatch = '';

    final charsMatchLen = charsToMatch.length;
    if (charsMatchLen > 0) {
      previousMatch = charsToMatch.substring(0, charsMatchLen - 1);
    }

    List<T> lastMatchingItems = matchingState[previousMatch];
    lastMatchingItems ??= matchingState[''];

    final List<T> matchingItems = lastMatchingItems
        .where((T item) => item.toString().lastIndexOf('$charsToMatch') >= 0)
        .toList();

    matchingState.putIfAbsent(charsToMatch, () => matchingItems);

    listView.clearList();
    listView.setList(matchingItems);

    selectFirstItem();

    listView.items.scrollTop = 0;

    _lastMatchingChars = charsToMatch;
  }
}
