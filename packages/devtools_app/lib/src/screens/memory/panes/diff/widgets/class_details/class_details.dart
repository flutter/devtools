// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../../../shared/heap/heap.dart';
import 'paths.dart';

class HeapClassDetails extends StatelessWidget {
  const HeapClassDetails({
    Key? key,
    required this.entries,
    required this.selection,
    required this.isDiff,
  }) : super(key: key);

  final List<StatsByPathEntry>? entries;
  final ValueNotifier<StatsByPathEntry?> selection;
  final bool isDiff;

  @override
  Widget build(BuildContext context) {
    final theEntries = entries;
    if (theEntries == null) {
      return const Center(
        child: Text('Select class to see details here.'),
      );
    }

    return RetainingPathTable(
      entries: theEntries,
      selection: selection,
      isDiff: isDiff,
    );
  }
}
