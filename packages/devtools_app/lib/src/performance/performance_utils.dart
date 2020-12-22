// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'performance_model.dart';

String computeEventGroupKey(TimelineEvent event) {
  if (event.groupKey != null) {
    return event.groupKey;
  } else if (event.isAsyncEvent) {
    return event.root.name;
  } else if (event.isUiEvent) {
    return PerformanceData.uiKey;
  } else if (event.isRasterEvent) {
    return PerformanceData.rasterKey;
  } else if (event.isGCEvent) {
    return PerformanceData.gcKey;
  } else {
    return PerformanceData.unknownKey;
  }
}
