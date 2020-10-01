// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'timeline_model.dart';

String computeEventGroupKey(TimelineEvent event) {
  if (event.groupKey != null) {
    return event.groupKey;
  } else if (event.isAsyncEvent) {
    return event.root.name;
  } else if (event.isUiEvent) {
    return TimelineData.uiKey;
  } else if (event.isRasterEvent) {
    return TimelineData.rasterKey;
  } else if (event.isGCEvent) {
    return TimelineData.gcKey;
  } else {
    return TimelineData.unknownKey;
  }
}
