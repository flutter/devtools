// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '_perfetto_controller_desktop.dart'
    if (dart.library.html) '_perfetto_controller_web.dart';
import '_perfetto_desktop.dart' if (dart.library.html) '_perfetto_web.dart';

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
