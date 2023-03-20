// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

enum ProfilerTab {
  summary('Summary', _summaryTab),
  bottomUp('Bottom Up', _bottomUpTab),
  callTree('Call Tree', _callTreeTab),
  methodTable('Method Table', _methodTableTab),
  cpuFlameChart('CPU Flame Chart', _flameChartTab);

  const ProfilerTab(this.title, this.key);

  final String title;
  final Key key;

  // When content of the selected DevToolsTab from the tab controller has any
  // of these three keys, we will not show the expand/collapse buttons.
  static const Key _flameChartTab = Key('cpu profile flame chart tab');
  static const Key _methodTableTab = Key('cpu profile method table tab');
  static const Key _summaryTab = Key('cpu profile summary tab');

  static const Key _bottomUpTab = Key('cpu profile bottom up tab');
  static const Key _callTreeTab = Key('cpu profile call tree tab');

  static ProfilerTab byKey(Key? k) {
    return ProfilerTab.values.firstWhere((tab) => tab.key == k);
  }
}
