// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '_perfetto_controller_web.dart';

class Perfetto extends StatelessWidget {
  const Perfetto({
    Key? key,
    required this.perfettoController,
  }) : super(key: key);

  final PerfettoController perfettoController;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const HtmlElementView(
        viewType: PerfettoController.viewId,
      ),
    );
  }
}
