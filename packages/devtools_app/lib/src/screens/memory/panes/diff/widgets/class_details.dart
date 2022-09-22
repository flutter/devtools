// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../../shared/heap/model.dart';
import '../controller/Item_controller.dart';

class ClassDetails extends StatelessWidget {
  const ClassDetails({Key? key, required this.item}) : super(key: key);

  final SnapshotListItem item;

  @override
  Widget build(BuildContext context) {
    if (item.selectedRecord.value == null) {
      return const Center(
        child: Text('Select class to see details here.'),
      );
    }
    return Center(
        child: Text('Details for ${item.selectedClass.value} will be here'));
  }
}
