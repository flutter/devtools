// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/config_specific/import_export/import_export.dart';
import '../../../../../shared/file_import.dart';
import '../../../../../shared/globals.dart';
import '../../../../../shared/memory/class_name.dart';
import '../../../../../shared/memory/classes.dart';
import '../../../../../shared/memory/heap_graph_loader.dart';
import '../../../../../shared/memory/retaining_path.dart';
import '../../../../../shared/memory/simple_items.dart';
import '../../../shared/heap/class_filter.dart';
import '../../../shared/primitives/memory_utils.dart';
import '../data/classes_diff.dart';
import '../data/csv.dart';
import '../data/heap_diff_data.dart';
import '../data/heap_diff_store.dart';
import 'class_data.dart';
import 'item_controller.dart';

class DiffPaneController extends DisposableController {
  DiffPaneController(this._heapGraphLoader);

  final HeapGraphLoader _heapGraphLoader;

  final retainingPathController = RetainingPathController();

  final core = CoreData();
  late final derived = DerivedData(core);

  /// True, if the list contains snapshots, i.e. items beyond the first
  /// informational item.
  bool get hasSnapshots => core.snapshots.value.length > 1;

  Future<void> takeSnapshot() async {
    ga.select(
      gac.memory,
      gac.MemoryEvent.diffTakeSnapshotControlPane,
    );

    final item = SnapshotDataItem(
      displayNumber: _nextDisplayNumber(),
      defaultName: selectedIsolateName ?? '<isolate-not-detected>',
    );

    await _addSnapshot(_heapGraphLoader, item);
    derived._updateValues();
  }

  /// Imports snapshots from files.
  ///
  /// Opens file selector and loads snapshots from the selected files.
  Future<void> importSnapshots() async {
    ga.select(
      gac.memory,
      gac.importFile,
    );
    final files = await importRawFilesFromPicker();
    if (files.isEmpty) return;

    final importers = files.map((file) async {
      final item = SnapshotDataItem(defaultName: file.name);
      await _addSnapshot(HeapGraphLoaderFile(file), item);
    });
    await Future.wait(importers);
    derived._updateValues();
  }

  Future<void> _addSnapshot(
    HeapGraphLoader loader,
    SnapshotDataItem item,
  ) async {
    final snapshots = core._snapshots;
    snapshots.add(item);

    try {
      await item.loadHeap(loader);
    } catch (e) {
      snapshots.remove(item);
      rethrow;
    } finally {
      final newElementIndex = snapshots.value.length - 1;
      core._selectedSnapshotIndex.value = newElementIndex;
    }
  }

  void clearSnapshots() {
    final snapshots = core._snapshots;
    for (var i = 1; i < snapshots.value.length; i++) {
      snapshots.value[i].dispose();
    }
    snapshots.removeRange(1, snapshots.value.length);
    core._selectedSnapshotIndex.value = 0;
    derived._updateValues();
  }

  int _nextDisplayNumber() {
    final numbers = core._snapshots.value.map((e) => e.displayNumber ?? 0);
    assert(numbers.isNotEmpty);
    return numbers.max + 1;
  }

  void deleteCurrentSnapshot() {
    final item = core.selectedDataItem;
    if (item == null) return;
    item.dispose();

    final index = core.selectedSnapshotIndex.value;
    core._snapshots.removeAt(index);
    // We change the selectedIndex, because:
    // 1. It is convenient UX
    // 2. Without it the content will not be re-rendered.
    core._selectedSnapshotIndex.value = max(index - 1, 0);
    derived._updateValues();
  }

  void setSnapshotIndex(int index) {
    core._selectedSnapshotIndex.value = index;
    derived._updateValues();
  }

  void setDiffing(
    SnapshotDataItem diffItem,
    SnapshotDataItem? withItem,
  ) {
    diffItem.diffWith.value = withItem;
    derived._updateValues();
  }

  void exportCurrentItem() {
    final item = core.selectedDataItem!;

    ExportController().downloadFile(
      item.heap!.graph.toUint8List(),
      fileName: ExportController.generateFileName(
        type: ExportFileType.data,
        prefix: item.name,
      ),
    );
  }

  void downloadCurrentItemToCsv() {
    final classes = derived.classesBeforeFiltering.value!;
    final item = core.selectedDataItem!;
    final diffWith = item.diffWith.value;

    late String filePrefix;
    filePrefix = diffWith == null ? item.name : '${item.name}-${diffWith.name}';

    ExportController().downloadFile(
      classesToCsv(classes.list),
      type: ExportFileType.csv,
      fileName: ExportController.generateFileName(
        type: ExportFileType.csv,
        prefix: filePrefix,
      ),
    );
  }

