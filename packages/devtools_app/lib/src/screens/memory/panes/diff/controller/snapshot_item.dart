// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';

import '../../../../../shared/memory/heap_data.dart';
import '../../../../../shared/memory/heap_graph_loader.dart';
import '../../../../../shared/primitives/serialization.dart';

abstract class SnapshotItem extends DisposableController {
  /// Number to show with auto-generated names that may be non unique, like isolate name.
  int? get displayNumber;
}

class SnapshotDocItem extends SnapshotItem {
  @override
  int? get displayNumber => null;
}

@visibleForTesting
enum Json {
  defaultName,
  displayNumber,
  graph,
  created,
  nameOverride;
}

class SnapshotDataItem extends SnapshotItem implements RenamableItem {
  SnapshotDataItem({
    required this.defaultName,
    this.displayNumber,
    this.nameOverride,
  });

  factory SnapshotDataItem.fromJson(Map<String, dynamic> json) {
    final result = SnapshotDataItem(
      displayNumber: json[Json.displayNumber.name] as int?,
      defaultName: json[Json.defaultName.name] as String? ?? 'no name',
      nameOverride: json[Json.nameOverride.name] as String?,
    );

    final graph = decodeHeapSnapshotGraph(json[Json.graph.name]);
    if (graph == null) return result;

    final loader = HeapGraphLoaderDirect(
      graph: graph,
      created: decodeDateTime(json[Json.created.name]) ?? DateTime.now(),
    );

    // Start the loading process, that will result in progress indicator in UI.
    unawaited(result.loadHeap(loader));

    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      Json.defaultName.name: defaultName,
      Json.displayNumber.name: displayNumber,
      Json.nameOverride.name: nameOverride,
      Json.graph.name: _heap?.graph,
      Json.created.name: _heap?.created,
    };
  }

  HeapData? get heap => _heap;
  HeapData? _heap;

  /// Automatically assigned name like isolate name or file name.
  final String defaultName;

  @override
  final int? displayNumber;

  Future<void> loadHeap(HeapGraphLoader loader) async {
    assert(_heap == null);
    final (graph, created) = await loader.load();
    _heap = HeapData(graph, created: created);
    await _heap!.calculate;
    _processed.complete();
  }

  @override
  String? nameOverride;

  final diffWith = ValueNotifier<SnapshotDataItem?>(null);

  @override
  String get name =>
      nameOverride ??
      '$defaultName${displayNumber == null ? '' : '-$displayNumber'}';

  int? get totalSize => _heap?.footprint?.reachable;

  Future<void> get process => _processed.future;
  final _processed = Completer<void>();
  bool get isProcessed => _processed.isCompleted;
}

abstract class RenamableItem {
  String get name;

  String? nameOverride;
}
