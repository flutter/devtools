// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(kenz): delete this legacy implementation after
// https://github.com/flutter/flutter/commit/78a96b09d64dc2a520e5b269d5cea1b9dde27d3f
// hits flutter stable.

// @dart=2.9

import 'performance_model.dart';

String legacyComputeEventGroupKey(
  LegacyTimelineEvent event,
  Map<int, String> threadNamesById,
) {
  if (event.groupKey != null) {
    return event.groupKey;
  } else if (event.isAsyncEvent) {
    return event.root.name;
  } else if (event.isUiEvent) {
    return LegacyPerformanceData.uiKey;
  } else if (event.isRasterEvent) {
    return LegacyPerformanceData.rasterKey;
  } else if (threadNamesById[event.threadId] != null) {
    return threadNamesById[event.threadId];
  } else {
    return LegacyPerformanceData.unknownKey;
  }
}
