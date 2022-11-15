// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'analytics_common.dart';

// TODO(polina-c): move other subclasses of ScreenAnalyticsMetrics here.

class MemoryScreenMetrics extends ScreenAnalyticsMetrics {
  MemoryScreenMetrics({
    this.heapObjectsTotal,
    this.heapDiffObjectsBefore,
    this.heapDiffObjectsAfter,
  });

  final int? heapDiffObjectsBefore;
  final int? heapDiffObjectsAfter;
  final int? heapObjectsTotal;
}
