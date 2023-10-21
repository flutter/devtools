// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '_perfetto_desktop.dart'
    if (dart.library.js_interop) '_perfetto_web.dart';
import 'perfetto_controller.dart';

class EmbeddedPerfetto extends StatelessWidget {
  const EmbeddedPerfetto({Key? key, required this.perfettoController})
      : super(key: key);

  final PerfettoController perfettoController;

  @override
  Widget build(BuildContext context) {
    return Perfetto(
      perfettoController: perfettoController,
    );
  }
}

class PerfettoHelpButton extends StatelessWidget {
  const PerfettoHelpButton({super.key, required this.perfettoController});

  final PerfettoController perfettoController;

  @override
  Widget build(BuildContext context) {
    return HelpButton(
      gaScreen: gac.performance,
      gaSelection: gac.PerformanceEvents.perfettoShowHelp.name,
      outlined: false,
      onPressed: perfettoController.showHelpMenu,
    );
  }
}
