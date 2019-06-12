// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/elements.dart';
import 'cpu_profiler_view.dart';
import 'timeline_controller.dart';

class CpuBottomUp extends CpuProfilerView {
  CpuBottomUp(TimelineController timelineController)
      : super(timelineController, CpuProfilerViewType.bottomUp) {
    flex();
    layoutVertical();

    add(div(text: 'Bottom up view coming soon', c: 'message'));
  }

  @override
  void rebuildView() {}
}
