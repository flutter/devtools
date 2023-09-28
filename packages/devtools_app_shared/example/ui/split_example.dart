// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart' as devtools_shared_ui;
import 'package:flutter/material.dart';

/// Example of using the [Split] widget from
/// 'package:devtools_app_shared/ui.dart' with two children laid across a
/// horizontal axis.
///
/// This example does not specify the [Split.splitters] parameter, so a
/// default splitter is used.
class SplitExample extends StatelessWidget {
  const SplitExample({super.key});

  @override
  Widget build(BuildContext context) {
    return devtools_shared_ui.Split(
      axis: Axis.horizontal,
      initialFractions: const [0.3, 0.7],
      minSizes: const [50.0, 100.0],
      children: const [
        Text('Left side'),
        Text('Right side'),
      ],
    );
  }
}

/// Example of using the [Split] widget from
/// 'package:devtools_app_shared/ui.dart' with three children laid across a
/// vertical axis.
///
/// This example uses custom splitters.
class MultiSplitExample extends StatelessWidget {
  const MultiSplitExample({super.key});

  @override
  Widget build(BuildContext context) {
    return devtools_shared_ui.Split(
      axis: Axis.vertical,
      initialFractions: const [0.3, 0.3, 0.4],
      minSizes: const [50.0, 50.0, 100.0],
      splitters: const [
        CustomSplitter(),
        CustomSplitter(),
      ],
      children: const [
        Text('Top'),
        Text('Middle'),
        Text('Bottom'),
      ],
    );
  }
}

class CustomSplitter extends StatelessWidget implements PreferredSizeWidget {
  const CustomSplitter({super.key});

  static const _size = 50.0;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: _size,
      child: Icon(Icons.front_hand),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(_size);
}
