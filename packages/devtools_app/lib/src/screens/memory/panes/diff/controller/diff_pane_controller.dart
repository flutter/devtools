// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../../../config_specific/import_export/import_export.dart';
import '../../../../../primitives/auto_dispose.dart';
import '../../../../../primitives/utils.dart';
import '../../../primitives/memory_utils.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import 'csv.dart';
import 'heap_diff.dart';
import 'item_controller.dart';

class DiffPaneController extends DisposableController {
  DiffPaneController(this.snapshotTaker);

  final SnapshotTaker snapshotTaker;

  /// If true, some process is going on.
  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  final core = CoreData();
  late final derived = DerivedData(core);

  /// True, if the list contains snapshots, i.e. items beyond the first
  /// informational item.
  bool get hasSnapshots => core.snapshots.value.length > 1;

  // This value should never be reset. It is incremented for every snapshot that
  // is taken, and is used to assign a unique id to each [SnapshotListItem].
  int _snapshotId = 0;

  Future<void> takeSnapshot() async {
    _isProcessing.value = true;
    final future = snapshotTaker.take();
    final snapshots = core._snapshots;

    final item = SnapshotInstanceItem(
      id: _snapshotId++,
      displayNumber: _nextDisplayNumber(),
      isolateName: currentIsolateName ?? '<isolate-not-detected>',
    );

    snapshots.add(item);
    item.setHeapData(await future);

    final newElementIndex = snapshots.value.length - 1;
    core._selectedSnapshotIndex.value = newElementIndex;
    _isProcessing.value = false;
    derived._updateValues();
  }

  Future<void> clearSnapshots() async {
    final snapshots = core._snapshots;
    for (var i = 1; i < snapshots.value.length; i++) {
      snapshots.value[i].dispose();
    }
    snapshots.removeRange(1, snapshots.value.length);
    core._selectedSnapshotIndex.value = 0;
    derived._updateValues();
  }

  int _nextDisplayNumber() {
    final numbers = core._snapshots.value.map((e) => e.displayNumber);
    assert(numbers.isNotEmpty);
    return numbers.max + 1;
  }

  void deleteCurrentSnapshot() {
    final item = core.selectedItem;
    assert(item is SnapshotInstanceItem);
    item.dispose();
    final index = core.selectedSnapshotIndex.value;
    core._snapshots.removeAt(index);
    // We change the selectedIndex, because:
    // 1. It is convenient UX
    // 2. Otherwise the content will not be re-rendered.
    core._selectedSnapshotIndex.value = max(index - 1, 0);
    derived._updateValues();
  }

  void setSnapshotIndex(int index) {
    core._selectedSnapshotIndex.value = index;
    derived._updateValues();
  }

  void setDiffing(
    SnapshotInstanceItem diffItem,
    SnapshotInstanceItem? withItem,
  ) {
    diffItem.diffWith.value = withItem;
    derived._updateValues();
  }

  void setClassFilter(String value) {
    // TODO(polina-c): add implementation
  }

  void downloadCurrentItemToCsv() {
    final classes = derived.heapClasses.value!;
    final item = core.selectedItem as SnapshotInstanceItem;
    final diffWith = item.diffWith.value;

    late String filePrefix;
    if (diffWith == null) {
      filePrefix = item.name;
    } else {
      filePrefix = '${item.name}--${diffWith.name}';
    }

    ExportController().downloadAndNotify(
      classesToCsv(classes),
      type: ExportFileType.csv,
      fileName: ExportController.generateFileName(
        type: ExportFileType.csv,
        prefix: filePrefix,
      ),
    );
  }
}

/// Values that define what data to show on diff screen.
///
/// Widgets should not update the fields directly, they should use
/// [DiffPaneController] or [DerivedData] for this.
class CoreData {
  /// The list contains one item that show information and all others
  /// are snapshots.
  ValueListenable<List<SnapshotItem>> get snapshots => _snapshots;
  final _snapshots = ListValueNotifier(<SnapshotItem>[SnapshotDocItem()]);

  /// Selected snapshot.
  ValueListenable<int> get selectedSnapshotIndex => _selectedSnapshotIndex;
  final _selectedSnapshotIndex = ValueNotifier<int>(0);

  SnapshotItem get selectedItem =>
      _snapshots.value[_selectedSnapshotIndex.value];

  // TODO(https://github.com/flutter/devtools/issues/4539): it is unclear
  // whether preserving the selection between snapshots should be the
  // default behavior. Revisit after consulting with UXR.

  /// Full name for the selected class (cross-snapshot).
  HeapClassName? className;

  /// Selected retaining path (cross-snapshot).
  ClassOnlyHeapPath? path;

  ValueListenable<String?> get classFilter => _classFilter;
  final _classFilter = ValueNotifier<String?>(null);
}

