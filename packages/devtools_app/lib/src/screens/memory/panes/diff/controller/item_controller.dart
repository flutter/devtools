// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../config_specific/import_export/import_export.dart';
import '../../../../../primitives/auto_dispose.dart';
import '../../../../../shared/globals.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import 'heap_diff.dart';

abstract class DiffListItem extends DisposableController {
  /// Number, that if shown in name, should be unique in the list.
  ///
  /// If the number is not expected to be shown in UI, it should be 0.
  int get displayNumber;

  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  /// If true, the item contains data, that can be compared and analyzed.
  bool get hasData;
}

class InformationListItem extends DiffListItem {
  @override
  int get displayNumber => 0;

  @override
  bool get hasData => false;
}

class SnapshotListItem extends DiffListItem with AutoDisposeControllerMixin {
  SnapshotListItem(
    Future<AdaptedHeapData?> receiver,
    this.displayNumber,
    this._isolateName,
    this.diffStore,
    this.selectedClassName,
  ) {
    _isProcessing.value = true;
    receiver.whenComplete(() async {
      final data = await receiver;
      if (data != null) {
        heap = AdaptedHeap(data);
        updateSelectedRecord();
        addAutoDisposeListener(selectedClassName, () => updateSelectedRecord());
      }
      _isProcessing.value = false;
    });
  }

  final String _isolateName;

  final HeapDiffStore diffStore;

  AdaptedHeap? heap;

  @override
  final int displayNumber;

  String get name => '$_isolateName-$displayNumber';

  ValueListenable<SnapshotListItem?> get diffWith => _diffWith;
  final _diffWith = ValueNotifier<SnapshotListItem?>(null);
  void setDiffWith(SnapshotListItem? value) {
    _diffWith.value = value;
    updateSelectedRecord();
  }

  final ValueListenable<String?> selectedClassName;

  ValueListenable<HeapClassStatistics?> get selectedClassStats =>
      _selectedClassStats;
  final _selectedClassStats = ValueNotifier<HeapClassStatistics?>(null);

  @override
  bool get hasData => heap != null;

  HeapStatistics get statsToShow {
    final theHeap = heap!;
    final itemToDiffWith = diffWith.value;
    if (itemToDiffWith == null) return theHeap.stats;
    return diffStore.compare(theHeap, itemToDiffWith.heap!).stats;
  }

  void updateSelectedRecord() => _selectedClassStats.value =
      statsToShow.statsByClassName[selectedClassName.value];

  void downloadToCsv() {
    final data = statsToShow;
    final csvBuffer = StringBuffer();

    // Write the headers first.
    csvBuffer.writeln(
      [
        'Class',
        'Library',
        'Instances',
        'Shallow Dart Size',
        'Retained Dart Size',
        'Short Retaining Path',
        'Full Retaining Path',
      ].map((e) => '"$e"').join(','),
    );

    // Write a row per retaining path.
    for (var classStats in data.classStats) {
      for (var pathStats in classStats.sizeByPath.entries) {
        csvBuffer.writeln(
          [
            classStats.heapClass.className,
            classStats.heapClass.library,
            pathStats.value.instanceCount,
            pathStats.value.shallowSize,
            pathStats.value.retainedSize,
            pathStats.key.asShortString(),
            pathStats.key.asLongString().replaceAll('\n', ' | '),
          ].join(','),
        );
      }
    }

    final file = ExportController().downloadFile(
      csvBuffer.toString(),
      type: ExportFileType.csv,
    );

    notificationService.push(successfulExportMessage(file));
  }
}
