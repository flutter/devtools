// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../config_specific/import_export/import_export.dart';
import '../../../../../primitives/auto_dispose.dart';
import '../../../../../shared/globals.dart';
import '../../../shared/heap/heap.dart';
import '../../../shared/heap/model.dart';
import 'heap_diff.dart';

abstract class SnapshotItem extends DisposableController {
  /// Number, that if shown in name, should be unique in the list.
  ///
  /// If the number is not expected to be shown in UI, it should be 0.
  int get displayNumber;

  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  /// If true, the item contains data, that can be compared and analyzed.
  bool get hasData;
}

class SnapshotDocItem extends SnapshotItem {
  @override
  int get displayNumber => 0;

  @override
  bool get hasData => false;
}

class SnapshotInstanceItem extends SnapshotItem
    with AutoDisposeControllerMixin {
  SnapshotInstanceItem(
    Future<AdaptedHeapData?> receiver,
    this.displayNumber,
    this._isolateName,
    this._diffStore,
    this._selectedClassName,
  ) {
    _isProcessing.value = true;
    receiver.whenComplete(() async {
      final data = await receiver;
      if (data != null) {
        heap = AdaptedHeap(data);
        _updateSelectedClass();
        addAutoDisposeListener(
          _selectedClassName,
          () => _updateSelectedClass(),
        );
      }
      _isProcessing.value = false;
    });
  }

  final String _isolateName;

  final HeapDiffStore _diffStore;

  AdaptedHeap? heap;

  @override
  final int displayNumber;

  String get name => '$_isolateName-$displayNumber';

  ValueListenable<SnapshotInstanceItem?> get diffWith => _diffWith;
  final _diffWith = ValueNotifier<SnapshotInstanceItem?>(null);
  void setDiffWith(SnapshotInstanceItem? value) {
    _diffWith.value = value;
    _updateSelectedClass();
  }

  final ValueListenable<HeapClassName?> _selectedClassName;

  ValueListenable<SingleHeapClass?> get selectedSingleHeapClass =>
      _selectedSingleHeapClass;
  final _selectedSingleHeapClass = ValueNotifier<SingleHeapClass?>(null);

  ValueListenable<DiffHeapClass?> get selectedDiffHeapClass =>
      _selectedDiffHeapClass;
  final _selectedDiffHeapClass = ValueNotifier<DiffHeapClass?>(null);

  @override
  bool get hasData => heap != null;

  HeapClasses heapClassesToShow() {
    print(1);
    final theHeap = heap!;
    final itemToDiffWith = diffWith.value;
    if (itemToDiffWith == null) return theHeap.classes;
    print('!!!! ${itemToDiffWith.name}');
    return _diffStore.compare(theHeap, itemToDiffWith.heap!);
  }

  void _updateSelectedClass() {
    _selectedSingleHeapClass.value = null;
    _selectedDiffHeapClass.value = null;

    final className = _selectedClassName.value;
    if (className == null) return;

    final heapClasses = heapClassesToShow();
    if (heapClasses is SingeHeapClasses) {
      _selectedSingleHeapClass.value = heapClasses.classesByName[className];
    } else if (heapClasses is DiffHeapClasses) {
      _selectedDiffHeapClass.value = heapClasses.classesByName[className];
    }

    throw StateError('Unexpected type: ${heapClasses.runtimeType}.');
  }

  void downloadToCsv() {
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

    // // Write a row per retaining path.
    // final data = heapClassesToShow;
    // for (var classStats in data.classAnalysis) {
    //   for (var pathStats in classStats.objectsByPath.entries) {
    //     csvBuffer.writeln(
    //       [
    //         classStats.heapClass.className,
    //         classStats.heapClass.library,
    //         pathStats.value.instanceCount,
    //         pathStats.value.shallowSize,
    //         pathStats.value.retainedSize,
    //         pathStats.key.asShortString(),
    //         pathStats.key.asLongString().replaceAll('\n', ' | '),
    //       ].join(','),
    //     );
    //   }
    // }

    final file = ExportController().downloadFile(
      csvBuffer.toString(),
      type: ExportFileType.csv,
    );

    notificationService.push(successfulExportMessage(file));

    throw UnimplementedError();
  }
}
