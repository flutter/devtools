// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import '../../../../../shared/memory/class_name.dart';
import '../../../../../shared/memory/classes.dart';
import '../../../../../shared/memory/heap_data.dart';
import '../../../../../shared/primitives/utils.dart';
import 'classes_diff.dart';

@immutable
class HeapDiffData {
  const HeapDiffData._(
    this.classes, {
    required this.before,
    required this.after,
  });

  final HeapData before;
  final HeapData after;

  final ClassDataList<DiffClassData> classes;
}

HeapDiffData calculateHeapDiffData({
  required HeapData before,
  required HeapData after,
}) {
  final classesByName = subtractMaps<HeapClassName, SingleClassData,
      SingleClassData, DiffClassData>(
    from: after.classes!.asMap(),
    subtract: before.classes!.asMap(),
    subtractor: ({subtract, from}) => DiffClassData.compare(
      before: subtract,
      after: from,
      dataBefore: before,
      dataAfter: after,
    ),
  );

  return HeapDiffData._(
    ClassDataList<DiffClassData>(classesByName.values.toList(growable: false)),
    before: before,
    after: after,
  );
}