  Map<String, dynamic> prepareForOffline() {
    return {};
  }
}

/// Values that define what data to show on diff screen.
///
/// Widgets should not update the fields directly, they should use
/// [DiffPaneController] or [DerivedData] for this.
class CoreData {
  late final rootPackage =
      serviceConnection.serviceManager.rootInfoNow().package;

  /// The list contains one item that show information and all others
  /// are snapshots.
  ValueListenable<List<SnapshotItem>> get snapshots => _snapshots;
  final _snapshots = ListValueNotifier(<SnapshotItem>[SnapshotDocItem()]);

  /// Selected snapshot.
  ValueListenable<int> get selectedSnapshotIndex => _selectedSnapshotIndex;
  final _selectedSnapshotIndex = ValueNotifier<int>(0);

  SnapshotItem get selectedItem =>
      _snapshots.value[_selectedSnapshotIndex.value];

  SnapshotDataItem? get selectedDataItem => selectedItem is SnapshotDataItem
      ? selectedItem as SnapshotDataItem
      : null;

  /// Full name for the selected class.
  ///
  /// The name is applied to all snapshots.
  HeapClassName? className;

  /// Selected retaining path.
  ///
  /// The path is applied to all snapshots.
  PathFromRoot? path;

  /// Current class filter.
  ///
  /// This filter is applied to all snapshots.
  ValueListenable<ClassFilter> get classFilter => _classFilter;
  final _classFilter = ValueNotifier(ClassFilter.empty());
}

/// Values that can be calculated from [CoreData] and notifiers that take signal
/// from widgets.
class DerivedData extends DisposableController with AutoDisposeControllerMixin {
  DerivedData(this._core) {
    _selectedItem = ValueNotifier<SnapshotItem>(_core.selectedItem);

    final classFilterData = ClassFilterData(
      filter: _core.classFilter,
      onChanged: applyFilter,
    );

    classesTableSingle = ClassesTableSingleData(
      heap: () => (_core.selectedItem as SnapshotDataItem).heap!,
      filterData: classFilterData,
      totalHeapSize: () => (_core.selectedItem as SnapshotDataItem).totalSize!,
    );

    classesTableDiff = ClassesTableDiffData(
      heapBefore: () => _currentDiff()!.before,
      heapAfter: () => _currentDiff()!.after,
      filterData: classFilterData,
    );

    addAutoDisposeListener(
      classesTableSingle.selection,
      () => _setClassIfNotNull(classesTableSingle.selection.value?.className),
    );
    addAutoDisposeListener(
      classesTableDiff.selection,
      () => _setClassIfNotNull(classesTableDiff.selection.value?.className),
    );
    addAutoDisposeListener(
      selectedPath,
      () => _setPathIfNotNull(selectedPath.value?.path),
    );
  }

  final CoreData _core;

  /// Currently selected item, to take signal from the list widget.
  ValueListenable<SnapshotItem> get selectedItem => _selectedItem;
  late final ValueNotifier<SnapshotItem> _selectedItem;

  /// Classes to show.
  final classesBeforeFiltering = ValueNotifier<ClassDataList?>(null);

  late final ClassesTableSingleData classesTableSingle;

  late final ClassesTableDiffData classesTableDiff;

  /// Classes to show for currently selected item, if the item is not diffed.
  ValueListenable<ClassDataList<SingleClassData>?> get singleClassesToShow =>
      _singleClassesToShow;
  final _singleClassesToShow =
      ValueNotifier<ClassDataList<SingleClassData>?>(null);

  /// Classes to show for currently selected item, if the item is diffed.
  ValueListenable<ClassDataList<DiffClassData>?> get diffClassesToShow =>
      _diffClassesToShow;
  final _diffClassesToShow = ValueNotifier<ClassDataList<DiffClassData>?>(null);

  /// Data to show for the selected class.
  final classData = ValueNotifier<ClassData?>(null);

  /// Selected retaining path record in a concrete snapshot, to take signal from the table widget.
  final selectedPath = ValueNotifier<PathData?>(null);

  /// Storage for already calculated diffs between snapshots.
  final _diffStore = HeapDiffStore();

  void applyFilter(ClassFilter filter) {
    if (filter == _core.classFilter.value) return;
    _core._classFilter.value = filter;
    _updateValues();
  }

  /// Updates cross-snapshot class if the argument is not null.
  void _setClassIfNotNull(HeapClassName? className) {
    if (className == null || className == _core.className) return;
    _core.className = className;
    _updateValues();
  }

