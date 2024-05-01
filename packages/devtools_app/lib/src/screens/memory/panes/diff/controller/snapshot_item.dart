// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/memory/heap_data.dart';
import '../../../../../shared/memory/heap_graph_loader.dart';

abstract class SnapshotItem extends DisposableController {
  /// Number to show with auto-generated names that may be non unique, like isolate name.
  int? get displayNumber;

  ValueListenable<bool> get isProcessing => _isProcessing;
  final _isProcessing = ValueNotifier<bool>(false);

  /// If true, the item contains data, that can be compared and analyzed.
  bool get hasData;

  @override
  void dispose() {
    _isProcessing.dispose();
    super.dispose();
  }
}

class SnapshotDocItem extends SnapshotItem {
  @override
  int? get displayNumber => null;

  @override
  bool get hasData => false;
}

class _Json {
  static const defaultName = 'defaultName';
  static const displayNumber = 'displayNumber';
  static const chunks = 'chunks';
  static const created = 'created';
  static const nameOverride = 'nameOverride';
}

class SnapshotDataItem extends SnapshotItem implements RenamableItem {
  SnapshotDataItem({
    required this.defaultName,
    this.displayNumber,
    this.nameOverride,
  });

  factory SnapshotDataItem.fromJson(Map<String, dynamic> json) {
    final result = SnapshotDataItem(
      displayNumber: json[_Json.displayNumber] as int?,
      defaultName: json[_Json.defaultName] as String,
      nameOverride: json[_Json.nameOverride] as String?,
    );

    final loader = HeapGraphLoaderFromChunks(
      chunks: json[_Json.chunks] as List<ByteData>,
      created: json[_Json.created] as DateTime,
    );

    unawaited(
      result.loadHeap(loader),
    ); // Start the loading process, that will result in progress indicator in UI.

    return result;
  }

  Map<String, dynamic> toJson() {
    final heap = _heap!; // Not processed heaps are not serializable.
    return {
      _Json.defaultName: defaultName,
      _Json.displayNumber: displayNumber,
      _Json.nameOverride: nameOverride,
      _Json.chunks: heap.graph.toChunks(),
      _Json.created: heap.created,
    };
  }

  HeapData? get heap => _heap;
  HeapData? _heap;

  /// Automatically assigned name like isolate name or file name.
  final String defaultName;

  @override
  final int? displayNumber;

  @override
  bool get hasData => _heap != null;

  Future<void> loadHeap(HeapGraphLoader loader) async {
    assert(_heap == null);
    final (graph, created) = await loader.load();
    _heap = HeapData(graph, created: created);
    await _heap!.calculate;
    _isProcessing.value = false;
  }

  @override
  String? nameOverride;

  final diffWith = ValueNotifier<SnapshotDataItem?>(null);

  @override
  String get name =>
      nameOverride ??
      '$defaultName${displayNumber == null ? '' : '-$displayNumber'}';

  int? get totalSize => _heap?.footprint?.reachable;
}

abstract class RenamableItem {
  String get name;

  String? nameOverride;
}
