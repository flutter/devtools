// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'perfetto_controller.dart';

class PerfettoControllerImpl extends PerfettoController {
  PerfettoControllerImpl(
    super.performanceController,
    super.timelineEventsController,
  );
}
