// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/elements.dart';
import 'timeline_controller.dart';

abstract class CpuProfilerView extends CoreElement {
  CpuProfilerView(this.timelineController, this.type)
      : super('div', classes: 'cpu-profiler-section');

  final TimelineController timelineController;

  final CpuProfilerViewType type;

  bool viewNeedsRebuild = false;

  void rebuildView();

  void update() {
    // Update the view if it is visible. Otherwise, mark the view as needing a
    // rebuild.
    if (!isHidden) {
      rebuildView();
    } else {
      viewNeedsRebuild = true;
    }
  }

  void show() {
    hidden(false);
    if (viewNeedsRebuild) {
      viewNeedsRebuild = false;
      update();
    }
  }

  void hide() => hidden(true);
}

enum CpuProfilerViewType {
  flameChart,
  bottomUp,
  callTree,
}
