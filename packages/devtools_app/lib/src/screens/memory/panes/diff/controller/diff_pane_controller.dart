// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../../../primitives/utils.dart';
import '../../../primitives/memory_utils.dart';
import '../../../shared/heap/model.dart';
import 'model.dart';

class DiffPaneController {
  DiffPaneController(this.snapshotTaker);

  final SnapshotTaker snapshotTaker;

  /// The list contains one item that show information and all others
  /// are snapshots.
  ValueListenable<List<DiffListItem>> get snapshots => _snapshots;
  final _snapshots = ListValueNotifier(<DiffListItem>[InformationListItem()]);

  ValueListenable<int> get selectedIndex => _selectedIndex;
  final _selectedIndex = ValueNotifier<int>(0);

  /// If true, some process is going on.
  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  DiffListItem get selected => snapshots.value[selectedIndex.value];

  /// True, if the list contains snapshots, i.e. items beyond the first
  /// informational item.
  bool get hasSnapshots => snapshots.value.length > 1;

  Future<void> takeSnapshot() async {
    _isProcessing.value = true;
    final future = snapshotTaker.take();
    _snapshots.add(
      SnapshotListItem(
        future,
        _nextDisplayNumber(),
        currentIsolateName ?? '<isolate-not-detected>',
      ),
    );
    await future;
    final newElementIndex = snapshots.value.length - 1;
    _selectedIndex.value = newElementIndex;
    _isProcessing.value = false;
  }

  Future<void> clearSnapshots() async {
    _snapshots.removeRange(1, snapshots.value.length);
    _selectedIndex.value = 0;
  }

  int _nextDisplayNumber() {
    final numbers = snapshots.value.map((e) => e.displayNumber);
    assert(numbers.isNotEmpty);
    return numbers.max + 1;
  }

  void deleteCurrentSnapshot() {
    assert(selected is SnapshotListItem);
    _snapshots.removeRange(selectedIndex.value, selectedIndex.value + 1);
    // We must change the selectedIndex, because otherwise the content will
    // not be re-rendered.
    _selectedIndex.value = max(selectedIndex.value - 1, 0);
  }

  void select(int index) {
    _selectedIndex.value = index;
  }
}