  /// Updates cross-snapshot path if the argument is not null.
  void _setPathIfNotNull(PathFromRoot? path) {
    if (path == null || path == _core.path) return;
    _core.path = path;
    _updateValues();
  }

  void _assertIntegrity() {
    assert(() {
      assert(!_updatingValues);

      var singleHidden = true;
      var diffHidden = true;
      var details = 'no data';
      final item = selectedItem.value;
      if (item is SnapshotDataItem && item.hasData) {
        diffHidden = item.diffWith.value == null;
        singleHidden = !diffHidden;
        details = diffHidden ? 'single' : 'diff';
      }

      assert(singleHidden || diffHidden);

      if (singleHidden) {
        assert(classesTableSingle.selection.value == null, details);
      }
      if (diffHidden) {
        assert(classesTableDiff.selection.value == null, details);
      }

      assert((singleClassesToShow.value == null) == singleHidden, details);
      assert((diffClassesToShow.value == null) == diffHidden, details);

      return true;
    }());
  }

  /// Classes for the selected snapshot with diffing applied.
  ClassDataList? _snapshotClassesAfterDiffing() {
    return _currentDiff()?.classes ?? _core.selectedDataItem?.heap?.classes;
  }

  HeapDiffData? _currentDiff() {
    final item = _core.selectedDataItem;
    return _diffStore.compare(item?.heap, item?.diffWith.value?.heap);
  }

  void _updatePathTableData() {
    final data = classData.value;

    final path = _core.path;
    if (data != null && path != null) {
      selectedPath.value = PathData(data, path);
    } else {
      selectedPath.value = null;
    }
  }

  void _updateClassTableData({
    required ClassDataList? classes,
    required HeapClassName? selectedClassName,
  }) {
    if (classes is ClassDataList<SingleClassData>) {
      _singleClassesToShow.value = classes;
      _diffClassesToShow.value = null;
      classesTableSingle.selection.value = classes.list
          .singleWhereOrNull((d) => d.className == selectedClassName);
      classesTableDiff.selection.value = null;
      classData.value = classesTableSingle.selection.value;
    } else if (classes is ClassDataList<DiffClassData>) {
      _singleClassesToShow.value = null;
      _diffClassesToShow.value = classes;
      classesTableSingle.selection.value = null;
      classesTableDiff.selection.value = classes.list
          .singleWhereOrNull((d) => d.className == selectedClassName);
      classData.value = classesTableDiff.selection.value;
    } else if (classes == null) {
      _singleClassesToShow.value = null;
      _diffClassesToShow.value = null;
      classesTableSingle.selection.value = null;
      classesTableDiff.selection.value = null;
      classData.value = null;
    } else {
      throw StateError('Unexpected type: ${classes.runtimeType}.');
    }
  }

  bool get updatingValues => _updatingValues;
  bool _updatingValues = false;

  /// Updates fields in this instance based on the values in [core].
  void _updateValues() {
    _startUpdatingValues();
    try {
      // Set class to show.
      ClassDataList<ClassData>? classes = _snapshotClassesAfterDiffing();
      classesBeforeFiltering.value = classes;

      // Apply filter.
      classes = classes?.filtered(_core.classFilter.value, _core.rootPackage);

      _updateClassAndPathSelection(classes);

      _updateClassTableData(
        classes: classes,
        selectedClassName: _core.className,
      );

      _updatePathTableData();

      _selectedItem.value = _core.selectedItem;
    } finally {
      // Exceptions are caught by UI and gracefully communicated.
      // Returning controller back to consistent state to make error reporting easier,
      // and non-failing operations still working.
      _endUpdatingValues();
    }
  }

  void _startUpdatingValues() {
    // Make sure the method does not trigger itself recursively.
    assert(!_updatingValues);

    ga.timeStart(
      gac.memory,
      gac.MemoryTime.updateValues,
    );

    _updatingValues = true;
  }

  void _endUpdatingValues() {
    _updatingValues = false;

    ga.timeEnd(
      gac.memory,
      gac.MemoryTime.updateValues,
    );

    _assertIntegrity();
  }

  /// Set selection of a class and path.
  void _updateClassAndPathSelection(ClassDataList<ClassData>? filteredClasses) {
    // If there are no classes, do not change previous selection.
    if (filteredClasses == null || filteredClasses.list.isEmpty) return;

    // Try to preserve existing selection.
    ClassData? classData = filteredClasses.byName(_core.className);

    // If the class is not found, select the class with the maximum retained size.
    classData ??= filteredClasses.withMaxRetainedSize();

    _core.className = classData.className;

    if (!classData.contains(_core.path)) {
      _core.path = classData.pathWithMaxRetainedSize;
    }
  }
}
