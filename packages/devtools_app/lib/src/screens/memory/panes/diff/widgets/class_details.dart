// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../controller/diff_pane_controller.dart';

class HeapClassDetails extends StatelessWidget {
  const HeapClassDetails({
    Key? key, required this.controller,
  }) : super(key: key);

  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HeapClass?>(
      valueListenable: item.selectedHeapClass,
      builder: (_, classStats, __) {
        if (classStats == null) {
          return const Center(
            child: Text('Select class to see details here.'),
          );
        }

        return ClassStatsTable(
          data: classStats,
          sorting: sorting,
        );
      },
    );
  }
}
