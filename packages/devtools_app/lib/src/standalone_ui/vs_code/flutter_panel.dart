// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/feature_flags.dart';

class VsCodeFlutterPanel extends StatelessWidget {
  const VsCodeFlutterPanel({super.key});

  @override
  Widget build(BuildContext context) {
    assert(FeatureFlags.vsCodeSidebarTooling);
    return const Center(
      child: Text('TODO: a panel for flutter actions in VS Code'),
    );
  }
}
