// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'perfetto_controller.dart';

class PerfettoControllerImpl extends PerfettoController {
  PerfettoControllerImpl(
    super.performanceController,
    super.timelineEventsController,
  );
}
