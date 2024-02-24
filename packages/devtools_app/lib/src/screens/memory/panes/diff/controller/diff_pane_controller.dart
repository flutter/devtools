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
import '../../../../../shared/memory/new/heap_graph_loader.dart';
import '../../../shared/heap/class_filter.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import '../../../shared/primitives/memory_utils.dart';
import 'class_data.dart';
import 'heap_diff.dart';
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

    final item = SnapshotGraphItem(
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
    SnapshotGraphItem item,
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
    assert(item is SnapshotInstanceItem);
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
    SnapshotGraphItem diffItem,
    SnapshotGraphItem? withItem,
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
    final classes = derived.heapClasses.value!;
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

  /// Full name for the selected class (cross-snapshot).
  HeapClassName? className;

  /// Selected retaining path (cross-snapshot).
  ClassOnlyHeapPath? path;

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
      heap: () => (_core.selectedItem as SnapshotInstanceItem).heap_!.data,
      totalHeapSize: () =>
          (_core.selectedItem as SnapshotInstanceItem).totalSize!,
      filterData: classFilterData,
    );

    classesTableDiff = ClassesTableDiffData(
      filterData: classFilterData,
      before: () => (heapClasses.value as DiffHeapClasses).before,
      after: () => (heapClasses.value as DiffHeapClasses).after,
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
      selectedPathEntry,
      () => _setPathIfNotNull(selectedPathEntry.value?.key),
    );
  }

  final CoreData _core;

  /// Currently selected item, to take signal from the list widget.
  ValueListenable<SnapshotItem> get selectedItem => _selectedItem;
  late final ValueNotifier<SnapshotItem> _selectedItem;

  /// Classes to show.
  final heapClasses = ValueNotifier<HeapClasses_?>(null);

  late final ClassesTableSingleData classesTableSingle;

  late final ClassesTableDiffData classesTableDiff;

  /// Classes to show for currently selected item, if the item is diffed.
  ValueListenable<List<DiffClassStats>?> get diffClassesToShow =>
      _diffClassesToShow;
  final _diffClassesToShow = ValueNotifier<List<DiffClassStats>?>(null);

  /// Classes to show for currently selected item, if the item is not diffed.
  ValueListenable<List<SingleClassStats_>?> get singleClassesToShow =>
      _singleClassesToShow;
  final _singleClassesToShow = ValueNotifier<List<SingleClassStats_>?>(null);

  /// List of retaining paths to show for the selected class.
  final pathEntries = ValueNotifier<List<StatsByPathEntry>?>(null);

  /// Selected retaining path record in a concrete snapshot, to take signal from the table widget.
  final selectedPathEntry = ValueNotifier<StatsByPathEntry?>(null);

  /// Storage for already calculated diffs between snapshots.
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
  void _setPathIfNotNull(ClassOnlyHeapPath? path) {
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
  HeapClasses_? _snapshotClassesAfterDiffing() {
    final theItem = _core.selectedItem;

    if (theItem is SnapshotInstanceItem) {
      final heap = theItem.heap_;
      if (heap == null) return null;
      final itemToDiffWith = theItem.diffWith.value;
      if (itemToDiffWith == null) return heap.classes;
      return _diffStore.compare_(heap, itemToDiffWith.heap_!);
    }

    if (theItem is SnapshotGraphItem) {
      final heap = theItem.heap;
      if (heap == null) return null;
      final itemToDiffWith = theItem.diffWith.value;
      if (itemToDiffWith == null) return heap.classes;
      return _diffStore.compare(heap, itemToDiffWith.heap!);
    }

    return null;
  }

  void _updateClasses({
    required HeapClasses_? classes,
    required HeapClassName? className,
  }) {
    final filter = _core.classFilter.value;
    if (classes is SingleHeapClasses) {
      _singleClassesToShow.value = classes.filtered(filter, _core.rootPackage);
      _diffClassesToShow.value = null;
      classesTableSingle.selection.value =
          _filter(classes.classesByName[className]);
      classesTableDiff.selection.value = null;
    } else if (classes is DiffHeapClasses) {
      _singleClassesToShow.value = null;
      _diffClassesToShow.value = classes.filtered(filter, _core.rootPackage);
      classesTableSingle.selection.value = null;
      classesTableDiff.selection.value =
          _filter(classes.classesByName[className]);
    } else if (classes == null) {
      _singleClassesToShow.value = null;
      _diffClassesToShow.value = null;
      classesTableSingle.selection.value = null;
      classesTableDiff.selection.value = null;
    } else {
      throw StateError('Unexpected type: ${classes.runtimeType}.');
    }
  }

  /// Returns [classStats] if it matches the current filter.
  T? _filter<T extends ClassStats_>(T? classStats) {
    if (classStats == null) return null;
    if (_core.classFilter.value.apply(
      classStats.heapClass,
      _core.rootPackage,
    )) {
      return classStats;
    }
    return null;
  }

  bool get updatingValues => _updatingValues;
  bool _updatingValues = false;

  /// Updates fields in this instance based on the values in [core].
  void _updateValues() {
    _startUpdatingValues();

    // Set class to show.
    final classes = _snapshotClassesAfterDiffing();
    heapClasses.value = classes;
    _selectClassAndPath();
    _updateClasses(
      classes: classes,
      className: _core.className,
    );
    // Set paths to show.
    final theClass =
        classesTableSingle.selection.value ?? classesTableDiff.selection.value;
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
    _endUpdatingValues();
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

    SingleClassStats_ singleWithMaxRetainedSize(
      SingleClassStats_ a,
      SingleClassStats_ b,
    ) =>
        a.objects.retainedSize > b.objects.retainedSize ? a : b;

    DiffClassStats diffWithMaxRetainedSize(
      DiffClassStats a,
      DiffClassStats b,
    ) =>
        a.total.delta.retainedSize > b.total.delta.retainedSize ? a : b;

    // Get class with max retained size.
    final ClassStats_ theClass;
    if (classes is SingleHeapClasses) {
      final classStatsList = classes.filtered(
        _core.classFilter.value,
        _core.rootPackage,
      );

      if (classStatsList.isEmpty) return;
      theClass = classStatsList.reduce(singleWithMaxRetainedSize);
    } else if (classes is DiffHeapClasses) {
      final classStatsList = classes.filtered(
        _core.classFilter.value,
        _core.rootPackage,
      );

      if (classStatsList.isEmpty) return;
      theClass = classStatsList.reduce(diffWithMaxRetainedSize);
    } else {
      throw StateError('Unexpected type ${classes.runtimeType}');
    }
    _core.className = theClass.heapClass;

    assert(theClass.statsByPathEntries.isNotEmpty);

    // Get path with max retained size.
    final path = theClass.statsByPathEntries.reduce((v, e) {
      if (v.value.retainedSize > e.value.retainedSize) return v;
      return e;
    });
    _core.path = path.key;
  }
}
