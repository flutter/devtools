// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../controller/model.dart';
import 'stats_table.dart';

class SnapshotView extends StatelessWidget {
  const SnapshotView({Key? key, required this.item}) : super(key: key);

  final SnapshotListItem item;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: item.isProcessing,
      builder: (_, isProcessing, __) {
        if (isProcessing) return const SizedBox.shrink();

        final stats = item.heap?.stats;
        if (stats == null) {
          return const Center(child: Text('Could not take snapshot.'));
        }

        return StatsTable(
          // The key is passed to persist state.
          key: ObjectKey(item),
          data: stats,
          sorting: item.sorting,
          selectedRecord: item.selectedRecord,
        );
      },
    );
  }
}
