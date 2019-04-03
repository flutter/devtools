// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/elements.dart';

class CpuBottomUp extends CoreElement {
  CpuBottomUp() : super('div', classes: 'ui-details-section') {
    flex();
    layoutVertical();

    add(div(text: 'Bottom up view coming soon', c: 'message'));
  }
}
