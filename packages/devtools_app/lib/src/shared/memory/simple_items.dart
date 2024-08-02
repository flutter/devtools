// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:vm_service/vm_service.dart';

/// Direction of reference between objects in memory.
enum RefDirection {
  inbound,
  outbound,
}

class MemoryFootprint {
  MemoryFootprint({
    required this.dart,
    required this.reachable,
  });

  /// Reachable and unreachable total dart heap size.
  final int dart;

  /// Subset of [dart].
  final int reachable;
}

/// Value for rootIndex is taken from the doc:
/// https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/heap_snapshot.md#object-ids
const heapRootIndex = 1;

extension HeapSnapshotGraphSerialization on HeapSnapshotGraph {
  static Future<HeapSnapshotGraph> load(XFile file) async {
    final bytes = await file.readAsBytes();
    final data = bytes.buffer.asByteData();
    return HeapSnapshotGraph.fromChunks([data]);
  }

  /// Serializes the graph to a list of bytes.
  ///
  /// Used to export graph to file to the same format as `writeHeapSnapshotToFile`.
  /// See https://api.flutter.dev/flutter/dart-developer/NativeRuntime/writeHeapSnapshotToFile.html
  Uint8List toUint8List() {
    final b = BytesBuilder();
    for (final chunk in toChunks()) {
      b.add(chunk.buffer.asUint8List());
    }
    return b.toBytes();
  }
}

/// A simple timer for measuring snapshotting performance in release mode.
///
/// To see performance numbers in console, set `_print` to `true`.
class SnapshotTimer {
  SnapshotTimer() {
    _timer.start();
  }
  static final instance = SnapshotTimer();
  static const _print = true;

  final _timer = Stopwatch();
  var _printedSnapshotTime = 0;

  void maybeReset() {
    if (!_print) return;
    _timer
      ..reset()
      ..start();
    _printedSnapshotTime = 0;
  }

  void maybePrint(String message) {
    if (!_print) return;
    final total = _timer.elapsedMilliseconds;
    final delta = total - _printedSnapshotTime;
    _printedSnapshotTime = total;

    // ignore: avoid_print, we want to measure performance in release mode.
    print('Snapshotting. $message: + $delta = $total ms');
  }
}