/// Values that can be calculated from [CoreData] and notifiers that take signal
/// from widgets.
class DerivedData extends DisposableController with AutoDisposeControllerMixin {
  DerivedData(this._core) {
    _selectedItem = ValueNotifier<SnapshotItem>(_core.selectedItem);

    addAutoDisposeListener(
      selectedSingleClassStats,
      () => _setClassIfNotNull(selectedSingleClassStats.value?.heapClass),
    );
    addAutoDisposeListener(
      selectedDiffClassStats,
      () => _setClassIfNotNull(selectedDiffClassStats.value?.heapClass),
    );
    addAutoDisposeListener(
      selectedPathEntry,
      () => _setPathIfNotNull(selectedPathEntry.value?.key),
    );
  }

  final CoreData _core;

  /// Currently selected item, to take signal from the list widget.
  ValueListenable<SnapshotItem> get selectedItem => _selectedItem;
  late final ValueNotifier<SnapshotItem> _selectedItem;

  /// Classes to show.
  final heapClasses = ValueNotifier<HeapClasses?>(null);

  /// Selected single class item in snapshot, to take signal from the table widget.
  final selectedSingleClassStats = ValueNotifier<SingleClassStats?>(null);

  /// Selected diff class item in snapshot, to take signal from the table widget.
  final selectedDiffClassStats = ValueNotifier<DiffClassStats?>(null);

  /// List of retaining paths to show for the selected class.
  final pathEntries = ValueNotifier<List<StatsByPathEntry>?>(null);

  /// Selected retaining path record in a concrete snapshot, to take signal from the table widget.
  final selectedPathEntry = ValueNotifier<StatsByPathEntry?>(null);

  /// Storage for already calculated diffs between snapshots.
  final _diffStore = HeapDiffStore();

  /// Updates cross-snapshot class if the argument is not null.
  void _setClassIfNotNull(HeapClassName? theClass) {
    if (theClass == null || theClass == _core.className) return;
    _core.className = theClass;
    _updateValues();
  }

  /// Updates cross-snapshot path if the argument is not null.
  void _setPathIfNotNull(ClassOnlyHeapPath? path) {
    if (path == null || path == _core.path) return;
    _core.path = path;
    _updateValues();
  }

  void _assertIntegrity() {
    assert(() {
      final singleClass = selectedSingleClassStats.value;
      final diffClass = selectedDiffClassStats.value;
      assert(singleClass == null || diffClass == null);
      return true;
    }());
  }

  /// List of classes to show for the selected snapshot.
  HeapClasses? _snapshotClasses() {
    final theItem = _core.selectedItem;
    if (theItem is! SnapshotInstanceItem) return null;
    final heap = theItem.heap;
    if (heap == null) return null;
    final itemToDiffWith = theItem.diffWith.value;
    if (itemToDiffWith == null) return heap.classes;
    return _diffStore.compare(heap, itemToDiffWith.heap!);
  }

  static void _updateClassStats({
    required HeapClasses? classes,
    required HeapClassName? className,
    required ValueNotifier<SingleClassStats?> singleToUpdate,
    required ValueNotifier<DiffClassStats?> diffToUpdate,
  }) {
    if (classes is SingleHeapClasses) {
      singleToUpdate.value = classes.classesByName[className];
      diffToUpdate.value = null;
    } else if (classes is DiffHeapClasses) {
      singleToUpdate.value = null;
      diffToUpdate.value = classes.classesByName[className];
    } else if (classes == null) {
      singleToUpdate.value = null;
      diffToUpdate.value = null;
    } else {
      throw StateError('Unexpected type: ${classes.runtimeType}.');
    }
  }

  /// Updates fields in this instance based on the values in [core].
  void _updateValues() {
    // Set classes to show.
    final classes = _snapshotClasses();
    heapClasses.value = classes;
    _updateClassStats(
      classes: classes,
      className: _core.className,
      singleToUpdate: selectedSingleClassStats,
      diffToUpdate: selectedDiffClassStats,
    );

    // Set paths to show.
    final theClass =
        selectedSingleClassStats.value ?? selectedDiffClassStats.value;
    final thePathEntries = pathEntries.value = theClass?.statsByPathEntries;
    final paths = theClass?.statsByPath;
    StatsByPathEntry? thePathEntry;
    if (_core.path != null && paths != null && thePathEntries != null) {
      final pathStats = paths[_core.path];
      if (pathStats != null) {
        thePathEntry =
            thePathEntries.firstWhereOrNull((e) => e.key == _core.path);
      }
    }
    selectedPathEntry.value = thePathEntry;

    // Set current snapshot.
    _selectedItem.value = _core.selectedItem;

    _assertIntegrity();
  }
}
