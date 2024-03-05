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
import '../../../../../shared/memory/new/classes.dart';
import '../../../../../shared/memory/new/heap_diff_data.dart';
import '../../../../../shared/memory/new/heap_graph_loader.dart';
import '../../../../../shared/memory/new/retaining_path.dart';
import '../../../shared/heap/class_filter.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import '../../../shared/primitives/memory_utils.dart';
import '../widgets/class_details/paths.dart';
import 'class_data.dart';
import 'heap_diff.dart';
import 'heap_diff_.dart';
import 'item_controller.dart';
import 'utils.dart';

class DiffPaneController extends DisposableController {
  DiffPaneController(
    SnapshotTaker snapshotTaker, {
    HeapGraphLoader heapGraphLoader = const HeapGraphLoaderMock(),
  }) : _heapGraphLoader = heapGraphLoader;

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
      final item = SnapshotInstanceItem(defaultName: file.name);
      await _addSnapshot_(SnapshotTakerFromFile(file), item);
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

  Future<void> _addSnapshot_(
    SnapshotTaker snapshotTaker,
    SnapshotInstanceItem item,
  ) async {
    final snapshots = core._snapshots;
    snapshots.add(item);

    try {
      final heapData = await snapshotTaker.take();
      await item.initializeHeapData(heapData);
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
    deleteSnapshot(core.selectedItem);
  }

  void deleteSnapshot(SnapshotItem item) {
    assert(item is SnapshotDataItem);
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

  void setDiffing_(
    SnapshotInstanceItem diffItem,
    SnapshotInstanceItem? withItem,
  ) {
    diffItem.diffWith.value = withItem;
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
    final item = core.selectedItem as SnapshotInstanceItem;
    ExportController().downloadFile(
      'hello',
      fileName: ExportController.generateFileName(
        type: ExportFileType.json,
        prefix: item.name,
      ),
    );
  }

  void downloadCurrentItemToCsv() {
    final classes = derived.heapClasses_.value!;
    final item = core.selectedItem as SnapshotInstanceItem;
    final diffWith = item.diffWith.value;

    late String filePrefix;
    filePrefix = diffWith == null ? item.name : '${item.name}-${diffWith.name}';

    ExportController().downloadFile(
      classesToCsv(classes.classStatsList),
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

  SnapshotDataItem? get selectedDataItem {
    final theItem = selectedItem;
    if (theItem is SnapshotDataItem) return theItem;
    return null;
  }

  /// Full name for the selected class (cross-snapshot).
  HeapClassName? className;

  /// Selected retaining path (cross-snapshot).
  ClassOnlyHeapPath? path_;

  /// Selected retaining path (cross-snapshot).
  PathFromRoot? path;

  /// Current class filter.
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
      () => _setClassIfNotNull(classesTableSingle.selection.value?.heapClass),
    );
    addAutoDisposeListener(
      classesTableDiff.selection,
      () => _setClassIfNotNull(classesTableDiff.selection.value?.heapClass),
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
  final heapClasses_ = ValueNotifier<HeapClasses_?>(null);
  final heapClasses = ValueNotifier<ClassDataList?>(null);

  late final ClassesTableSingleData classesTableSingle;

  late final ClassesTableDiffData classesTableDiff;

  ValueListenable<ClassDataList<DiffClassData>?> get diffClassesToShow =>
      _diffClassesToShow;
  final _diffClassesToShow = ValueNotifier<ClassDataList<DiffClassData>?>(null);

  /// Classes to show for currently selected item, if the item is not diffed.
  ValueListenable<ClassDataList<SingleClassData>?> get singleClassesToShow =>
      _singleClassesToShow;
  final _singleClassesToShow =
      ValueNotifier<ClassDataList<SingleClassData>?>(null);

  /// Data to show for the selected class.
  final classData = ValueNotifier<ClassData?>(null);

  /// Selected retaining path record in a concrete snapshot, to take signal from the table widget.
  final selectedPath = ValueNotifier<PathData?>(null);

  /// Storage for already calculated diffs between snapshots.
  late final _diffStore_ = HeapDiffStore_();
  late final _diffStore = HeapDiffStore();

  void applyFilter(ClassFilter filter) {
    if (filter.equals(_core.classFilter.value)) return;
    _core._classFilter.value = filter;
    _updateValues();
  }

  /// Updates cross-snapshot class if the argument is not null.
  void _setClassIfNotNull(HeapClassName? theClass) {
    if (theClass == null || theClass == _core.className) return;
    _core.className = theClass;
    _updateValues();
  }

  /// Updates cross-snapshot path if the argument is not null.
  void _setPathIfNotNull_(ClassOnlyHeapPath? path) {
    if (path == null || path == _core.path_) return;
    _core.path_ = path;
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
      // assert(!_updatingValues);

      // var singleHidden = true;
      // var diffHidden = true;
      // var details = 'no data';
      // final item = selectedItem.value;
      // if (item is SnapshotInstanceItem && item.hasData) {
      //   diffHidden = item.diffWith.value == null;
      //   singleHidden = !diffHidden;
      //   details = diffHidden ? 'single' : 'diff';
      // }
      // if (item is SnapshotGraphItem && item.hasData) {
      //   diffHidden = item.diffWith.value == null;
      //   singleHidden = !diffHidden;
      //   details = diffHidden ? 'single' : 'diff';
      // }

      // assert(singleHidden || diffHidden);

      // if (singleHidden) {
      //   assert(classesTableSingle.selection.value == null, details);
      // }
      // if (diffHidden) assert(classesTableDiff.selection.value == null, details);

      // assert((singleClassesToShow.value == null) == singleHidden, details);
      // assert((diffClassesToShow.value == null) == diffHidden, details);

      return true;
    }());
  }

  /// Classes for the selected snapshot with diffing applied.
  ClassDataList? _snapshotClassesAfterDiffing() {
    return _currentDiff()?.classes ?? _core.selectedDataItem?.heap?.classes;
  }

  HeapDiffData? _currentDiff() {
    final theItem = _core.selectedDataItem;
    final itemToDiffWith = theItem?.diffWith.value;
    return _diffStore.compare(theItem?.heap, itemToDiffWith?.heap);
  }

  void _updateClasses({
    required ClassDataList? classes,
    required HeapClassName? className,
  }) {
    if (classes != null) {
      final filter = _core.classFilter.value;
      classes = classes.filtered(filter, _core.rootPackage);
    }

    if (classes is ClassDataList<SingleClassData>) {
      _singleClassesToShow.value = classes;
      _diffClassesToShow.value = null;
      classesTableSingle.selection.value =
          classes.list.singleWhereOrNull((d) => d.heapClass == className);
      classesTableDiff.selection.value = null;
      classData.value = classesTableSingle.selection.value;
    } else if (classes is ClassDataList<DiffClassData>) {
      _singleClassesToShow.value = null;
      _diffClassesToShow.value = classes;
      classesTableSingle.selection.value = null;
      classesTableDiff.selection.value =
          classes.list.singleWhereOrNull((d) => d.heapClass == className);
    } else if (classes == null) {
      _singleClassesToShow.value = null;
      _diffClassesToShow.value = null;
      classesTableSingle.selection.value = null;
      classesTableDiff.selection.value = null;
    } else {
      throw StateError('Unexpected type: ${classes.runtimeType}.');
    }
  }

  // /// Returns [classStats] if it matches the current filter.
  // T? _filter<T extends ClassStats_>(T? classStats) {
  //   if (classStats == null) return null;
  //   if (_core.classFilter.value.apply(
  //     classStats.heapClass,
  //     _core.rootPackage,
  //   )) {
  //     return classStats;
  //   }
  //   return null;
  // }

  bool get updatingValues => _updatingValues;
  bool _updatingValues = false;

  /// Updates fields in this instance based on the values in [core].
  void _updateValues() {
    _startUpdatingValues();
    try {
      // Set class to show.
      final classes = _snapshotClassesAfterDiffing();
      heapClasses.value = classes;
      _selectClassAndPath();
      _updateClasses(
        classes: classes,
        className: _core.className,
      );

      final theClassData = classData.value;
      final thePath = _core.path;
      if (theClassData != null && thePath != null) {
        selectedPath.value = PathData(theClassData, thePath);
      } else {
        selectedPath.value = null;
      }

      // Set current snapshot.
      _selectedItem.value = _core.selectedItem;
    } finally {
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

  /// Set initial selection of class and path, for discoverability of detailed view.
  void _selectClassAndPath() {
    if (_core.className != null) return;
    assert(_core.path == null);

    final classes = heapClasses.value;
    if (classes == null) return;

    final theClass = classes.withMaxRetainedSize;

    _core.className = theClass.heapClass;
    _core.path = theClass.pathWithMaxRetainedSize;
  }
}
