// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../shared/primitives/utils.dart';
import '../../shared/ui/search.dart';
import 'logging_controller.dart';

/// A controller for the log details view that provides search functionality.
class LogDetailsController extends DisposableController
    with SearchControllerMixin<LogDetailsMatch>, AutoDisposeControllerMixin {
  LogDetailsController({required ValueListenable<LogData?> selectedLog}) {
    init();
    addAutoDisposeListener(selectedLog, () {
      _selectedLog = selectedLog.value;
      refreshSearchMatches();
    });
  }

  LogData? _selectedLog;

  @override
  List<LogDetailsMatch> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) {
    if (search.isEmpty || _selectedLog == null) return [];
    final matches = <LogDetailsMatch>[];

    final text = _selectedLog!.prettyPrinted();
    if (text == null) return [];

    final regex = RegExp(search, caseSensitive: false);
    final allMatches = regex.allMatches(text);
    for (final match in allMatches) {
      matches.add(LogDetailsMatch(match.start, match.end));
    }
    return matches;
  }

  @override
  void dispose() {
    _selectedLog = null;
    super.dispose();
  }
}

/// A search match in the log details view.
class LogDetailsMatch with SearchableDataMixin {
  LogDetailsMatch(this.start, this.end);

  final int start;
  final int end;

  Range get range => Range(start, end);

  @override
  bool matchesSearchToken(RegExp regExpSearch) => false;
}
