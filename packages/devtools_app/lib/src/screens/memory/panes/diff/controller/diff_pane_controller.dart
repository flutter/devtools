// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../primitives/utils.dart';
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/split.dart';
import '../../../../../shared/table.dart';
import '../../../../../shared/theme.dart';
import '../../../primitives/memory_utils.dart';
import 'model.dart';

class DiffPaneController {
  final scrollController = ScrollController();

  /// The list contains one item that show information and all others
  /// are snapshots.
  final snapshots = ListValueNotifier(<DiffListItem>[InformationListItem()]);

  final selectedIndex = ValueNotifier<int>(0);

  /// If true, some process is going on.
  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  DiffListItem get selected => snapshots.value[selectedIndex.value];

  /// True, if the list contains snapshots, i.e. items beyond the first
  /// informational item.
  bool get hasSnapshots => snapshots.value.length > 1;

  Future<void> takeSnapshot() async {
    _isProcessing.value = true;
    final future = snapshotMemory();
    snapshots.add(
      SnapshotListItem(
        future,
        _nextDisplayNumber(),
        currentIsolateName ?? '<isolate-not-detected>',
      ),
    );
    await future;
    final newElementIndex = snapshots.value.length - 1;
    scrollController.autoScrollToBottom();
    selectedIndex.value = newElementIndex;
    _isProcessing.value = false;
  }

  Future<void> clearSnapshots() async {
    snapshots.removeRange(1, snapshots.value.length);
    selectedIndex.value = 0;
  }

  int _nextDisplayNumber() {
    final numbers = snapshots.value.map((e) => e.displayNumber);
    assert(numbers.isNotEmpty);
    return numbers.max + 1;
  }

  void deleteCurrentSnapshot() {
    assert(selected is SnapshotListItem);
    snapshots.removeRange(selectedIndex.value, selectedIndex.value + 1);
    selectedIndex.value = selectedIndex.value - 1;
  }
}
