// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

typedef Matcher = bool Function(String text);

/// Create a query a text based filter.
///
/// The search terms can be positive terms (the query items must contain the
/// term) or negative terms (the query items must not contain the term).
///
/// The filter text `'foo'` would match all items that contain the word `foo`.
/// `'-bar'` would exclude all items that contain `bar`.
class Filter {
  Filter._(this.items);

  static Filter compile(String text) {
    if (text == null) {
      return Filter._(const []);
    }

    text = text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final terms = text.split(' ');

    return Filter._(terms.where((term) => term != '-').map((term) {
      if (term.startsWith(r'\-')) {
        return FilterItem(term.substring(1));
      } else if (term.startsWith('-')) {
        return FilterItem(term.substring(1), negative: true);
      } else {
        return FilterItem(term);
      }
    }).toList());
  }

  final List<FilterItem> items;

  bool matches(Matcher matcher) {
    for (FilterItem item in items) {
      final match = matcher(item.text);

      if (item.positive && !match) {
        return false;
      } else if (item.negative && match) {
        return false;
      }
    }

    return true;
  }
}

class FilterItem {
  FilterItem(this.text, {this.negative = false});

  final String text;
  final bool negative;

  bool get positive => !negative;
}
