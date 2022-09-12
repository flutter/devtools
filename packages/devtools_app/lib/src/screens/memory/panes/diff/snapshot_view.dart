// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'model.dart';

class SnapshotView extends StatefulWidget {
  const SnapshotView({Key? key, required this.item}) : super(key: key);

  final SnapshotListItem item;

  @override
  State<SnapshotView> createState() => _SnapshotViewState();
}

class _SnapshotViewState extends State<SnapshotView> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.item.isProcessing,
      builder: (_, isProcessing, ____) {
        if (isProcessing) return const SizedBox.shrink();

        final stats = widget.item.stats;
        if (stats == null) return const Text('Could not take snapshot.');

        return const Text('under construction');
      },
    );
  }
}
