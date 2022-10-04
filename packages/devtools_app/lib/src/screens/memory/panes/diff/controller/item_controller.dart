// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
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

class SnapshotInstanceItem extends SnapshotItem {
  SnapshotInstanceItem({
    required Future<AdaptedHeapData?> receiver,
    required this.displayNumber,
    required this.isolateName,
    required this.id,
  }) {
    _isProcessing.value = true;
    receiver.whenComplete(() async {
      final data = await receiver;
      if (data != null) heap = AdaptedHeap(data);
      _isProcessing.value = false;
    });
  }

  final int id;

  final String isolateName;

  AdaptedHeap? heap;

  @override
  final int displayNumber;

  String get name => '$isolateName-$displayNumber';

  final diffWith = ValueNotifier<SnapshotInstanceItem?>(null);

  @override
  bool get hasData => heap != null;

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

    // TODO(polina-c): write data to file before opening the feature.
    // // Write a row per retaining path.
    // final data = heapClassesToShow();
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

    // TODO(polina-c): add the notification to ExportController.downloadFile.
    notificationService.push(successfulExportMessage(file));

    throw UnimplementedError();
  }
}
