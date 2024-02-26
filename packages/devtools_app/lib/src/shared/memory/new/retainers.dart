// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

typedef IsRetainer = bool Function(int index);
typedef Referrers = List<int> Function(int index);
typedef ShallowSize = int Function(int index);

class ShortestRetainers {
  final List<int> retainers;
  final List<int>? retainedSizes;
}

ShortestRetainers shortestRetainers(
  int graphSize,
  int rootIndex,
  IsRetainer isRetainer,
  Referrers referrers,
  ShallowSize shallowSize, {
  bool calculateSizes = true,
}) {
  var distance = 0;
  while (cut.isNotEmpty) {
    final nextCut = <int>[];
    for (final index in cut) {
      final object = graph.objects[index];
      for (final ref in object.references) {
        final refIndex = ref.index;
        if (retainers[refIndex] == 0) {
          retainers[refIndex] = index;
          sizes[refIndex] = graph.objects[refIndex].shallowSize;
          if (weakClasses.isWeakClass(graph.objects[refIndex].clazz)) {
            nextCut.add(refIndex);
          }
        }
      }
    }
    cut = nextCut;
    distance++;
  }
}
