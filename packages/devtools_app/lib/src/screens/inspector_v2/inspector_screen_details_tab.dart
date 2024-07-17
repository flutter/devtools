// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import 'inspector_controller.dart';
import 'layout_explorer/layout_explorer.dart';

class InspectorDetails extends StatelessWidget {
  const InspectorDetails({
    required this.controller,
    super.key,
  });

  final InspectorController controller;

  @override
  Widget build(BuildContext context) {
    return RoundedOutlinedBorder(
      clip: true,
      child: Column(
        children: [
          Expanded(
            child: LayoutExplorerTab(
              controller: controller,
            ),
          ),
        ],
      ),
    );
  }
}
